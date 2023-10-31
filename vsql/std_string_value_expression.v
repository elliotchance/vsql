// ISO/IEC 9075-2:2016(E), 6.31, <string value expression>

module vsql

// Format
//~
//~ <string value expression> /* CharacterValueExpression */ ::=
//~     <character value expression>
//~
//~ <character value expression> /* CharacterValueExpression */ ::=
//~     <concatenation>      -> CharacterValueExpression
//~   | <character factor>   -> CharacterValueExpression
//~
//~ <concatenation> /* Concatenation */ ::=
//~     <character value expression>
//~     <concatenation operator>
//~     <character factor>             -> concatenation
//~
//~ <character factor> /* CharacterPrimary */ ::=
//~     <character primary>
//~
//~ <character primary> /* CharacterPrimary */ ::=
//~     <value expression primary>   -> CharacterPrimary
//~   | <string value function>      -> CharacterPrimary

type CharacterValueExpression = CharacterPrimary | Concatenation

fn (e CharacterValueExpression) pstr(params map[string]Value) string {
	return match e {
		Concatenation, CharacterPrimary {
			e.pstr(params)
		}
	}
}

fn (e CharacterValueExpression) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		Concatenation, CharacterPrimary {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e CharacterValueExpression) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		Concatenation, CharacterPrimary {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e CharacterValueExpression) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		Concatenation, CharacterPrimary {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e CharacterValueExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !CharacterValueExpression {
	return match e {
		Concatenation {
			e.resolve_identifiers(conn, tables)!
		}
		CharacterPrimary {
			e.resolve_identifiers(conn, tables)!
		}
	}
}

type CharacterPrimary = CharacterValueFunction | ValueExpressionPrimary

fn (e CharacterPrimary) pstr(params map[string]Value) string {
	return match e {
		ValueExpressionPrimary, CharacterValueFunction {
			e.pstr(params)
		}
	}
}

fn (e CharacterPrimary) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		ValueExpressionPrimary, CharacterValueFunction {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e CharacterPrimary) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		ValueExpressionPrimary, CharacterValueFunction {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e CharacterPrimary) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	match e {
		ValueExpressionPrimary, CharacterValueFunction {
			if e.is_agg(conn, row, params)! {
				return sqlstate_42601('nested aggregate functions are not supported: ${e.pstr(params)}')
			}
		}
	}

	return false
}

fn (e CharacterPrimary) resolve_identifiers(conn &Connection, tables map[string]Table) !CharacterPrimary {
	return match e {
		ValueExpressionPrimary {
			e.resolve_identifiers(conn, tables)!
		}
		CharacterValueFunction {
			e.resolve_identifiers(conn, tables)!
		}
	}
}

struct Concatenation {
	left  CharacterValueExpression
	right CharacterValueExpression
}

fn (e Concatenation) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} || ${e.right.pstr(params)}'
}

fn (e Concatenation) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	mut left := e.left.eval(mut conn, data, params)!
	mut right := e.right.eval(mut conn, data, params)!

	if (left.typ.typ == .is_character || left.typ.typ == .is_varchar)
		&& (right.typ.typ == .is_character || right.typ.typ == .is_varchar) {
		return new_varchar_value(left.string_value() + right.string_value())
	}

	return sqlstate_42883('operator does not exist: ${left.typ.typ} || ${right.typ.typ}')
}

fn (e Concatenation) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return new_type('VARCHAR', 0, 0)
}

fn (e Concatenation) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if e.left.is_agg(conn, row, params)! || e.right.is_agg(conn, row, params)! {
		return sqlstate_42601('nested aggregate functions are not supported: ${e.pstr(params)}')
	}

	return false
}

fn (e Concatenation) resolve_identifiers(conn &Connection, tables map[string]Table) !Concatenation {
	return Concatenation{e.left.resolve_identifiers(conn, tables)!, e.right.resolve_identifiers(conn,
		tables)!}
}

fn parse_concatenation(a CharacterValueExpression, b CharacterValueExpression) !Concatenation {
	return Concatenation{a, b}
}
