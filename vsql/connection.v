// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

struct Connection {
mut:
	storage        FileStorage
	funcs          map[string]Func
	virtual_tables map[string]VirtualTable
}

pub fn open(path string) ?Connection {
	mut conn := Connection{
		storage: new_file_storage(path) ?
	}
	register_builtin_funcs(mut conn) ?

	return conn
}

pub fn (mut c Connection) query(sql string) ?Result {
	stmt := parse(sql) ?

	match stmt {
		CreateTableStmt {
			return c.create_table(stmt)
		}
		DeleteStmt {
			return c.delete(stmt)
		}
		DropTableStmt {
			return c.drop_table(stmt)
		}
		InsertStmt {
			return c.insert(stmt)
		}
		SelectStmt {
			return c.query_select(stmt)
		}
		UpdateStmt {
			return c.update(stmt)
		}
	}
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
	stmt := parse(create_table) ?

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
