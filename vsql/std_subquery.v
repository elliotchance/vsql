// ISO/IEC 9075-2:2016(E), 7.19, <subquery>

module vsql

// Format
//~
//~ <row subquery> /* QueryExpression */ ::=
//~     <subquery>
//~
//~ <table subquery> /* TablePrimary */ ::=
//~     <subquery>
//~
//~ <subquery> /* TablePrimaryBody */ ::=
//~     <left paren> <query expression> <right paren>   -> subquery

type TablePrimaryBody = Identifier | QueryExpression

fn parse_subquery(stmt QueryExpression) !TablePrimary {
	return TablePrimary{
		body: stmt
	}
}
