module vsql

// Structs intentionally have less than 6 fields, any more then inserts queries get exponentially slower.
import time

// struct TestDateTypes {
// 	id      int    @[primary; sql: serial]
// 	custom1 string @[sql_type: 'TIME WITH TIME ZONE']
// 	custom2 string @[sql_type: 'TIMESTAMP(3) WITH TIME ZONE']
// 	custom3 string @[sql_type: 'INT']
// 	custom4 string @[sql_type: 'DATE']
// 	custom5 string @[sql_type: 'TIMESTAMP(3) WITHOUT TIME ZONE']
// 	custom6 string @[sql_type: 'TIME WITHOUT TIME ZONE']
// }

@[table: 'testcustomtable']
struct TestCustomTableAndSerial {
	id      int @[sql: serial]
	an_bool bool
}

struct TestPrimaryBroken {
	id int @[primary; sql: serial]
}

struct TestDefaultAttribute {
	id         int @[sql: serial]
	name       string
	created_at string @[default: 'CURRENT_TIMESTAMP(6)'; sql_type: 'TIMESTAMP(3) WITHOUT TIME ZONE']
}

struct TestUniqueAttribute {
	attribute string @[unique]
}

struct TestReservedWordField {
	where string
}

struct TestReservedWordSqlAttribute {
	ok string @[sql: 'ORDER']
}

struct TestOrmValuesOne {
	an_f32 f32 // REAL
	an_f64 f64 // DOUBLE PRECISION
	an_i16 i16 // SMALLINT
	an_i64 i64 // BIGINT
}

struct TestOrmValuesTwo {
	an_i8    i8     // SMALLINT
	an_int   int    // INTEGER
	a_string string // CHARACTER VARYING(255)
}

struct TestOrmValuesThree {
	an_u16 u16 // INTEGER
	an_u32 u32 // BIGINT
	an_u64 u64 // BIGINT
	an_u8  u8  // SMALLINT
}

