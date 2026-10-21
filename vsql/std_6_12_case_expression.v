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

			// NULLIF(V1, V2) is CASE WHEN V1 = V2 THEN NULL ELSE V1 END, so the
			// values only need to be comparable, such as an INTEGER and a SMALLINT.
			//
			// ISO/IEC 9075-2:2016(E), 6.12, <case expression>, Syntax Rules, 1c
			if !comparable_types(compiled_a.typ.typ, compiled_b.typ.typ) {
				return sqlstate_42804('in NULLIF', compiled_a.typ.str(), compiled_b.typ.str())
			}

			return CompileResult{
				run:          fn [compiled_a, compiled_b] (mut conn Connection, data Row, params map[string]Value) !Value {
					a := compiled_a.run(mut conn, data, params)!
					b := compiled_b.run(mut conn, data, params)!

					cmp := compare(conn, a, b)!
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

			// ISO/IEC 9075-2:2016(E), 6.12, <case expression>, Syntax Rules, 7: the
			// result has the combined type of all the arguments (9.5).
			mut typ := Type{compiled_exprs[0].typ.typ, compiled_exprs[0].typ.size, compiled_exprs[0].typ.scale, false}
			mut contains_agg := compiled_exprs[0].contains_agg
			for i, compiled_expr in compiled_exprs[1..] {
				typ = combine_types(typ, compiled_expr.typ) or {
					return sqlstate_42804('in argument ${i + 2} of COALESCE', typ.str(),
						compiled_expr.typ.str())
				}
				contains_agg = contains_agg || compiled_expr.contains_agg
			}

			return CompileResult{
				run:          fn [compiled_exprs, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
					for compiled_expr in compiled_exprs {
						value := compiled_expr.run(mut conn, data, params)!

						if !value.is_null {
							return convert_to_combined_type(mut conn, 'in COALESCE', value,
								typ)!
						}
					}

					return new_null_value(typ.typ)
				}
				typ:          typ
				contains_agg: contains_agg
			}
		}
	}
}

// a and b are references because a ValueExpression can contain a CaseExpression,
// and V stores a sum type's value inline.
struct CaseExpressionNullIf {
	a &ValueExpression
	b &ValueExpression
}

fn new_case_expression_null_if(a ValueExpression, b ValueExpression) CaseExpressionNullIf {
	return CaseExpressionNullIf{&a, &b}
}

struct CaseExpressionCoalesce {
	exprs []ValueExpression
}

// comparable_types is true when values of the types can be compared, such as
// two numbers or two character strings (4.2 to 4.7).
fn comparable_types(t1 SQLType, t2 SQLType) bool {
	return (t1.is_number() && t2.is_number()) || (t1.is_string() && t2.is_string())
		|| (t1 == .is_boolean && t2 == .is_boolean) || (t1.is_datetime() && t2.is_datetime())
}
