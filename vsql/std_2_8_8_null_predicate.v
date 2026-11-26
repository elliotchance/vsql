module vsql

// ISO/IEC 9075-2:2023, 8.8, <null predicate>
//
// Specify a test for a null value.

// NullPredicate for "IS NULL" and "IS NOT NULL". The expression can be a row
// (F481).
struct NullPredicate {
	expr RowValueConstructorPredicand
	not  bool
}

fn (e NullPredicate) pstr(params map[string]Value) string {
	if e.not {
		return '${e.expr.pstr(params)} IS NOT NULL'
	}

	return '${e.expr.pstr(params)} IS NULL'
}

fn (e NullPredicate) compile(mut c Compiler) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &NullPredicate{
		...e
	}
	compiled := e.expr.compile_fields(mut c)!

	return CompileResult{
		run:          fn [e_ref, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
			// ISO/IEC 9075-2:2023, 8.8, <null predicate>, General Rules, 2:
			// for a row, IS NULL is true when every value is NULL and IS NOT
			// NULL is true when none are. So a row with some NULLs is neither
			// (Table 16, <null predicate> semantics).
			mut nulls := 0
			for element in compiled {
				if element.run(mut conn, data, params)!.is_null {
					nulls++
				}
			}

			if e_ref.not {
				return new_boolean_value(nulls == 0)
			}

			return new_boolean_value(nulls == compiled.len)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled.any(it.contains_agg)
	}
}
