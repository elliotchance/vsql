// sqlstate.v contains all the error definitions as they are described by the
// SQLSTATE codes.
//
// The SQL standard is pretty flexible on the individual codes, so I've copied
// the relevant errors code from the definitions in PostgreSQL:
// https://www.postgresql.org/docs/9.4/errcodes-appendix.html

module vsql

// syntax error
struct SQLState42601 {
	msg  string
	code int
}

fn sqlstate_42601(message string) IError {
	return SQLState42601{
		msg: 'syntax error $message'
	}
}

// no such table
struct SQLState42P01 {
	msg  string
	code int
pub:
	table_name string
}

fn sqlstate_42p01(table_name string) IError {
	return SQLState42P01{
		msg: 'no such table: $table_name'
		table_name: table_name
	}
}

// duplicate table
struct SQLState42P07 {
	msg  string
	code int
pub:
	table_name string
}

fn sqlstate_42p07(table_name string) IError {
	return SQLState42P07{
		msg: 'duplicate table: $table_name'
		table_name: table_name
	}
}
