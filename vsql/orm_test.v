module vsql

import os
import time

// ORMTable1 is for testing CREATE TABLE, it has many combinations of types and
// other attributes that are verified from the generated CREATE TABLE
// afterwards.
struct ORMTable1 {
	// Each of the basic orm.Primative types without specifying any options.
	a_bool   bool      // BOOLEAN
	an_f32   f32       // REAL
	an_f64   f64       // DOUBLE PRECISION
	an_i16   i16       // SMALLINT
	an_i64   i64       // BIGINT
	an_i8    i8        // SMALLINT
	an_int   int       // INTEGER
	a_string string    // CHARACTER VARYING(255)
	a_time   time.Time // TIMESTAMP(6) WITH TIME ZONE
	an_u16   u16       // INTEGER
	an_u32   u32       // BIGINT
	an_u64   u64       // NUMERIC(20)
	an_u8    u8        // SMALLINT
	// Naming edge cases
	where       int // reserved word
	actual_name int @[sql: 'secret_name']
	order       int @[sql: 'ORDER']
	// Primary keys and other indexes.
	a_primary_key int @[primary] // PRIMARY KEY (A_PRIMARY_KEY)
	// Skipped fields
	this_is_skipped int @[skip]
	this_as_well    int @[sql: '-']
	// Customize types
	not_an_int      int @[sql: string]
	custom_sql_type int @[sql_type: 'NUMERIC(10)']
	// Nullable types
	int_or_null ?int
}

fn test_orm_create_success1() {
	mut db := new_db()
	sql db {
		create table ORMTable1
	}!

	mut c := db.connection()
	mut catalog := c.catalog()
	mut table := catalog.schema_table('PUBLIC', 'ORMTABLE1')!
	assert table.str() == 'CREATE TABLE "test".PUBLIC.ORMTABLE1 (
  A_BOOL BOOLEAN NOT NULL,
  AN_F32 REAL NOT NULL,
  AN_F64 DOUBLE PRECISION NOT NULL,
  AN_I16 SMALLINT NOT NULL,
  AN_I64 BIGINT NOT NULL,
  AN_I8 SMALLINT NOT NULL,
  AN_INT INTEGER NOT NULL,
  A_STRING CHARACTER VARYING(2048) NOT NULL,
  A_TIME TIMESTAMP(6) WITH TIME ZONE NOT NULL,
  AN_U16 INTEGER NOT NULL,
  AN_U32 BIGINT NOT NULL,
  AN_U64 NUMERIC(20) NOT NULL,
  AN_U8 SMALLINT NOT NULL,
  "WHERE" INTEGER NOT NULL,
  "secret_name" INTEGER NOT NULL,
  "ORDER" INTEGER NOT NULL,
  A_PRIMARY_KEY INTEGER NOT NULL,
  NOT_AN_INT CHARACTER VARYING(2048) NOT NULL,
  CUSTOM_SQL_TYPE NUMERIC(10) NOT NULL,
  INT_OR_NULL INTEGER,
  PRIMARY KEY (A_PRIMARY_KEY)
);'
}

// ORMTable2 tests some cases that are not possible on ORMTable1. Specifically:
// - A custom table name (that uses a reserved word to check quoting)
// - No primary key.
@[table: 'GROUP']
struct ORMTable2 {
	dummy int
}

fn test_orm_create_success2() {
	mut db := new_db()
	sql db {
		create table ORMTable2
	}!

	mut c := db.connection()
	mut catalog := c.catalog()
	assert catalog.schema_table('PUBLIC', 'GROUP')!.str() == 'CREATE TABLE "test".PUBLIC."GROUP" (
  DUMMY INTEGER NOT NULL
);'
}

// ORMTableUnique makes sure we throw an error if @[unique] is used since it's
// not supported.
struct ORMTableUnique {
	is_unique int @[unique]
}

fn test_orm_create_unique_is_not_supported() {
	mut db := new_db()
	mut error := ''
	sql db {
		create table ORMTableUnique
	} or { error = err.str() }
	assert error == 'for is_unique: UNIQUE is not supported'
}

// ORMTableSpecificName covers the edge case where already quoted table names
// need to remain intact. This is explained in more detail in create().
//
// The extra escape is required for now, see bug
// https://github.com/vlang/v/issues/20313.
@[table: '\"specific name\"']
struct ORMTableSpecificName {
	dummy int
}

fn test_orm_create_specific_name() {
	mut db := new_db()
	sql db {
		create table ORMTableSpecificName
	}!

	mut c := db.connection()
	mut catalog := c.catalog()
	assert catalog.schema_table('PUBLIC', 'specific name')!.str() == 'CREATE TABLE "test".PUBLIC."specific name" (
  DUMMY INTEGER NOT NULL
);'
}

// ORMTableSerial lets the DB backend choose a column type for a auto-increment
// field.
struct ORMTableSerial {
	dummy int @[sql: serial]
}

fn test_orm_create_serial() {
	mut db := new_db()
	sql db {
		create table ORMTableSerial
	}!

	mut c := db.connection()
	mut catalog := c.catalog()
	assert catalog.schema_table('PUBLIC', 'ORMTABLESERIAL')!.str() == 'CREATE TABLE "test".PUBLIC.ORMTABLESERIAL (
  DUMMY INTEGER NOT NULL,
  PRIMARY KEY (DUMMY)
);'
}

