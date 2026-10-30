// tables.v contains the CREATE TABLE and DROP TABLE statements of the ORM, and
// finds the tables and sequences it has created.

module vorm

import orm
import vsql

// create is used internally by V's ORM for processing table creation queries
// (DDL). Nothing happens if the table already exists.
//
// vsql doesn't have identity columns, so each serial field gets a sequence
// called "<table>_<field>_seq".
pub fn (mut db DB) create(table orm.Table, fields []orm.TableField) ! {
	if table.name in db.tables()! {
		return
	}

	query := orm.orm_table_gen(.vsql, table, quote, true, 0, fields, sql_type_from_v,
		false)!
	db.conn.query(query)!

	for field in fields {
		if is_serial(field) {
			db.conn.query('CREATE SEQUENCE ${serial_name(table.name, field.name)}')!
		}
	}
}

// drop is used internally by V's ORM for processing table destroying queries
// (DDL). The sequences for serial fields are also dropped.
pub fn (mut db DB) drop(table orm.Table) ! {
	schema := db.current_schema()!
	mut sequences := map[string]bool{}
	for sequence in db.conn.catalog().sequences(schema)! {
		sequences[sequence.name.entity_name] = true
	}

	mut columns := []string{}
	if t := db.tables()![table.name] {
		columns = t.column_names()
	}

	db.conn.query('DROP TABLE ${quote}${table.name}${quote}')!

	for column in columns {
		if '${table.name}_${column}_seq' in sequences {
			db.conn.query('DROP SEQUENCE ${serial_name(table.name, column)}')!
		}
	}
}

// tables returns the tables in the current schema by name.
fn (mut db DB) tables() !map[string]vsql.Table {
	mut tables := map[string]vsql.Table{}
	for t in db.conn.catalog().schema_tables(db.current_schema()!)! {
		tables[t.name.entity_name] = t
	}

	return tables
}

fn (mut db DB) current_schema() !string {
	mut result := db.conn.query('VALUES CURRENT_SCHEMA')!
	for row in result {
		return row.get('COL1')!.str()
	}

	return error('no current schema')
}

// column_types returns the type of each column in a table, so that values can
// be converted to the column's type. For example, a string can be used for a
// NUMERIC column.
fn (mut db DB) column_types(table string) !map[string]vsql.Type {
	mut types := map[string]vsql.Type{}
	if t := db.tables()![table] {
		for column in t.columns {
			types[column.name.sub_entity_name] = column.typ
		}
	}

	return types
}

fn (mut db DB) next_serial(table string, field string) !i64 {
	mut result := db.conn.query('SELECT NEXT VALUE FOR ${serial_name(table, field)} FROM (VALUES 1) AS t')!
	for row in result {
		return row.get('COL1')!.int_value()
	}

	return error('no value for ${serial_name(table, field)}')
}

fn serial_name(table string, field string) string {
	return '${quote}${table}_${field}_seq${quote}'
}

fn is_serial(field orm.TableField) bool {
	return field.attrs.any(it.name == 'sql' && it.arg == 'serial')
}

// sql_type_from_v returns the SQL type for a V type, see orm.type_idx.
fn sql_type_from_v(typ int) !string {
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
