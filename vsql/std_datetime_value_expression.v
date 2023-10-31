module vsql

// ISO/IEC 9075-2:2016(E), 6.35, <datetime value expression>
//
// # Function
//
// Specify a datetime value.
//
// # Format
//~
//~ <datetime value expression> /* DatetimePrimary */ ::=
//~     <datetime term>
//~
//~ <datetime term> /* DatetimePrimary */ ::=
//~     <datetime factor>
//~
//~ <datetime factor> /* DatetimePrimary */ ::=
//~     <datetime primary>
//~
//~ <datetime primary> /* DatetimePrimary */ ::=
//~     <value expression primary>   -> DatetimePrimary
//~   | <datetime value function>    -> DatetimePrimary

type DatetimePrimary = DatetimeValueFunction | ValueExpressionPrimary

fn (e DatetimePrimary) pstr(params map[string]Value) string {
	return match e {
		ValueExpressionPrimary, DatetimeValueFunction {
			e.pstr(params)
		}
	}
}

fn (e DatetimePrimary) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		ValueExpressionPrimary, DatetimeValueFunction {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e DatetimePrimary) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		ValueExpressionPrimary, DatetimeValueFunction {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e DatetimePrimary) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		ValueExpressionPrimary, DatetimeValueFunction {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e DatetimePrimary) resolve_identifiers(conn &Connection, tables map[string]Table) !DatetimePrimary {
	return match e {
		ValueExpressionPrimary {
			e.resolve_identifiers(conn, tables)!
		}
		DatetimeValueFunction {
			e.resolve_identifiers(conn, tables)!
		}
	}
}
