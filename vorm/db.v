// vorm is a driver for V's built-in ORM:
//
//   import elliotchance.vsql.vorm
//
//   struct Product {
//       id    int @[primary; sql: serial]
//       name  string
//       price f64
//   }
//
//   mut db := vorm.open('test.vsql')!
//   sql db {
//       create table Product
//   }!
//
// See docs/v-orm.rst.

module vorm

import orm
import vsql

// quote is used for all table and column names. Names are delimited so that
// they keep the same case as the V struct and its fields, and so that names
// that are reserved words in SQL (such as "user" or "order") can be used.
const quote = '"'

// The ORM numbers each placeholder (:p1, :p2, etc), and the number of each
// placeholder is the order of the value in the QueryData.
const placeholder = ':p'

// DB is a vsql connection that can be used with V's ORM.
pub struct DB {
pub mut:
	// conn is the vsql connection. It can be used to run SQL in the same
	// connection (and transaction) as the ORM.
	conn &vsql.Connection
mut:
	// last_serial is the last value given to a serial field, see last_id().
	last_serial int
}

// open opens a vsql database file (or ":memory:") for the ORM.
pub fn open(path string) !DB {
	return new(vsql.open(path)!)
}

// new uses an existing vsql connection for the ORM.
pub fn new(conn &vsql.Connection) DB {
	return DB{
		conn: conn
	}
}

// last_id is used internally by V's ORM for post-processing `INSERT` queries.
// It's the last value that was given to a serial field.
pub fn (mut db DB) last_id() int {
	return db.last_serial
}

// execute runs a raw SQL query. All values are returned as strings.
pub fn (mut db DB) execute(query string) ![]orm.Row {
	mut result := db.conn.query(query)!
	names := result.columns.map(it.name.sub_entity_name)

	mut rows := []orm.Row{}
	for row in result {
		mut vals := []string{}
		for name in names {
			vals << row.get(name)!.str()
		}
		rows << orm.Row{
			vals:  vals
			names: names
		}
	}

	return rows
}

// orm_begin starts a transaction for the ORM.
pub fn (mut db DB) orm_begin() ! {
	db.conn.query('START TRANSACTION')!
}

// orm_commit commits a transaction for the ORM.
pub fn (mut db DB) orm_commit() ! {
	db.conn.query('COMMIT')!
}

// orm_rollback rolls back a transaction for the ORM.
pub fn (mut db DB) orm_rollback() ! {
	db.conn.query('ROLLBACK')!
}

// orm_savepoint is not supported because vsql does not have savepoints.
pub fn (mut db DB) orm_savepoint(name string) ! {
	return error('vsql does not support savepoints')
}

// orm_rollback_to is not supported because vsql does not have savepoints.
pub fn (mut db DB) orm_rollback_to(name string) ! {
	return error('vsql does not support savepoints')
}

// orm_release_savepoint is not supported because vsql does not have
// savepoints.
pub fn (mut db DB) orm_release_savepoint(name string) ! {
	return error('vsql does not support savepoints')
}
