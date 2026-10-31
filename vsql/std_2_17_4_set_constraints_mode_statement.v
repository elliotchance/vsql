module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.4, <set constraints mode statement>
//
// If an SQL-transaction is currently active, then set the constraint mode for
// that SQL-transaction in the current SQL-session. If no SQL-transaction is
// currently active, then set the constraint mode for the next SQL-transaction
// in the current SQL-session for the SQL-agent.
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.7.1, Constraint
// checking.

// The names are empty for ALL.
struct SetConstraintsModeStatement {
	names       []Identifier
	is_deferred bool
}

// execute sets the constraint mode of each constraint. A constraint that
// becomes immediate is checked straight away, for the rows written while it
// was deferred. If it's not satisfied, the statement fails and nothing
// changes, so it's still deferred and checked again later. Outside of an
// SQL-transaction, it's the constraint mode of the next one.
//
// ISO/IEC 9075-2:2016(E), 4.23.2, Checking of constraints
// ISO/IEC 9075-2:2016(E), 17.4, <set constraints mode statement>, General Rules, 2 and 3
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
// catalog.
//
// ISO/IEC 9075-2:2016(E), 17.4, <set constraints mode statement>, Syntax Rules, 1
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
