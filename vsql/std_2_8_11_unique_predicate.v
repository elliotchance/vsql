module vsql

// ISO/IEC 9075-2:2023, 8.11, <unique predicate>
//
// Specify a test for the absence of duplicate rows.

// UniquePredicate is "UNIQUE (SELECT ...)". It's never UNKNOWN.
struct UniquePredicate {
	subquery Subquery
}

fn (e UniquePredicate) pstr(params map[string]Value) string {
	return 'UNIQUE ${e.subquery.pstr(params)}'
}

fn (e UniquePredicate) compile(mut c Compiler) !CompileResult {
	plan := e.subquery.plan(mut c)!

	return CompileResult{
		run:          fn [plan] (mut conn Connection, data Row, params map[string]Value) !Value {
			rows := subquery_rows(mut conn, plan, data)!

			return new_boolean_value(is_unique_rows(conn, rows)!)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: plan.contains_agg
	}
}

// is_unique_rows is true if no two rows are duplicates. A row that contains a
// NULL is never a duplicate of another row, and it's TRUE when there are no
// rows. Each column is compared like a grouping operation, the same as for
// SELECT DISTINCT.
//
// The <unique null treatment> can't be given (F292), and the implicit one is
// implementation-defined. vsql's is NULLS DISTINCT, which is why a row with a
// NULL is never a duplicate.
//
// ISO/IEC 9075-2:2023, 8.11, <unique predicate>, Syntax Rules, 2 and 3
// ISO/IEC 9075-2:2023, 8.11, <unique predicate>, General Rules, 2.a, 2.b and 2.d
fn is_unique_rows(conn &Connection, rows [][]Value) !bool {
	mut kept := [][]Value{}
	for row in rows {
		if row.any(it.is_null) {
			continue
		}

		for existing in kept {
			if is_duplicate_row(conn, row, existing)! {
				return false
			}
		}
		kept << row
	}

	return true
}
