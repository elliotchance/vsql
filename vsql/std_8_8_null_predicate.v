module vsql

// ISO/IEC 9075-2:2016(E), 8.8, <null predicate>
//
// Specify a test for a null value.

// NullPredicate for "IS NULL" and "IS NOT NULL".
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
	compiled := e.expr.compile(mut c)!

	return CompileResult{
		run:          fn [e, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled.run(mut conn, data, params)!

			if e.not {
				return new_boolean_value(!value.is_null)
			}

			return new_boolean_value(value.is_null)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled.contains_agg
	}
}
