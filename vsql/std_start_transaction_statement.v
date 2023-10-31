// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>

module vsql

// Format
//~
//~ <start transaction statement> /* Stmt */ ::=
//~   START TRANSACTION   -> start_transaction_statement

struct StartTransactionStatement {
}

fn parse_start_transaction_statement() !Stmt {
	return StartTransactionStatement{}
}
