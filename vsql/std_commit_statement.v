// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>

module vsql

// Format
//~
//~ <commit statement> /* Stmt */ ::=
//~     COMMIT        -> commit
//~   | COMMIT WORK   -> commit

fn parse_commit() !Stmt {
	return CommitStmt{}
}
