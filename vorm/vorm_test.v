module vorm

import time

struct Product {
	id    int @[primary; sql: serial]
	name  string
	price f64
	stock int
}

// "order" is a reserved word in SQL.
@[table: 'order']
struct Order {
	id       int @[primary; sql: serial]
	note     ?string
	paid     bool
	small    i16
	big      i64
	ratio    f32
	tiny     u8
	placed   time.Time
	shipped  ?time.Time
	quantity ?int
}

fn new_db() !DB {
	mut db := open(':memory:')!

	sql db {
		create table Product
	}!

	products := [
		Product{
			name:  'Ice Cream'
			price: 5.99
			stock: 10
		},
		Product{
			name:  'Ham Sandwhich'
			price: 3.47
			stock: 5
		},
		Product{
			name:  'Bagel'
			price: 1.25
			stock: 20
		},
	]
	for product in products {
		sql db {
			insert product into Product
		}!
	}

	return db
}

fn test_insert_and_select() {
	mut db := new_db()!
	assert db.last_id() == 3

	products := sql db {
		select from Product order by id
	}!
	assert products == [
		Product{1, 'Ice Cream', 5.99, 10},
		Product{2, 'Ham Sandwhich', 3.47, 5},
		Product{3, 'Bagel', 1.25, 20},
	]
}

fn test_where() {
	mut db := new_db()!

	products := sql db {
		select from Product where price < 4.0 && stock > 5
	}!
	assert products.map(it.name) == ['Bagel']

	products2 := sql db {
		select from Product where name == 'Ice Cream' || name == 'Bagel' order by name desc
	}!
	assert products2.map(it.name) == ['Ice Cream', 'Bagel']
}

fn test_limit_and_offset() {
	mut db := new_db()!

	products := sql db {
		select from Product order by id limit 2 offset 1
	}!
	assert products.map(it.id) == [2, 3]
}

fn test_count() {
	mut db := new_db()!

	count := sql db {
		select count from Product where stock >= 10
	}!
	assert count == 2
}

fn test_update() {
	mut db := new_db()!

	sql db {
		update Product set price = 1.5, stock = stock + 5 where name == 'Bagel'
	}!

	products := sql db {
		select from Product where id == 3
	}!
	assert products == [Product{3, 'Bagel', 1.5, 25}]
}

fn test_delete() {
	mut db := new_db()!

	sql db {
		delete from Product where stock < 10
	}!

	products := sql db {
		select from Product order by id
	}!
	assert products.map(it.id) == [1, 3]
}

fn test_batch_insert() {
	mut db := new_db()!

	products := [Product{
		name: 'Muffin'
	}, Product{
		name: 'Scone'
	}]
	sql db {
		insert products into Product
	}!
	assert db.last_id() == 5

	names := sql db {
		select from Product where id > 3 order by id
	}!
	assert names.map(it.name) == ['Muffin', 'Scone']
}

fn test_types_and_nulls() {
	mut db := open(':memory:')!

	sql db {
		create table Order
	}!

	placed := time.new(
		year:       2024
		month:      2
		day:        3
		hour:       4
		minute:     5
		second:     6
		nanosecond: 7000
	)
	orders := [
		Order{
			note:     'first'
			paid:     true
			small:    -3
			big:      9_000_000_000
			ratio:    0.5
			tiny:     255
			placed:   placed
			shipped:  placed
			quantity: 7
		},
		Order{
			placed: placed
		},
	]
	for order in orders {
		sql db {
			insert order into Order
		}!
	}

	got := sql db {
		select from Order order by id
	}!
	assert got.len == 2
	assert got[0].id == 1
	assert got[0].note or { '' } == 'first'
	assert got[0].paid
	assert got[0].small == -3
	assert got[0].big == 9_000_000_000
	assert got[0].ratio == 0.5
	assert got[0].tiny == 255
	assert got[0].placed == placed
	assert got[0].shipped or { time.Time{} } == placed
	assert got[0].quantity or { 0 } == 7

	assert got[1].id == 2
	assert got[1].note == none
	assert !got[1].paid
	assert got[1].shipped == none
	assert got[1].quantity == none

	unpaid := sql db {
		select from Order where note is none
	}!
	assert unpaid.map(it.id) == [2]
}

