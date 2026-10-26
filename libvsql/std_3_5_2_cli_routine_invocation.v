module main

// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation
//
// Specify the rules for invocation of a <CLI routine>.

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
