module vsql

type NumericValueExpression = Term | BinaryExpr

fn (e NumericValueExpression) pstr(params map[string]Value) string {
	return 'FIXME'
}

fn (e NumericValueExpression) eval_as_type(conn &Connection, data Row, params map[string]Value) !Type {
	match e {
		Term {
			match e {
				Factor {
					return eval_as_type(conn, data, e, params)
				}
				BinaryExpr {
					return eval_as_type(conn, data, e, params)
				}
			}
		}
		BinaryExpr {
			return eval_as_type(conn, data, e, params)
		}
	}
}

fn (e NumericValueExpression) eval_as_value(mut conn &Connection, data Row, params map[string]Value) !Value {
	return match e {
		Term {
			match e {
				Factor {
					eval_as_value(mut conn, data, e, params)!
				}
				BinaryExpr {
					eval_as_value(mut conn, data, e, params)!
				}
			}
		}
		BinaryExpr {
			eval_as_value(mut conn, data, e, params)!
		}
	}
}

type Term = Factor | BinaryExpr

struct Factor {
	sign   string
	factor NumericPrimary
}

fn (e Factor) pstr(params map[string]Value) string {
	return 'FIXME'
}

fn parse_numeric_value_expression_1(expr Term) !NumericValueExpression {
	return expr
}

fn parse_numeric_value_expression_2(left NumericValueExpression, op string, right Term) !NumericValueExpression {
	match left {
		Term {
			match left {
				Factor {
					match right {
						Factor {
							return NumericValueExpression(BinaryExpr{left, op, right})
						}
						BinaryExpr {
							return NumericValueExpression(BinaryExpr{left, op, right})
						}
					}
				}
				BinaryExpr {
					match right {
						Factor {
							return NumericValueExpression(BinaryExpr{left, op, right})
						}
						BinaryExpr {
							return NumericValueExpression(BinaryExpr{left, op, right})
						}
					}
				}
			}
		}
		BinaryExpr {
			match right {
				Factor {
					return NumericValueExpression(BinaryExpr{left, op, right})
				}
				BinaryExpr {
					return NumericValueExpression(BinaryExpr{left, op, right})
				}
			}
		}
	}
}

fn parse_term_1(e Factor) !Term {
	return e
}

fn parse_term_2(left Term, op string, right Factor) !Term {
	match left {
		Factor {
			return BinaryExpr{left, op, right}
		}
		BinaryExpr {
			return BinaryExpr{left, op, right}
		}
	}
}

fn parse_factor_1(e NumericPrimary) !Factor {
	return Factor{'+', e}
}

fn parse_factor_2(sign string, expr NumericPrimary) !Factor {
	return Factor{sign, expr}
}
