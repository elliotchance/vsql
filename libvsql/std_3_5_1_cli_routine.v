module main

// ISO/IEC 9075-3:2003(E), 5.1, <CLI routine>
//
// An argument with the data type ANY (such as the Value of SetStmtAttr) is a
// "void *" in C (Syntax Rule 14.c.iv). The value is passed by reference, so
// "void *" points to an INTEGER or SMALLINT, the same as when it's retrieved
// (for example by GetStmtAttr).
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.8, Communication between an SQL-agent and an
// SQL-server
// ISO/IEC 9075-1:2003(E), 4.8.1, Host languages

// read_integer reads an INTEGER passed by reference.
fn read_integer(value voidptr) !i64 {
	if value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	return i64(unsafe { *&SQLInteger(value) })
}

// read_smallint reads a SMALLINT passed by reference.
fn read_smallint(value voidptr) !i64 {
	if value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	return i64(unsafe { *&i16(value) })
}
