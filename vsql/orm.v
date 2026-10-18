module vsql

// A Connection can be used with V's built-in ORM:
//
//   import vsql
//
//   struct Product {
//       id    int @[primary; sql: serial]
//       name  string
//       price f64
//   }
//
//   mut db := vsql.open('test.vsql')!
//   sql db {
//       create table Product
//   }!

import orm
import time

// orm_quote is used for all table and column names. Names are delimited so that
// they keep the same case as the V struct and its fields, and so that names
// that are reserved words in SQL (such as "user" or "order") can be used.
const orm_quote = '"'

// The ORM numbers each placeholder (:p1, :p2, etc), and the number of each
// placeholder is the order of the value in the QueryData.
const orm_placeholder = ':p'

// select is used internally by V's ORM for processing `SELECT` queries.
pub fn (mut conn Connection) select(config orm.SelectConfig, data orm.QueryData, where orm.QueryData) ![][]orm.Primitive {
	query := orm.orm_select_gen_with_dialect(.vsql, config, orm_quote, true, orm_placeholder, 1,
		where)
	mut stmt := conn.prepare(query)!
	mut result := stmt.query(conn.orm_params(config.table.name, [where, data])!)!

	mut rows := [][]orm.Primitive{}
	for row in result {
		mut primitives := []orm.Primitive{}
		for i, column in result.columns {
			typ := if i < config.types.len { config.types[i] } else { orm.type_string }
			primitives << orm_primitive(row.get(column.name.sub_entity_name)!, typ)!
		}
		rows << primitives
	}

	return rows
}

// insert is used internally by V's ORM for processing `INSERT` queries.
//
// Each row is inserted with its own statement. A serial field that has no value
// is given the next value of its sequence (see create).
pub fn (mut conn Connection) insert(table orm.Table, data orm.QueryData) ! {
	row_count := if data.batch_rows > 0 { data.batch_rows } else { 1 }
	for row in 0 .. row_count {
		mut columns := []string{}
		mut values := []string{}
		mut params := map[string]Value{}
		column_types := conn.orm_column_types(table.name)!
		for i, field in data.fields {
			index := row * data.fields.len + i
			value := if index < data.data.len { data.data[index] } else { orm.null_primitive }
			columns << '${orm_quote}${field}${orm_quote}'

			if i in data.auto_fields && orm_is_auto_value(value) {
				conn.orm_last_id = int(conn.orm_next_serial(table.name, field)!)
				values << conn.orm_last_id.str()
				continue
			}

			name := 'p${params.len + 1}'
			params[name] = conn.orm_to_column_value(value, column_types[field])!
			values << ':${name}'
		}

		mut stmt := conn.prepare('INSERT INTO ${orm_quote}${table.name}${orm_quote} (${columns.join(', ')}) VALUES (${values.join(', ')})')!
		stmt.query(params)!
	}
}

// update is used internally by V's ORM for processing `UPDATE` queries.
pub fn (mut conn Connection) update(table orm.Table, data orm.QueryData, where orm.QueryData) ! {
	query, _ := orm.orm_stmt_gen(.vsql, table, orm_quote, .update, true, orm_placeholder, 1, data,
		where)
	mut stmt := conn.prepare(query)!
	stmt.query(conn.orm_params(table.name, [data, where])!)!
}

// delete is used internally by V's ORM for processing `DELETE` queries.
pub fn (mut conn Connection) delete(table orm.Table, where orm.QueryData) ! {
	query, _ := orm.orm_stmt_gen(.vsql, table, orm_quote, .delete, true, orm_placeholder, 1,
		orm.QueryData{}, where)
	mut stmt := conn.prepare(query)!
	stmt.query(conn.orm_params(table.name, [where])!)!
}

// last_id is used internally by V's ORM for post-processing `INSERT` queries.
// It's the last value that was given to a serial field.
pub fn (mut conn Connection) last_id() int {
	return conn.orm_last_id
}

// create is used internally by V's ORM for processing table creation queries
// (DDL). Nothing happens if the table already exists.
//
// vsql doesn't have identity columns, so each serial field gets a sequence
// called "<table>_<field>_seq".
pub fn (mut conn Connection) create(table orm.Table, fields []orm.TableField) ! {
	if conn.orm_table_exists(table.name)! {
		return
	}

	query := orm.orm_table_gen(.vsql, table, orm_quote, true, 0, fields, orm_type_from_v,
		false)!
	conn.query(query)!

	for field in fields {
		if orm_is_serial(field) {
			conn.query('CREATE SEQUENCE ${orm_serial_name(table.name, field.name)}')!
		}
	}
}

