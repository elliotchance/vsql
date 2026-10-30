module vsql

// ISO/IEC 9075-2:2016(E), 8.8, <null predicate>
//
// Specify a test for a null value.

// NullPredicand is a single value or a row (F481).
type NullPredicand = ExplicitRowValueConstructor | RowValueConstructorPredicand

// NullPredicate for "IS NULL" and "IS NOT NULL".
struct NullPredicate {
	expr NullPredicand
	not  bool
}

fn new_null_predicate_row(elements []ContextuallyTypedRowValueConstructorElement, not bool) !NullPredicate {
	mut exprs := []ValueExpression{}
	for element in elements {
		match element {
			ValueExpression { exprs << element }
			ContextuallyTypedValueSpecification {
				return match element {
					DefaultSpecification { sqlstate_42601('unexpected DEFAULT') }
					NullSpecification { sqlstate_42601('unexpected NULL') }
				}
			}
		}
	}

	return NullPredicate{ExplicitRowValueConstructor{exprs}, not}
}

fn (e NullPredicate) pstr(params map[string]Value) string {
	expr := match e.expr {
		ExplicitRowValueConstructor { 'ROW(${e.expr.pstr(params)})' }
		RowValueConstructorPredicand { e.expr.pstr(params) }
	}

	if e.not {
		return '${expr} IS NOT NULL'
	}

	return '${expr} IS NULL'
}

fn (e NullPredicate) compile(mut c Compiler) !CompileResult {
	compiled := match e.expr {
		ExplicitRowValueConstructor { e.expr.exprs.map(it.compile(mut c)!) }
		RowValueConstructorPredicand { [e.expr.compile(mut c)!] }
	}

	return CompileResult{
		run:          fn [e, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
			// ISO/IEC 9075-2:2016(E), 8.8, <null predicate>, General Rules, 2:
			// for a row, IS NULL is true when every value is NULL and IS NOT
			// NULL is true when none are. So a row with some NULLs is neither
			// (Table 16, <null predicate> semantics).
			mut nulls := 0
			for element in compiled {
				if element.run(mut conn, data, params)!.is_null {
					nulls++
				}
			}

			if e.not {
				return new_boolean_value(nulls == 0)
			}

			return new_boolean_value(nulls == compiled.len)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled.any(it.contains_agg)
	}
}
