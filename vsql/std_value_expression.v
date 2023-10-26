// ISO/IEC 9075-2:2016(E), 6.28, <value expression>

module vsql

// Format
//~
//~ <value expression> /* ValueExpression */ ::=
//~     <common value expression>    -> ValueExpression
//~   | <boolean value expression>   -> ValueExpression
//~
//~ <common value expression> /* CommonValueExpression */ ::=
//~     <numeric value expression>    -> CommonValueExpression
//~   | <string value expression>     -> CommonValueExpression
//~   | <datetime value expression>   -> CommonValueExpression

type ValueExpression = BooleanValueExpression | CommonValueExpression

fn (e ValueExpression) pstr(params map[string]Value) string {
	return match e {
		CommonValueExpression, BooleanValueExpression {
			e.pstr(params)
		}
	}
}

fn (e ValueExpression) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		CommonValueExpression, BooleanValueExpression {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e ValueExpression) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		CommonValueExpression, BooleanValueExpression {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e ValueExpression) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		CommonValueExpression, BooleanValueExpression {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e ValueExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !ValueExpression {
	match e {
		CommonValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		BooleanValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
	}
}

type CommonValueExpression = CharacterValueExpression | DatetimePrimary | NumericValueExpression

fn (e CommonValueExpression) pstr(params map[string]Value) string {
	return match e {
		NumericValueExpression, CharacterValueExpression, DatetimePrimary {
			e.pstr(params)
		}
	}
}

fn (e CommonValueExpression) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		NumericValueExpression, CharacterValueExpression, DatetimePrimary {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e CommonValueExpression) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		NumericValueExpression, CharacterValueExpression, DatetimePrimary {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e CommonValueExpression) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		NumericValueExpression, CharacterValueExpression, DatetimePrimary {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e CommonValueExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !CommonValueExpression {
	return match e {
		NumericValueExpression {
			e.resolve_identifiers(conn, tables)!
		}
		CharacterValueExpression {
			e.resolve_identifiers(conn, tables)!
		}
		DatetimePrimary {
			e.resolve_identifiers(conn, tables)!
		}
	}
}
