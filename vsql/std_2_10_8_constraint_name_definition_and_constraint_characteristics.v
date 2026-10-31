module vsql

// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint
// characteristics>
//
// Specify the name of a constraint and its characteristics.
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.6.6.3, Table
// constraints.

// ConstraintCharacteristics are the <constraint characteristic>s of a
// constraint (DEFERRABLE, NOT DEFERRABLE, INITIALLY DEFERRED or INITIALLY
// IMMEDIATE), in the order they were given. They're stored in the file the same
// way (see str).
struct ConstraintCharacteristics {
	clauses []string
}

// add returns the characteristics with another one, or an error if it's the
// second DEFERRABLE (or NOT DEFERRABLE) or the second INITIALLY, or it's
// INITIALLY DEFERRED and NOT DEFERRABLE.
//
// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint characteristics>, Syntax Rules, 2.a.i
fn (c ConstraintCharacteristics) add(clause string) !ConstraintCharacteristics {
	mut clauses := c.clauses.clone()
	clauses << clause
	deferrable := clauses.filter(it.ends_with('DEFERRABLE')).len
	if deferrable > 1 || clauses.len - deferrable > 1
		|| ('INITIALLY DEFERRED' in clauses && 'NOT DEFERRABLE' in clauses) {
		return sqlstate_42601('invalid constraint characteristics: ${clauses.join(' ')}')
	}

	return ConstraintCharacteristics{clauses}
}

// is_deferrable is true unless the constraint is NOT DEFERRABLE. DEFERRABLE is
// implicit for INITIALLY DEFERRED, otherwise NOT DEFERRABLE is implicit when
// neither DEFERRABLE nor NOT DEFERRABLE is given, which includes a constraint
// without any <constraint characteristics>.
//
// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint characteristics>, Syntax Rules, 2.a.ii and 2.b
// ISO/IEC 9075-2:2016(E), 11.6, <table constraint definition>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint characteristics>, General Rules, 2
fn (c ConstraintCharacteristics) is_deferrable() bool {
	return 'DEFERRABLE' in c.clauses || 'INITIALLY DEFERRED' in c.clauses
}

// is_initially_deferred is true when the constraint mode of the constraint is
// deferred at the start of each transaction. Otherwise, it's immediate, which
// is the same as an implicit INITIALLY IMMEDIATE.
//
// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint characteristics>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint characteristics>, General Rules, 3
fn (c ConstraintCharacteristics) is_initially_deferred() bool {
	return 'INITIALLY DEFERRED' in c.clauses
}

// check_not_deferrable returns an error if the constraint is DEFERRABLE, for a
// PRIMARY KEY or NOT NULL, which can't be deferred. Rows are stored by their
// PRIMARY KEY (see Row.object_key) and a NOT NULL column doesn't store whether
// it's NULL (see Row.bytes), so neither can be violated, even for a moment.
fn (c ConstraintCharacteristics) check_not_deferrable(constraint string) ! {
	if c.is_deferrable() {
		return sqlstate_0a000('${constraint} cannot be DEFERRABLE')
	}
}

// str is the characteristics, each after a space, as they're stored in the
// file after the constraint (see Table.bytes).
fn (c ConstraintCharacteristics) str() string {
	return c.clauses.map(' ${it}').join('')
}

// with_constraint_characteristic adds a <constraint characteristic> to the last
// of the elements, which is a column followed by the constraints of the column
// (see add_column_constraint), or a single table constraint. A column without a
// constraint can't have one.
fn with_constraint_characteristic(elements []TableElement, clause string) ![]TableElement {
	mut new_elements := elements.clone()
	element := elements.last()
	new_elements[elements.len - 1] = match element {
		Column {
			return sqlstate_42601('${clause} must follow a constraint')
		}
		CheckConstraintDefinition {
			TableElement(CheckConstraintDefinition{
				...element
				characteristics: element.characteristics.add(clause)!
			})
		}
		NotNullConstraint {
			TableElement(NotNullConstraint{
				...element
				characteristics: element.characteristics.add(clause)!
			})
		}
		UniqueConstraintDefinition {
			TableElement(UniqueConstraintDefinition{
				...element
				characteristics: element.characteristics.add(clause)!
			})
		}
		ReferentialConstraintDefinition {
			TableElement(ReferentialConstraintDefinition{
				...element
				characteristics: element.characteristics.add(clause)!
			})
		}
	}

	return new_elements
}

// constraint_key identifies a constraint in a catalog, because its name is
// unique in its schema.
fn constraint_key(t Table, name string) string {
	return '${t.name.schema_name}.${name}'
}

// set_constraint_mode sets the constraint mode of a constraint of t, which
// must be deferrable.
//
// ISO/IEC 9075-2:2016(E), 17.4, <set constraints mode statement>, Syntax Rules, 2
fn (mut f Storage) set_constraint_mode(t Table, name string, characteristics ConstraintCharacteristics, is_deferred bool) ! {
	if !characteristics.is_deferrable() {
		return sqlstate_42601('constraint ${name} is not DEFERRABLE')
	}

	f.constraint_modes[constraint_key(t, name)] = is_deferred
}

// set_all_constraint_modes sets the constraint mode of every deferrable
// constraint, for ALL.
//
// ISO/IEC 9075-2:2016(E), 17.4, <set constraints mode statement>, General Rules, 2.a and 3.a
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
// constraint modes. A new SQL-session also starts with them, rather than with
// every constraint immediate.
//
// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 10.b.ii
// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.h.ii.2
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 13.n
// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, General Rules, 5.c.iii.2.C.II
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
