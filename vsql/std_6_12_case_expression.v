module vsql

// ISO/IEC 9075-2:2016(E), 6.12, <case expression>
//
// Specify a conditional value.

type CaseExpression = CaseExpressionCoalesce | CaseExpressionNullIf

fn (e CaseExpression) pstr(params map[string]Value) string {
	return match e {
		CaseExpressionNullIf {
			'NULLIF(${e.a.pstr(params)}, ${e.b.pstr(params)})'
		}
		CaseExpressionCoalesce {
			'COALESCE(${e.exprs.map(it.pstr(params)).join(', ')})'
		}
	}
}

fn (e CaseExpression) compile(mut c Compiler) !CompileResult {
	match e {
		CaseExpressionNullIf {
			compiled_a := e.a.compile(mut c)!
			compiled_b := e.b.compile(mut c)!

			return CompileResult{
				run:          fn [compiled_a, compiled_b] (mut conn Connection, data Row, params map[string]Value) !Value {
					a := compiled_a.run(mut conn, data, params)!
					b := compiled_b.run(mut conn, data, params)!

					if a.typ.typ != b.typ.typ {
						return sqlstate_42804('in NULLIF', a.typ.str(), b.typ.str())
					}

					cmp := compare(a, b)!
					if cmp == .is_equal {
						return new_null_value(a.typ.typ)
					}

					return a
				}
				typ:          compiled_a.typ
				contains_agg: compiled_a.contains_agg || compiled_b.contains_agg
			}
		}
		CaseExpressionCoalesce {
			compiled_exprs := e.exprs.map(it.compile(mut c)!)

			mut contains_agg := false
			for _, compiled_expr in compiled_exprs {
				contains_agg = contains_agg || compiled_expr.contains_agg
			}

			return CompileResult{
				run:          fn [compiled_exprs] (mut conn Connection, data Row, params map[string]Value) !Value {
					mut typ := SQLType.is_varchar
					mut first := true
					for i, compiled_expr in compiled_exprs {
						typ2 := compiled_expr.typ

						if first {
							typ = typ2.typ
							first = false
						} else if typ != typ2.typ {
							return sqlstate_42804('in argument ${i + 1} of COALESCE',
								typ.str(), typ2.typ.str())
						}
					}

					mut value := Value{}
					for compiled_expr in compiled_exprs {
						value = compiled_expr.run(mut conn, data, params)!

						if !value.is_null {
							return value
						}
					}

					return new_null_value(value.typ.typ)
				}
				typ:          compiled_exprs[0].typ
				contains_agg: contains_agg
			}
		}
	}
}

struct CaseExpressionNullIf {
	a ValueExpression
	b ValueExpression
}

struct CaseExpressionCoalesce {
	exprs []ValueExpression
}