fn test_create_twice() {
	mut db := new_db()!

	sql db {
		create table Product
	}!

	count := sql db {
		select count from Product
	}!
	assert count == 3
}

fn test_drop() {
	mut db := new_db()!

	sql db {
		drop table Product
	}!

	// The sequence for the serial field is dropped too, so the table can be
	// created again and starts from 1.
	sql db {
		create table Product
	}!
	product := Product{
		name: 'Bagel'
	}
	sql db {
		insert product into Product
	}!
	assert db.last_id() == 1
}

fn test_transaction() {
	mut db := new_db()!

	product := Product{
		name: 'Muffin'
	}
	db.orm_begin()!
	sql db {
		insert product into Product
	}!
	db.orm_rollback()!

	count := sql db {
		select count from Product
	}!
	assert count == 3

	db.orm_savepoint('a') or {
		assert err.msg() == 'vsql does not support savepoints'
		return
	}
	assert false
}

fn test_execute() {
	mut db := new_db()!

	rows := db.execute('SELECT "name", "stock" FROM "product" WHERE "id" = 3')!
	assert rows.len == 1
	assert rows[0].names == ['name', 'stock']
	assert rows[0].vals == ['Bagel', '20']
}

fn test_unique() {
	mut db := open(':memory:')!

	sql db {
		create table UniqueName
	}!

	first := UniqueName{
		city:  'p'
		name:  'a'
		first: 'b'
		last:  'c'
	}
	sql db {
		insert first into UniqueName
	}!

	same_name := UniqueName{
		city:  'q'
		name:  'a'
		first: 'x'
		last:  'y'
	}
	mut failed := false
	sql db {
		insert same_name into UniqueName
	} or {
		assert err.msg() == 'violates unique constraint: UNIQUE ("name") on ":memory:".PUBLIC."uniquename"'
		failed = true
	}
	assert failed

	same_key := UniqueName{
		city:  'r'
		name:  'd'
		first: 'b'
		last:  'c'
	}
	failed = false
	sql db {
		insert same_key into UniqueName
	} or {
		assert err.msg() == 'violates unique constraint: UNIQUE ("first", "last") on ":memory:".PUBLIC."uniquename"'
		failed = true
	}
	assert failed

	same_group := UniqueName{
		city:  'p'
		name:  'e'
		first: 'f'
		last:  'g'
	}
	sql db {
		insert same_group into UniqueName
	} or {
		assert err.msg() == 'violates unique constraint: UNIQUE ("city", "zip") on ":memory:".PUBLIC."uniquename"'
		return
	}
	assert false
}

@[unique_key: 'first, last']
struct UniqueName {
	name  string @[unique]
	first string
	last  string
	city  string @[unique: 'address']
	zip   string @[unique: 'address']
}

fn test_references() {
	mut db := open(':memory:')!

	sql db {
		create table Parent
		create table Child
	}!

	parent := Parent{}
	sql db {
		insert parent into Parent
	}!
	child := Child{
		parent_id: 1
	}
	sql db {
		insert child into Child
	}!

	orphan := Child{
		parent_id: 2
	}
	sql db {
		insert orphan into Child
	} or {
		assert err.msg().starts_with('violates foreign key constraint: ')
		return
	}
	assert false
}

struct Parent {
	id int @[primary; sql: serial]
}

struct Child {
	id        int @[primary; sql: serial]
	parent_id int @[references]
}

fn test_default() {
	mut db := open(':memory:')!

	sql db {
		create table WithDefault
	}!

	db.execute('INSERT INTO "withdefault" ("id") VALUES (1)')!
	rows := sql db {
		select from WithDefault
	}!
	assert rows == [WithDefault{
		id:    1
		count: 7
		label: 'none'
	}]
}

struct WithDefault {
	id    int
	count int    @[default: 7]
	label string @[default: '`none`']
}

enum Color {
	red
	green
	blue
}

