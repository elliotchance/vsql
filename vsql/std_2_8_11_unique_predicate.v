module vsql

// ISO/IEC 9075-2:2023, 8.11, <unique predicate>
//
// Specify a test for the absence of duplicate rows.

// UniquePredicate is "UNIQUE (SELECT ...)". It's never UNKNOWN.
struct UniquePredicate {
	subquery Subquery
	// nulls_not_distinct is NULLS NOT DISTINCT, otherwise it's NULLS DISTINCT.
	nulls_not_distinct bool
}

fn (e UniquePredicate) pstr(params map[string]Value) string {
	null_treatment := if e.nulls_not_distinct { 'NULLS NOT DISTINCT ' } else { '' }
	return 'UNIQUE ${null_treatment}${e.subquery.pstr(params)}'
}

fn (e UniquePredicate) compile(mut c Compiler) !CompileResult {
	plan := e.subquery.plan(mut c)!

	return CompileResult{
		run:          fn [plan, e] (mut conn Connection, data Row, params map[string]Value) !Value {
			rows := subquery_rows(mut conn, plan, data)!

			return new_boolean_value(is_unique_rows(conn, rows, e.nulls_not_distinct)!)
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
// ISO/IEC 9075-2:2023, 8.11, <unique predicate>, Syntax Rules, 2
// ISO/IEC 9075-2:2023, 8.11, <unique predicate>, General Rules, 2
//
// With NULLS NOT DISTINCT, a NULL is the same as another NULL (like a grouping
// operation), so rows that are all NULL are duplicates too, which is
// implementation-defined.
//
// ISO/IEC 9075-2:2023, 4.25.3.2, Unique constraints
// ISO/IEC 9075-2:2023, 8.11, <unique predicate>, General Rules, 2.c
fn is_unique_rows(conn &Connection, rows [][]Value, nulls_not_distinct bool) !bool {
	mut kept := [][]Value{}
	for row in rows {
		if !nulls_not_distinct && row.any(it.is_null) {
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
