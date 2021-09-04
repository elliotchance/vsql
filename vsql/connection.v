// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

[heap]
struct Connection {
mut:
	storage        FileStorage
	funcs          map[string]Func
	virtual_tables map[string]VirtualTable
	query_cache    &QueryCache
}

pub fn open(path string) ?Connection {
	return open_database(path, default_connection_options())
}

pub fn open_database(path string, options ConnectionOptions) ?Connection {
	mut conn := Connection{
		storage: new_file_storage(path) ?
		query_cache: options.query_cache
	}
	register_builtin_funcs(mut conn) ?

	return conn
}

pub fn (mut c Connection) prepare(sql string) ?PreparedStmt {
	stmt, params := c.query_cache.parse(sql) ?
	println('> $stmt $params')

	return PreparedStmt{stmt, params, &c}
}

pub fn (mut c Connection) query(sql string) ?Result {
	mut prepared := c.prepare(sql) ?

	return prepared.query(map[string]Value{})
}

pub fn (mut c Connection) register_func(func Func) ? {
	c.funcs[func.name] = func
}

pub fn (mut c Connection) register_function(prototype string, func fn ([]Value) ?Value) ? {
	// TODO(elliotchance): A rather crude way to decode the prototype...
	parts := prototype.replace('(', '|').replace(')', '|').split('|')
	function_name := identifier_name(parts[0].trim_space())
	raw_args := parts[1].split(',')
	mut arg_types := []Type{}
	for arg in raw_args {
		if arg.trim_space() != '' {
			arg_types << new_type(arg.trim_space().to_upper(), 0)
		}
	}

	c.register_func(Func{function_name, arg_types, func}) ?
}

pub fn (mut c Connection) register_virtual_table(create_table string, data fn (mut t VirtualTable)) ? {
	// Registering virtual tables does not need use query cache.
	mut tokens := tokenize(create_table)
	stmt := parse(tokens) ?

	if stmt is CreateTableStmt {
		table_name := identifier_name(stmt.table_name)
		c.virtual_tables[table_name] = VirtualTable{
			create_table_sql: create_table
			create_table_stmt: stmt
			data: data
		}

		return
	}

	return error('must provide a CREATE TABLE statement')
}

struct ConnectionOptions {
pub mut:
	query_cache &QueryCache
}

fn default_connection_options() ConnectionOptions {
	return ConnectionOptions{
		query_cache: new_query_cache()
	}
}