// Attributes covers the naming and type attributes for fields.
struct Attributes {
	id              int @[primary; sql: serial]
	where           int // a reserved word
	renamed         int @[sql: 'secret_name']
	skipped         int @[skip]
	skipped_as_well int @[sql: '-']
	stored_as_text  int @[sql: string]
	small           int @[sql: i8]
	exact           int @[sql_type: 'NUMERIC(10)']
	tiny            i8
	medium          u16
	large           u32
	huge            u64
	color           Color
}

fn test_attributes() {
	mut db := open(':memory:')!

	sql db {
		create table Attributes
	}!

	mut catalog := db.conn.catalog()
	mut columns := map[string]string{}
	for t in catalog.schema_tables('PUBLIC')! {
		assert t.primary_key == ['id']
		for column in t.columns {
			columns[column.name.sub_entity_name] = column.typ.str()
		}
	}
	assert columns == {
		'id':             'INTEGER'
		'where':          'INTEGER'
		'secret_name':    'INTEGER'
		'stored_as_text': 'CHARACTER VARYING(2048)'
		'small':          'SMALLINT'
		'exact':          'NUMERIC(10)'
		'tiny':           'SMALLINT'
		'medium':         'INTEGER'
		'large':          'BIGINT'
		'huge':           'NUMERIC(20)'
		'color':          'INTEGER'
	}

	row := Attributes{
		where:           1
		renamed:         2
		skipped:         3
		skipped_as_well: 4
		stored_as_text:  5
		small:           6
		exact:           7
		tiny:            -8
		medium:          65535
		large:           4294967295
		huge:            18446744073709551615
		color:           .blue
	}
	sql db {
		insert row into Attributes
	}!

	got := sql db {
		select from Attributes where huge > 9223372036854775807
	}!
	assert got == [Attributes{
		...row
		id:              1
		skipped:         0
		skipped_as_well: 0
	}]
}

// Price is stored as an exact number, but used as a string in V.
struct Price {
	id       int @[primary; sql: serial]
	name     string
	price    string @[sql_type: 'NUMERIC(5,2)']
	quantity ?i16
}

fn test_where_operators() {
	mut db := open(':memory:')!

	sql db {
		create table Price
	}!
	prices := [
		Price{
			name:     'Ice Cream'
			price:    '5.99'
			quantity: 17
		},
		Price{
			name:  'Ham Sandwhich'
			price: '3.47'
		},
		Price{
			name:     'Bagel'
			price:    '1.25'
			quantity: 45
		},
	]
	for price in prices {
		sql db {
			insert price into Price
		}!
	}

	not_equal := sql db {
		select from Price where id != 3
	}!
	assert not_equal.map(it.id) == [1, 2]

	greater := sql db {
		select from Price where price > '3.47'
	}!
	assert greater.map(it.id) == [1]

	greater_or_equal := sql db {
		select from Price where price >= '3'
	}!
	assert greater_or_equal.map(it.id) == [1, 2]

	less_or_equal := sql db {
		select from Price where price <= '5'
	}!
	assert less_or_equal.map(it.id) == [2, 3]

	like := sql db {
		select from Price where name like 'Ham%'
	}!
	assert like.map(it.id) == [2]

	not_none := sql db {
		select from Price where quantity !is none && price < '3'
	}!
	assert not_none == [Price{3, 'Bagel', '1.25', 45}]

	grouped := sql db {
		select from Price where (price < '2' || name like 'Ice%') && id != 1
	}!
	assert grouped.map(it.id) == [3]
}

// Converted is read from a table that wasn't created by the ORM, so the types of
// its columns are different from the types of the fields.
@[table: 'converted']
struct Converted {
	from_double  i64
	from_integer u64
	as_float     f64
	from_numeric f64
}

fn test_converted_types() {
	mut db := open(':memory:')!
	db.conn.query('CREATE TABLE "converted" ("from_double" DOUBLE PRECISION, "from_integer" INTEGER, "as_float" INTEGER, "from_numeric" NUMERIC(10, 2))')!
	db.conn.query('INSERT INTO "converted" ("from_double", "from_integer", "as_float", "from_numeric") VALUES (12.75e0, 7, 3, 2.5)')!

	got := sql db {
		select from Converted
	}!
	assert got.len == 1
	assert got[0].from_double == 12
	assert got[0].from_integer == 7
	assert got[0].as_float == 3.0
	assert got[0].from_numeric == 2.5
}
