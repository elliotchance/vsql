module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.4, <set constraints mode statement>
//
// If an SQL-transaction is currently active, then set the constraint mode for
// that SQL-transaction in the current SQL-session. If no SQL-transaction is
// currently active, then set the constraint mode for the next SQL-transaction
// in the current SQL-session for the SQL-agent.

// The names are empty for ALL.
struct SetConstraintsModeStatement {
	names       []Identifier
	is_deferred bool
}

// execute sets the constraint mode of each constraint (General Rules 2 and 3).
// A constraint that becomes immediate is checked straight away, for the rows
// written while it was deferred (ISO/IEC 9075-2:2016(E), 4.23.2). If it's not
// satisfied, the statement fails and nothing changes, so it's still deferred
// and checked again later.
fn (stmt SetConstraintsModeStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut old_modes := map[string]map[string]bool{}
	mut old_checks := map[string]map[string]string{}
	for catalog_name, catalog in conn.catalogs {
		old_modes[catalog_name] = catalog.storage.constraint_modes.clone()
		old_checks[catalog_name] = catalog.storage.deferred_checks.clone()
	}

	if stmt.names.len == 0 {
		for _, mut catalog in conn.catalogs {
			catalog.storage.set_all_constraint_modes(stmt.is_deferred)
		}
	}
	for name in stmt.names {
		mut catalog, table, characteristics := conn.find_constraint(name)!
		catalog.storage.set_constraint_mode(table, name.entity_name, characteristics,
			stmt.is_deferred)!
	}

	if !stmt.is_deferred {
		conn.check_deferred_constraints() or {
			for catalog_name, mut catalog in conn.catalogs {
				catalog.storage.constraint_modes = old_modes[catalog_name].clone()
				catalog.storage.deferred_checks = old_checks[catalog_name].clone()
			}
			return err
		}
	}

	return new_result_msg('SET CONSTRAINTS', elapsed_parse, t.elapsed())
}

fn (stmt SetConstraintsModeStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET CONSTRAINTS')
}

// find_constraint returns the catalog, table and characteristics of the
// constraint that has the name, which can be qualified by its schema and
// catalog (Syntax Rule 1).
fn (mut conn Connection) find_constraint(name Identifier) !(&CatalogConnection, Table, ConstraintCharacteristics) {
	resolved := conn.resolve_identifier(name)
	mut catalog := conn.catalogs[resolved.catalog_name] or {
		return sqlstate_42704('constraint', name.str())
	}
	for _, table in catalog.storage.tables {
		if table.name.schema_name != resolved.schema_name {
			continue
		}

		kind, i := table.find_constraint(resolved) or { continue }
		return catalog, table, table.constraint_characteristics(kind, i)
	}

	return sqlstate_42704('constraint', name.str())
}

// constraint_key identifies a constraint in a catalog, because its name is
// unique in its schema.
fn constraint_key(t Table, name string) string {
	return '${t.name.schema_name}.${name}'
}

// set_constraint_mode sets the constraint mode of a constraint of t, which
// must be deferrable (Syntax Rule 2).
fn (mut f Storage) set_constraint_mode(t Table, name string, characteristics ConstraintCharacteristics, is_deferred bool) ! {
	if !characteristics.is_deferrable() {
		return sqlstate_42601('constraint ${name} is not DEFERRABLE')
	}

	f.constraint_modes[constraint_key(t, name)] = is_deferred
}

// set_all_constraint_modes sets the constraint mode of every deferrable
// constraint, for ALL.
fn (mut f Storage) set_all_constraint_modes(is_deferred bool) {
	for _, t in f.tables {
		for constraint in t.unique_constraints {
			f.set_constraint_mode(t, constraint.name, constraint.characteristics, is_deferred) or {}
		}
		for key in t.foreign_keys {
			f.set_constraint_mode(t, key.name, key.characteristics, is_deferred) or {}
		}
		for constraint in t.check_constraints {
			f.set_constraint_mode(t, constraint.name.entity_name, constraint.characteristics,
				is_deferred) or {}
		}
	}
}

// end_constraint_modes forgets the constraint modes and deferred checks at the
// end of a transaction, so that the next one starts with the initial
// constraint modes.
fn (mut f Storage) end_constraint_modes() {
	f.constraint_modes = map[string]bool{}
	f.deferred_checks = map[string]string{}
}

// is_deferred is true if the constraint mode of a constraint of t is deferred.
// It's always immediate outside of a transaction, because a statement on its
// own is in a transaction that ends with the statement.
fn (f Storage) is_deferred(t Table, name string, characteristics ConstraintCharacteristics) bool {
	if f.transaction_state != .active || !characteristics.is_deferrable() {
		return false
	}

	return f.constraint_modes[constraint_key(t, name)] or {
		characteristics.is_initially_deferred()
	}
}

// defer_check is true if a constraint of t is deferred, so a statement doesn't
// check it. It's remembered so that it's checked once it's immediate (see
// check_deferred_constraints).
fn (mut f Storage) defer_check(t Table, name string, characteristics ConstraintCharacteristics) bool {
	if !f.is_deferred(t, name, characteristics) {
		return false
	}

	f.deferred_checks[constraint_key(t, name)] = t.name.storage_id()
	return true
}

// check_deferred_constraints checks each constraint that a statement didn't
// check (see defer_check), and is now immediate, against every row of its
// table. A constraint that's still deferred is remembered again, and one that
// has been dropped (or whose table has been dropped) doesn't need to be checked.
fn (mut conn Connection) check_deferred_constraints() ! {
	_, time_zone := conn.now()
	for _, mut catalog in conn.catalogs {
		mut keys := catalog.storage.deferred_checks.keys()
		keys.sort()
		for key in keys {
			storage_id := catalog.storage.deferred_checks[key]
			catalog.storage.deferred_checks.delete(key)
			table := catalog.storage.tables[storage_id] or { continue }

			constraint := Table{
				...table
				unique_constraints: table.unique_constraints.filter(constraint_key(table,
					it.name) == key)
				foreign_keys:       table.foreign_keys.filter(constraint_key(table, it.name) == key)
				check_constraints:  table.check_constraints.filter(constraint_key(table,
					it.name.entity_name) == key)
			}
			rows := catalog.storage.read_rows(table.name)!.map(it.for_storage())
			check_constraints := new_check_constraints(mut conn, constraint)!
			for row in rows {
				check_constraints.verify(mut conn, row)!
			}
			catalog.storage.check_unique_constraints(constraint, rows)!
			catalog.storage.check_foreign_keys(constraint, rows, time_zone)!
		}
	}
}
