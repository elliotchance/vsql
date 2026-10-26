module vsql

// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint
// characteristics>
//
// Specify the name of a constraint and its characteristics.

// ConstraintCharacteristics are the <constraint characteristic>s of a
// constraint (DEFERRABLE, NOT DEFERRABLE, INITIALLY DEFERRED or INITIALLY
// IMMEDIATE), in the order they were given. They're stored in the file the same
// way (see str).
struct ConstraintCharacteristics {
	clauses []string
}

// add returns the characteristics with another one, or an error if it's the
// second DEFERRABLE (or NOT DEFERRABLE) or the second INITIALLY, or it's
// INITIALLY DEFERRED and NOT DEFERRABLE (Syntax Rule 2a).
fn (c ConstraintCharacteristics) add(clause string) !ConstraintCharacteristics {
	mut clauses := c.clauses.clone()
	clauses << clause
	deferrable := clauses.filter(it.ends_with('DEFERRABLE')).len
	if deferrable > 1 || clauses.len - deferrable > 1
		|| ('INITIALLY DEFERRED' in clauses && 'NOT DEFERRABLE' in clauses) {
		return sqlstate_42601('invalid constraint characteristics: ${clauses.join(' ')}')
	}
	if clause == 'INITIALLY DEFERRED' {
		return sqlstate_0a000('INITIALLY DEFERRED is not supported')
	}

	return ConstraintCharacteristics{clauses}
}

// is_deferrable is true unless the constraint is NOT DEFERRABLE, which is
// implicit when it's not INITIALLY DEFERRED and neither DEFERRABLE nor NOT
// DEFERRABLE is given (Syntax Rule 2b, General Rule 2).
fn (c ConstraintCharacteristics) is_deferrable() bool {
	return 'DEFERRABLE' in c.clauses || 'INITIALLY DEFERRED' in c.clauses
}

// is_initially_deferred is true when the constraint mode of the constraint is
// deferred at the start of each transaction (General Rule 3).
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
