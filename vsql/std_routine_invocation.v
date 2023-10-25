// ISO/IEC 9075-2:2016(E), 10.4, <routine invocation>

module vsql

// Format
//~
//~ <routine invocation> /* Expr */ ::=
//~     <routine name> <SQL argument list>   -> routine_invocation
//~
//~ <routine name> /* Identifier */ ::=
//~     <qualified identifier>   -> routine_name
//~
//~ <SQL argument list> /* []Expr */ ::=
//~     <left paren> <right paren>                  -> empty_exprs
//~   | <left paren> <SQL argument> <right paren>   -> expr_to_list
//~   | <left paren> <SQL argument list> <comma>
//~     <SQL argument> <right paren>                -> append_exprs1
//~
//~ <SQL argument> /* Expr */ ::=
//~     <value expression>

fn parse_routine_invocation(name Identifier, args []Expr) !Expr {
	return CallExpr{name.entity_name, args}
}

fn parse_routine_name(identifier IdentifierChain) !Identifier {
	return new_function_identifier(identifier.identifier)
}

fn parse_empty_exprs() ![]Expr {
	return []Expr{}
}

fn parse_empty() !Expr {
	return NoExpr{}
}
