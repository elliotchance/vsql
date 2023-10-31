// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>

module vsql

// Format
//~
//~ <aggregate function> /* AggregateFunction */ ::=
//~     COUNT <left paren> <asterisk> <right paren>   -> count_all
//~   | <general set function>
//~
//~ <general set function> /* AggregateFunction */ ::=
//~     <set function type> <left paren>
//~     <value expression> <right paren>   -> general_set_function
//~
//~ <set function type> /* string */ ::=
//~     <computational operation>
//~
//~ <computational operation> /* string */ ::=
//~     AVG
//~   | MAX
//~   | MIN
//~   | SUM
//~   | COUNT

type AggregateFunction = AggregateFunctionCount | RoutineInvocation

fn (e AggregateFunction) pstr(params map[string]Value) string {
	return match e {
		AggregateFunctionCount { 'COUNT(*)' }
		RoutineInvocation { e.pstr(params) }
	}
}

fn (e AggregateFunction) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		AggregateFunctionCount {
			(new_column_identifier('"COUNT(*)"')!).eval(mut conn, data, params)!
		}
		RoutineInvocation {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e AggregateFunction) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		AggregateFunctionCount { new_type('INTEGER', 0, 0) }
		RoutineInvocation { e.eval_type(conn, data, params)! }
	}
}

fn (e AggregateFunction) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	match e {
		AggregateFunctionCount {
			return true
		}
		RoutineInvocation {
			return e.is_agg(conn, row, params)!
		}
	}

	return false
}

fn (e AggregateFunction) resolve_identifiers(conn &Connection, tables map[string]Table) !AggregateFunction {
	match e {
		AggregateFunctionCount { return AggregateFunction(e) }
		RoutineInvocation { return e.resolve_identifiers(conn, tables)! }
	}
}

fn parse_count_all(asterisk string) !AggregateFunction {
	return AggregateFunctionCount{}
}

fn parse_general_set_function(name string, expr ValueExpression) !AggregateFunction {
	return RoutineInvocation{name, [expr]}
}

struct AggregateFunctionCount {}
