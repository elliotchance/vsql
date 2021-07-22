// vdb.v is the main file and library entry point allows the database to be
// opened.

module vdb

struct Vdb {
mut:
	storage FileStorage
}

pub fn open(path string) ?Vdb {
	return Vdb{new_file_storage(path) ?}
}

pub fn (mut db Vdb) query(sql string) ?Result {
	stmt := parse(sql) ?

	match stmt {
		CreateTableStmt {
			return db.create_table(stmt)
		}
		DeleteStmt {
			return db.delete(stmt)
		}
		DropTableStmt {
			return db.drop_table(stmt)
		}
		InsertStmt {
			return db.insert(stmt)
		}
		SelectStmt {
			return db.query_select(stmt)
		}
		UpdateStmt {
			return db.update(stmt)
		}
	}
}
