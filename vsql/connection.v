// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

struct Connection {
mut:
	storage FileStorage
}

pub fn open(path string) ?Connection {
	return Connection{new_file_storage(path) ?}
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
