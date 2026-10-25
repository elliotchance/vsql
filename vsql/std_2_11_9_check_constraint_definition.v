module vsql

// ISO/IEC 9075-2:2016(E), 11.9, <check constraint definition>
//
// Specify a condition for the SQL-data.

struct CheckConstraintDefinition {
	search_condition BooleanValueExpression
	// column_name is set for a CHECK on a column, which can only use that column
	// (11.4, Syntax Rule 17d). It's not in the file, so a CHECK that's read from
	// the file is always a table constraint.
	column_name string
	// name is empty when the constraint doesn't have a <constraint name
	// definition> (see Table.name_constraints).
	name Identifier
}

// str is the SQL of the constraint, which is how it's stored in the file as part
// of the CREATE TABLE (see Table.bytes).
fn (e CheckConstraintDefinition) str() string {
	return 'CHECK (${e.search_condition.pstr(map[string]Value{})})'
}

// compile returns the search condition to be evaluated for a row of the table,
// or an error if it can't be used in a CHECK constraint (Syntax Rules 1, 2 and
// 5). The table doesn't need to exist yet, so it can be checked by the CREATE
// TABLE.
fn (e CheckConstraintDefinition) compile(mut conn Connection, table Table) !CompileResult {
	mut c := Compiler{
		conn:                   conn
		params:                 map[string]Value{}
		tables:                 {
			table.name.id(): table
		}
		context:                table.name
		next_value_not_allowed: 'a CHECK constraint'
		check_constraint:       true
		check_column:           e.column_name
	}
	compiled := e.search_condition.compile(mut c)!

	if compiled.contains_agg {
		return sqlstate_42601('an aggregate function cannot be used in a CHECK constraint')
	}

	if compiled.typ.typ != .is_boolean {
		return sqlstate_42804('in CHECK constraint', 'BOOLEAN', compiled.typ.str())
	}

	return compiled
}

// CheckConstraints are the compiled CHECK constraints of a table, so they're
// only compiled once for a statement that writes many rows.
struct CheckConstraints {
	table       Table
	constraints []CompileResult
}

fn new_check_constraints(mut conn Connection, table Table) !CheckConstraints {
	mut constraints := []CompileResult{}
	for constraint in table.check_constraints {
		constraints << constraint.compile(mut conn, table)!
	}

	return CheckConstraints{table, constraints}
}

// verify returns an error if a new row doesn't satisfy one of the CHECK
// constraints. The row is how it's written to the table, keyed by the column
// names (see Row.for_storage). A constraint is only violated when its search
// condition is FALSE, so UNKNOWN (such as when a column is NULL) satisfies it.
// The whole statement then fails, so none of its rows are written.
//
// ISO/IEC 9075-2:2016(E), 4.23.2, Checking of constraints
// ISO/IEC 9075-2:2016(E), 4.23.3.4, Table check constraints
fn (c CheckConstraints) verify(mut conn Connection, row Row) ! {
	if c.constraints.len == 0 {
		return
	}

	// The search condition uses the full column names, like a row that's read
	// from the table.
	mut data := map[string]Value{}
	for column in c.table.columns {
		data[column.name.id()] = row.data[column.name.sub_entity_name]
	}
	full_row := new_row(data)

	for i, constraint in c.constraints {
		result := constraint.run(mut conn, full_row, map[string]Value{})!
		if !result.is_null && result.bool_value() == .is_false {
			return sqlstate_23514('${c.table.check_constraints[i]} on ${c.table.name}')
		}
	}
}