// drop is used internally by V's ORM for processing table destroying queries
// (DDL). The sequences for serial fields are also dropped.
pub fn (mut conn Connection) drop(table orm.Table) ! {
	mut catalog := conn.catalog()
	schema := conn.current_schema
	mut sequences := map[string]bool{}
	for sequence in catalog.sequences(schema)! {
		sequences[sequence.name.entity_name] = true
	}

	mut columns := []string{}
	for t in catalog.schema_tables(schema)! {
		if t.name.entity_name == table.name {
			columns = t.column_names()
		}
	}

	conn.query('DROP TABLE ${orm_quote}${table.name}${orm_quote}')!

	for column in columns {
		if '${table.name}_${column}_seq' in sequences {
			conn.query('DROP SEQUENCE ${orm_serial_name(table.name, column)}')!
		}
	}
}

// execute runs a raw SQL query. All values are returned as strings.
pub fn (mut conn Connection) execute(query string) ![]orm.Row {
	mut result := conn.query(query)!
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
pub fn (mut conn Connection) orm_begin() ! {
	conn.query('START TRANSACTION')!
}

// orm_commit commits a transaction for the ORM.
pub fn (mut conn Connection) orm_commit() ! {
	conn.query('COMMIT')!
}

// orm_rollback rolls back a transaction for the ORM.
pub fn (mut conn Connection) orm_rollback() ! {
	conn.query('ROLLBACK')!
}

// orm_savepoint is not supported because vsql does not have savepoints.
pub fn (mut conn Connection) orm_savepoint(name string) ! {
	return error('vsql does not support savepoints')
}

// orm_rollback_to is not supported because vsql does not have savepoints.
pub fn (mut conn Connection) orm_rollback_to(name string) ! {
	return error('vsql does not support savepoints')
}

// orm_release_savepoint is not supported because vsql does not have
// savepoints.
pub fn (mut conn Connection) orm_release_savepoint(name string) ! {
	return error('vsql does not support savepoints')
}

fn (mut conn Connection) orm_table_exists(name string) !bool {
	mut catalog := conn.catalog()
	for t in catalog.schema_tables(conn.current_schema)! {
		if t.name.entity_name == name {
			return true
		}
	}

	return false
}

fn (mut conn Connection) orm_next_serial(table string, field string) !i64 {
	mut result := conn.query('VALUES NEXT VALUE FOR ${orm_serial_name(table, field)}')!
	for row in result {
		return row.get('COL1')!.int_value()
	}

	return error('no value for ${orm_serial_name(table, field)}')
}

fn orm_serial_name(table string, field string) string {
	return '${orm_quote}${table}_${field}_seq${orm_quote}'
}

fn orm_is_serial(field orm.TableField) bool {
	return field.attrs.any(it.name == 'sql' && it.arg == 'serial')
}

// is_auto_value is true when a serial field should be given the next value of
// its sequence. That's when the field was left as zero, like other databases.
fn orm_is_auto_value(p orm.Primitive) bool {
	return match p {
		orm.Null { true }
		i8, i16, int, i64, u8, u16, u32, u64 { u64(p) == 0 }
		else { false }
	}
}

// orm_type_from_v returns the SQL type for a V type, see orm.type_idx.
fn orm_type_from_v(typ int) !string {
	return match typ {
		orm.type_idx['i8'], orm.type_idx['i16'], orm.type_idx['u8'] {
			'SMALLINT'
		}
		orm.type_idx['int'], orm.type_idx['u16'], orm.serial, orm.enum_ {
			'INTEGER'
		}
		orm.type_idx['i64'], orm.type_idx['u32'] {
			'BIGINT'
		}
		// A u64 can be larger than a BIGINT.
		orm.type_idx['u64'] {
			'NUMERIC(20)'
		}
		orm.type_idx['bool'] {
			'BOOLEAN'
		}
		orm.type_idx['f32'] {
			'REAL'
		}
		orm.type_idx['f64'] {
			'DOUBLE PRECISION'
		}
		orm.type_idx['string'] {
			'CHARACTER VARYING(${orm.string_max_len})'
		}
		orm.time_ {
			'TIMESTAMP(6) WITHOUT TIME ZONE'
		}
		else {
			error('vsql: unknown type ${typ}')
		}
	}
}

// params turns the values of each QueryData into the placeholders :p1, :p2,
// etc, in the same order that the ORM numbers them.
fn (mut conn Connection) orm_params(table string, data []orm.QueryData) !map[string]Value {
	column_types := conn.orm_column_types(table)!
	mut values := map[string]Value{}
	for d in data {
		// IS NULL and IS NOT NULL have a field, but no value.
		mut fields := []string{}
		for i, field in d.fields {
			if i >= d.kinds.len || d.kinds[i] !in [.is_null, .is_not_null] {
				fields << field
			}
		}

		for i, p in d.data {
			typ := if i < fields.len { column_types[fields[i]] } else { none }
			values['p${values.len + 1}'] = conn.orm_to_column_value(p, typ)!
		}
	}

	return values
}

// orm_column_types returns the type of each column in a table, so that values
// can be converted to the column's type. For example, a string can be used for
// a NUMERIC column.
fn (mut conn Connection) orm_column_types(table string) !map[string]Type {
	mut types := map[string]Type{}
	mut catalog := conn.catalog()
	for t in catalog.schema_tables(conn.current_schema)! {
		if t.name.entity_name == table {
			for column in t.columns {
				types[column.name.sub_entity_name] = column.typ
			}
		}
	}

	return types
}

// orm_to_column_value converts a value from V to the type of the column, if
// it's known.
fn (mut conn Connection) orm_to_column_value(p orm.Primitive, column_type ?Type) !Value {
	typ := column_type or { return orm_to_value(p)! }
	if p is orm.Null {
		return new_null_value(typ.typ)
	}

	value := orm_to_value(p)!
	if value.typ.typ == typ.typ {
		return value
	}

	return cast(mut conn, 'for ORM value', value, typ)
}

// orm_to_value converts a value from V to vsql.
fn orm_to_value(p orm.Primitive) !Value {
	return match p {
		orm.Null { new_null_value(.is_varchar) }
		bool { new_boolean_value(p) }
		i8, i16, u8 { new_smallint_value(i16(p)) }
		int, u16 { new_integer_value(int(p)) }
		i64, u32 { new_bigint_value(i64(p)) }
		u64 { new_numeric_value(p.str()) }
		f32 { new_real_value(p) }
		f64 { new_double_precision_value(p) }
		string { new_varchar_value(p) }
		time.Time { new_timestamp_value(p.format_ss_micro())! }
		orm.InfixType { orm_to_value(p.right)! }
		else { error('vsql: ${p.type_name()} is not supported') }
	}
}

// orm_primitive converts a value from vsql to the V type that the ORM expects,
// see orm.type_idx. The column may have a different type to the V field, such
// as an int field with @[sql_type: 'NUMERIC(10)'].
fn orm_primitive(v Value, typ int) !orm.Primitive {
	if v.is_null {
		return orm.null_primitive
	}

	return match typ {
		orm.type_idx['bool'] { orm.Primitive(v.bool_value() == .is_true) }
		orm.type_idx['i8'] { orm.Primitive(i8(orm_int(v))) }
		orm.type_idx['i16'] { orm.Primitive(i16(orm_int(v))) }
		orm.type_idx['int'], orm.serial, orm.enum_ { orm.Primitive(int(orm_int(v))) }
		orm.type_idx['i64'] { orm.Primitive(orm_int(v)) }
		orm.type_idx['u8'] { orm.Primitive(u8(orm_int(v))) }
		orm.type_idx['u16'] { orm.Primitive(u16(orm_int(v))) }
		orm.type_idx['u32'] { orm.Primitive(u32(orm_int(v))) }
		orm.type_idx['u64'] { orm.Primitive(orm_u64(v)) }
		orm.type_idx['f32'] { orm.Primitive(f32(orm_f64(v))) }
		orm.type_idx['f64'] { orm.Primitive(orm_f64(v)) }
		orm.time_ { orm.Primitive(v.time_value().t) }
		else { orm.Primitive(orm_string(v)) }
	}
}

fn orm_int(v Value) i64 {
	if v.typ.uses_int() {
		return v.int_value()
	}

	if v.typ.uses_string() {
		return v.string_value().i64()
	}

	return v.as_int()
}

// orm_u64 is separate from orm_int because a u64 is stored as NUMERIC(20),
// which can be larger than an i64.
fn orm_u64(v Value) u64 {
	if v.typ.uses_int() {
		return u64(v.int_value())
	}

	return orm_string(v).u64()
}

fn orm_f64(v Value) f64 {
	if v.typ.uses_f64() {
		return v.f64_value()
	}

	if v.typ.uses_int() {
		return f64(v.int_value())
	}

	return orm_string(v).f64()
}

fn orm_string(v Value) string {
	if v.typ.uses_string() {
		return v.string_value()
	}

	return v.str()
}