// ORMTableEnum is not supported.
struct ORMTableEnum {
	an_enum Colors
}

enum Colors {
	red
	green
	blue
}

fn test_orm_create_enum_is_not_supported() {
	mut db := new_db()
	mut error := ''
	sql db {
		create table ORMTableEnum
	} or { error = err.str() }
	assert error == 'for an_enum: ENUM is not supported'
}

// ORMTableDefault is not supported.
struct ORMTableDefault {
	has_default int @[default: '3']
}

fn test_orm_create_default_is_not_supported() {
	mut db := new_db()
	mut error := ''
	sql db {
		create table ORMTableDefault
	} or { error = err.str() }
	assert error == 'for has_default: DEFAULT is not supported'
}

struct Product {
	id           int // @[primary] FIXME
	product_name string
	price        string @[sql_type: 'NUMERIC(5,2)']
	quantity     ?i16
}

fn test_orm_insert() {
	mut db := new_db()
	sql db {
		create table Product
	}!

	product := Product{1, 'Ice Cream', '5.99', 17}
	sql db {
		insert product into Product
	}!

	mut rows := []Product{}
	for row in sql db {
		select from Product
	}! {
		rows << row
	}

	assert rows == [product]
}

fn test_orm_update() {
	mut db := new_db_with_products()

	sql db {
		update Product set quantity = 16 where product_name == 'Ice Cream'
	}!

	assert sql db {
		select from Product
	}! == [
		Product{1, 'Ice Cream', '5.99', 16}, // 17 -> 16
		Product{2, 'Ham Sandwhich', '3.47', none},
		Product{3, 'Bagel', '1.25', 45},
	]
}

fn test_orm_delete() {
	mut db := new_db_with_products()

	sql db {
		delete from Product where product_name == 'Ice Cream'
	}!

	assert sql db {
		select from Product
	}! == [
		Product{2, 'Ham Sandwhich', '3.47', none},
		Product{3, 'Bagel', '1.25', 45},
	]
}

struct PrimaryColor {
	id   int    @[sql: serial]
	name string
}

fn test_orm_insert_serial() {
	mut db := new_db()
	sql db {
		create table PrimaryColor
	}!

	colors := [PrimaryColor{
		name: 'red'
	}, PrimaryColor{
		name: 'green'
	}, PrimaryColor{
		name: 'blue'
	}]
	for color in colors {
		sql db {
			insert color into PrimaryColor
		}!
	}

	mut rows := []PrimaryColor{}
	for row in sql db {
		select from PrimaryColor
	}! {
		rows << row
	}

	assert rows == [PrimaryColor{1, 'red'}, PrimaryColor{2, 'green'},
		PrimaryColor{3, 'blue'}]
}

@[assert_continues]
fn test_orm_select_where() {
	db := new_db_with_products()

	assert sql db {
		select from Product where id == 2
	}! == [Product{2, 'Ham Sandwhich', '3.47', none}]

	assert sql db {
		select from Product where id == 5
	}! == []

	assert sql db {
		select from Product where id != 3
	}! == [Product{1, 'Ice Cream', '5.99', 17}, Product{2, 'Ham Sandwhich', '3.47', none}]

	assert sql db {
		select from Product where price > '3.47'
	}! == [Product{1, 'Ice Cream', '5.99', 17}]

	assert sql db {
		select from Product where price >= '3'
	}! == [Product{1, 'Ice Cream', '5.99', 17}, Product{2, 'Ham Sandwhich', '3.47', none}]

	assert sql db {
		select from Product where price < '3.47'
	}! == [Product{3, 'Bagel', '1.25', 45}]

	assert sql db {
		select from Product where price <= '5'
	}! == [Product{2, 'Ham Sandwhich', '3.47', none}, Product{3, 'Bagel', '1.25', 45}]

	// TODO(elliotchance): The ORM does not support a "not like" constraint right
	// now.
	// assert sql db {
	// 	select from Product where product_name !like 'Ham%'
	// }! == [Product{2, 'Ham Sandwhich', '3.47', none}]

	assert sql db {
		select from Product where quantity is none
	}! == [Product{2, 'Ham Sandwhich', '3.47', none}]

	assert sql db {
		select from Product where quantity !is none
	}! == [Product{1, 'Ice Cream', '5.99', 17}, Product{3, 'Bagel', '1.25', 45}]

	assert sql db {
		select from Product where price > '3' && price < '3.50'
	}! == [Product{2, 'Ham Sandwhich', '3.47', none}]

	assert sql db {
		select from Product where price < '2.000' || price >= '5'
	}! == [Product{1, 'Ice Cream', '5.99', 17}, Product{3, 'Bagel', '1.25', 45}]
}

fn new_db() ORMConnection {
	os.rm('test.vsql') or {}
	return open_orm('test.vsql') or { panic(err) }
}

fn new_db_with_products() ORMConnection {
	mut db := new_db()
	sql db {
		create table Product
	} or { panic(err) }

	products := [
		Product{1, 'Ice Cream', '5.99', 17},
		Product{2, 'Ham Sandwhich', '3.47', none},
		Product{3, 'Bagel', '1.25', 45},
	]
	for product in products {
		sql db {
			insert product into Product
		} or { panic(err) }
	}

	return db
}

fn test_orm_drop_table() {
	mut db := new_db()
	sql db {
		create table Product
	}!

	sql db {
		drop table Product
	}!
}
