// ISO/IEC 9075-2:2016(E), 6.36, <datetime value function>

module vsql

// Format
//~
//~ <datetime value function> /* Expr */ ::=
//~     <current date value function>
//~   | <current time value function>
//~   | <current timestamp value function>
//~   | <current local time value function>
//~   | <current local timestamp value function>
//~
//~ <current date value function> /* Expr */ ::=
//~     CURRENT_DATE   -> current_date
//~
//~ <current time value function> /* Expr */ ::=
//~     CURRENT_TIME                                               -> current_time1
//~   | CURRENT_TIME <left paren> <time precision> <right paren>   -> current_time2
//~
//~ <current local time value function> /* Expr */ ::=
//~     LOCALTIME                                               -> localtime1
//~   | LOCALTIME <left paren> <time precision> <right paren>   -> localtime2
//~
//~ <current timestamp value function> /* Expr */ ::=
//~     CURRENT_TIMESTAMP                                  -> current_timestamp1
//~   | CURRENT_TIMESTAMP
//~     <left paren> <timestamp precision> <right paren>   -> current_timestamp2
//~
//~ <current local timestamp value function> /* Expr */ ::=
//~     LOCALTIMESTAMP                                     -> localtimestamp1
//~   | LOCALTIMESTAMP
//~     <left paren> <timestamp precision> <right paren>   -> localtimestamp2

fn parse_current_date() !Expr {
	return CurrentDateExpr{}
}

fn parse_current_time1() !Expr {
	return CurrentTimeExpr{default_time_precision}
}

fn parse_current_time2(prec string) !Expr {
	return CurrentTimeExpr{prec.int()}
}

fn parse_localtime1() !Expr {
	return LocalTimeExpr{0}
}

fn parse_localtime2(prec string) !Expr {
	return LocalTimeExpr{prec.int()}
}

fn parse_current_timestamp1() !Expr {
	return CurrentTimestampExpr{default_timestamp_precision}
}

fn parse_current_timestamp2(prec string) !Expr {
	return CurrentTimestampExpr{prec.int()}
}

fn parse_localtimestamp1() !Expr {
	return LocalTimestampExpr{6}
}

fn parse_localtimestamp2(prec string) !Expr {
	return LocalTimestampExpr{prec.int()}
}