struct TestOrmValuesFour {
	a_time      time.Time // TIMESTAMP(6) WITH TIME ZONE
	a_bool      bool      // BOOLEAN
	int_or_null ?int      // optional int
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

// @[table: 'GROUP']
struct ORMTable2 {
	dummy int
}

fn test_orm_create_success2() {
	mut db := open(':memory:')!
	sql db {
		create table ORMTable2
	}!
	dumm := ORMTable2{dummy: 1}
	sql db {
		insert dumm into ORMTable2
	}!

	sql db {
		drop table ORMTable2
	}!
}

// We cannot test this because it will make all tests fail, because the database itself will run into an error
// so it is put behind a -d flag if you really want to try it
fn test_primary_key_broken() {
	$if test_primary_key ? {
		mut db := open(':memory:')!
		mut error := ''
		sql db {
			create table TestPrimaryBroken
		} or { error = err.str() }
		assert error == ''

		test_primary_broken := TestPrimaryBroken{}

		sql db {
			insert test_primary_broken into TestPrimaryBroken
		} or { error = err.str() }
		assert error == ''

		mut all := sql db {
			select from TestPrimaryBroken
		}!

		sql db {
			delete from TestPrimaryBroken where id == all[0].id
		} or { error = err.str() }
	}
}

fn test_custom_table_name_and_serial_crud() {
	mut db := open(':memory:')!
	mut error := ''
	sql db {
		create table TestCustomTableAndSerial
	} or { error = err.str() }
	assert error == ''

	test_custom_sql := TestCustomTableAndSerial{
		an_bool: true
	}
	test_custom_sql2 := TestCustomTableAndSerial{
		an_bool: false
	}

	sql db {
		insert test_custom_sql into TestCustomTableAndSerial
		insert test_custom_sql2 into TestCustomTableAndSerial
	} or { error = err.str() }

	assert error == ''
	mut all := sql db {
		select from TestCustomTableAndSerial
	}!
	assert all[0].id != 0

	sql db {
		update TestCustomTableAndSerial set an_bool = false where id == all[0].id
	} or { error = err.str() }
	assert error == ''

	sql db {
		delete from TestCustomTableAndSerial where id == all[1].id
	} or { error = err.str() }
	assert error == ''

	all = sql db {
		select from TestCustomTableAndSerial
	}!
	assert all.len == 1
	assert all[0].an_bool == false

	sql db {
		drop table TestCustomTableAndSerial
	} or { error = err.str() }

	assert error == ''
}

fn test_reserved_words() {
	mut db := open(':memory:')!
	mut error := ''
	sql db {
		create table TestReservedWordField
	} or { error = err.str() }
	assert error == 'reserved word where cannot be used as a field name at TestReservedWordField.where'
	sql db {
		create table TestReservedWordSqlAttribute
	} or { error = err.str() }
	assert error == 'ORDER is a reserved word in vsql'
}

fn test_unsupported_attributes() {
	mut db := open(':memory:')!
	mut error := ''
	sql db {
		create table TestDefaultAttribute
	} or { error = err.str() }
	assert error == 'default is not supported in vsql'
	sql db {
		create table TestUniqueAttribute
	} or { error = err.str() }
	assert error == 'unique is not supported in vsql'
}

fn test_default_orm_values() {
	mut db := open(':memory:')!
	mut error := ''
	sql db {
		create table TestOrmValuesOne
		create table TestOrmValuesTwo
		create table TestOrmValuesThree
		create table TestOrmValuesFour
	} or { error = err.str() }
	assert error == ''

	values_one := TestOrmValuesOne{
		an_f32: 3.14
		an_f64: 2.718281828459
		an_i16: 12345
		an_i64: 123456789012345
	}
	values_two := TestOrmValuesTwo{
		an_i8:    12
		an_int:   123456
		a_string: 'Hello, World!'
	}
	values_three := TestOrmValuesThree{
		an_u16: 54321
		an_u32: 1234567890
		an_u64: 1234
		an_u8:  255
	}

	values_four := TestOrmValuesFour{
		a_time: time.now()
		a_bool: true
		// int_or_null: 123
	}
	values_four_b := TestOrmValuesFour{
		a_time:      time.now()
		a_bool:      false
		int_or_null: 123
	}

	sql db {
		insert values_one into TestOrmValuesOne
		insert values_two into TestOrmValuesTwo
		insert values_three into TestOrmValuesThree
		insert values_four into TestOrmValuesFour
		insert values_four_b into TestOrmValuesFour
	} or { error = err.str() }
	assert error == ''

	result_values_one := sql db {
		select from TestOrmValuesOne
	}!
	one := result_values_one[0]

	assert typeof(one.an_f32).idx == typeof[f32]().idx
	assert one.an_f32 == 3.14
	assert typeof(one.an_f64).idx == typeof[f64]().idx
	assert one.an_f64 == 2.718281828459
	assert typeof(one.an_i16).idx == typeof[i16]().idx
	assert one.an_i16 == 12345
	assert typeof(one.an_i64).idx == typeof[i64]().idx
	assert one.an_i64 == 123456789012345

	result_values_two := sql db {
		select from TestOrmValuesTwo
	}!

	two := result_values_two[0]

	assert typeof(two.an_i8).idx == typeof[i8]().idx
	assert two.an_i8 == 12
	assert typeof(two.an_int).idx == typeof[int]().idx
	assert two.an_int == 123456
	assert typeof(two.a_string).idx == typeof[string]().idx
	assert two.a_string == 'Hello, World!'

	result_values_three := sql db {
		select from TestOrmValuesThree
	}!

	three := result_values_three[0]

	assert typeof(three.an_u16).idx == typeof[u16]().idx
	assert three.an_u16 == 54321
	assert typeof(three.an_u32).idx == typeof[u32]().idx
	assert three.an_u32 == 1234567890
	// println(three.an_u64)
	assert typeof(three.an_u64).idx == typeof[u64]().idx
	assert three.an_u64 == 1234
	assert typeof(three.an_u8).idx == typeof[u8]().idx
	assert three.an_u8 == 255

	result_values_four := sql db {
		select from TestOrmValuesFour
	}!

	four := result_values_four[0]

	assert typeof(four.a_time).idx == typeof[time.Time]().idx
	assert typeof(four.a_bool).idx == typeof[bool]().idx
	assert four.a_bool == true
	assert typeof(four.int_or_null).idx == typeof[?int]().idx
	unwrapped_option_one := four.int_or_null or { 0 }
	assert unwrapped_option_one == 0
	unwrapped_option_two := result_values_four[1].int_or_null or { 0 }
	assert unwrapped_option_two == 123
}

fn test_orm_create_enum_is_not_supported() {
	mut db := open(':memory:')!
	mut error := ''
	sql db {
		create table ORMTableEnum
	} or { error = err.str() }
	assert error == 'enum is not supported in vsql'
}
