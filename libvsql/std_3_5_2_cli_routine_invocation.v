module main

// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation
//
// Specify the rules for invocation of a <CLI routine>.
//
// Each routine is a C function, so the C compiler checks the number and types
// of the arguments (Syntax Rules 2 to 4), and the routine returns its return
// code (General Rules 4.a). Every routine first looks up its handle, and
// returns SQL_INVALID_HANDLE (without a status record) if it isn't allocated
// (General Rules 3.b.i.1 and 3.b.ii.1). The return code and status records
// for each condition are set by the Diagnostics (General Rules 5 and 6). A
// failed SQL-statement has no effect, even in an SQL-transaction (General
// Rules 5.c.i).

// invoke applies General Rule 3.b.i to a routine with a statement handle (other
// than Error): the SQL-connection of the statement must be established, and it
// becomes the current SQL-connection. If deferred is false, the statement
// can't be waiting for the values of deferred parameters (only Cancel,
// ParamData and PutData can be).
fn (stmt &Stmt) invoke(deferred bool) ! {
	// - 3.b.i.4. If there is no established SQL-connection associated with C,
	// then an exception condition is raised: connection exception —
	// connection does not exist.
	dbc := dbcs[stmt.dbc] or { return cli_error('08003', 'connection does not exist') }
	if dbc.conn == none {
		return cli_error('08003', 'connection does not exist')
	}

	// - 3.b.i.5. If EC is not the current SQL-connection, then the General
	// Rules of Subclause 5.3, "Implicit set connection", are applied.
	implicit_set_connection(stmt.dbc)!

	// - 3.b.i.6. If GRN is neither Cancel nor ParamData nor PutData and there
	// is a deferred parameter number associated with S, then an exception
	// condition is raised: CLI-specific condition — function sequence error.
	if !deferred {
		stmt.check_deferred()!
	}
}

// invoke applies General Rule 3.b.ii to a routine with a descriptor handle
// (other than CopyDesc).
fn (desc &Desc) invoke() ! {
	// - 3.b.ii.4. If there is no established SQL-connection associated with
	// C, then an exception condition is raised: connection exception —
	// connection does not exist.
	dbc := dbcs[desc.dbc] or { return cli_error('08003', 'connection does not exist') }
	if dbc.conn == none {
		return cli_error('08003', 'connection does not exist')
	}

	// - 3.b.ii.5. If EC is not the current SQL-connection, then the General
	// Rules of Subclause 5.3, "Implicit set connection", are applied.
	implicit_set_connection(desc.dbc)!
}
