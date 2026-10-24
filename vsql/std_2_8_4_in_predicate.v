module vsql

// ISO/IEC 9075-2:2016(E), 8.4, <in predicate>
//
// Specify a quantified comparison.

struct InPredicate {
	not    bool
	expr   RowValueConstructorPredicand
	values []RowValueConstructorPredicand
}

fn (e InPredicate) pstr(params map[string]Value) string {
	mut values := []string{}
	for value in e.values {
		values << value.pstr(params)
	}

	return '${e.expr.pstr(params)} ' + if e.not {
		'NOT '
	} else {
		''
	} + 'IN (${values.join(', ')})'
}

fn (e InPredicate) compile(mut c Compiler) !CompileResult {
	compiled_expr := e.expr.compile(mut c)!
	mut contains_agg := compiled_expr.contains_agg
	mut compiled_values := []CompileResult{}
	for value in e.values {
		compiled := value.compile(mut c)!
		c.check_time_zone_comparison(compiled_expr.typ, compiled.typ)!
		contains_agg = contains_agg || compiled.contains_agg
		compiled_values << compiled
	}

	return CompileResult{
		run:          fn [e, compiled_expr, compiled_values] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := compiled_expr.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2016(E), 8.4, <in predicate>, Syntax Rules 2, 4 and 5:
			//
			//   RVC IN (A, B, C) is RVC = ANY (VALUES A, B, C)
			//   RVC NOT IN (A, B, C) is NOT (RVC IN (A, B, C))
			//
			// So the result is TRUE if any value is equal, FALSE if every value is
			// not equal and otherwise UNKNOWN. Every value is compared (rather than
			// stopping at the first match) so that an incomparable value is always
			// an error, wherever it is in the list.
			mut result := Truth.is_false
			for compiled_value in compiled_values {
				value := compiled_value.run(mut conn, data, params)!
				result = truth_or(result, match compare(conn, expr, value)! {
					.is_unknown { Truth.is_unknown }
					.is_equal { Truth.is_true }
					else { Truth.is_false }
				})
			}

			if e.not {
				result = truth_not(result)
			}

			return match result {
				.is_true { new_boolean_value(true) }
				.is_false { new_boolean_value(false) }
				.is_unknown { new_unknown_value() }
			}
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: contains_agg
	}
}
