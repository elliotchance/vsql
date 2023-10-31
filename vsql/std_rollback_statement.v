// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>

module vsql

// Format
//~
//~ <rollback statement> /* Stmt */ ::=
//~     ROLLBACK        -> rollback
//~   | ROLLBACK WORK   -> rollback

struct RollbackStatement {
}

fn parse_rollback() !Stmt {
	return RollbackStatement{}
}
