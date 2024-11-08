module vsql

import orm
import time

pub const varchar_default_len = 255

// DDL (table creation/destroying etc)
fn vsql_type_from_v(typ int) !string {
	return if typ == orm.type_idx['i8'] || typ == orm.type_idx['i16'] || typ == orm.type_idx['u8'] {
		'SMALLINT'
	} else if typ == orm.type_idx['bool'] {
		'BOOLEAN'
	} else if typ == orm.type_idx['int'] || typ == orm.type_idx['u16'] || typ == 8 {
		'INT'
	} else if typ == orm.type_idx['i64'] || typ == orm.type_idx['u32'] {
		'BIGINT'
	} else if typ == orm.type_idx['f32'] {
		'REAL'
	} else if typ == orm.type_idx['u64'] {
		// 'NUMERIC(20)'
		'BIGINT'
	} else if typ == orm.type_idx['f64'] {
		'DOUBLE PRECISION'
	} else if typ == orm.type_idx['string'] {
		'VARCHAR(${varchar_default_len})'
	} else if typ == typeof[time.Time]().idx || typ == -2 {
		// time.Time will be converted to a string
		// will be parsed as a time.Time when read
		'TIMESTAMP(6) WITHOUT TIME ZONE'
	} else if typ == -1 {
		// SERIAL
		'INTEGER'
	} else {
		error('Unknown type ${typ}')
	}
}

// fn get_prepared_args(query_data []orm.QueryData) map[string]Value {
// 	mut mp := map[string]Value{}
// 	for i , q in query_data {
// 		// for f in q.fields {
// 		// 	type_idx :=
// 		// }
// 		// for j, v in f.data {
// 		// 	mp[':${i}_${j}'] = v
// 		// }
// 	}
// 	return mp
// }

// `query_converter_lite` converts a statement like `INSERT INTO Product (id, product_name, price) VALUES (:1, :2, :3)` to `INSERT INTO Product (id, product_name, price) VALUES (:id, :product_name, :price)`
fn query_converter_lite(query string, query_data []orm.QueryData) !string {
	mut counter := 1
	mut new_query := query
	for data in query_data {
		for field in data.fields {
			new_query = new_query.replace(':${counter}', ':${field}')
			counter++
		}
	}
	return new_query
}

fn query_converter(query string, query_data []orm.QueryData) !string {
	mut counter := 1
	mut new_query := query

	for data in query_data {
		vals := primitive_array_to_string_array(data.data)
		for val in vals {
			new_query = new_query.replace(':${counter}', val)
			counter++
		}
	}

	return new_query
}

fn primitive_array_to_string_array(prims []orm.Primitive) []string {
	mut values := prims.map(fn (p orm.Primitive) string {
		match p {
			orm.InfixType {
				// TODO(elliotchance): Not sure what this is?
				return '${p}'
			}
			time.Time {
				//
				return 'TIMESTAMP \'${p}\''
				// return '${p}'
			}
			orm.Null {
				return 'NULL'
			}
			bool {
				if p {
					return 'TRUE'
				}

				return 'FALSE'
			}
			string {
				return '\'${p}\''
			}
			f32 {
				return '${p}'
			}
			f64 {
				return '${p}'
			}
			i16 {
				return '${p}'
			}
			i64 {
				return '${p}'
			}
			i8 {
				return '${p}'
			}
			int {
				return '${p}'
			}
			u16 {
				return '${p}'
			}
			u32 {
				return '${p}'
			}
			u64 {
				return '${p}'
			}
			u8 {
				return '${p}'
			}
		}
	})
	return values
}

// select is used internally by V's ORM for processing `SELECT` queries
pub fn (mut db Connection) select(config orm.SelectConfig, data orm.QueryData, where orm.QueryData) ![][]orm.Primitive {
	// 1. Create query and bind necessary data
	// println(orm.type_idx)
	mut query := orm.orm_select_gen(config, '', true, ':', 1, where)
	query = query_converter(query, [data, where])!
	rows := db.query(query)!
	mut ret := [][]orm.Primitive{}
	for row in rows {
		mut row_primitives := []orm.Primitive{}
		keys := row.data.keys()
		for idx, key in keys {
			prim := row.get(key)!
			type_idx := config.types[idx]

			// check orm.type_idx for what these numbers are
			if type_idx == 5 {
				row_primitives << i8(prim.int_value())
			} else if type_idx == 2 {
				row_primitives << time.parse(prim.string_value())!
			} else if type_idx == 6 {
				row_primitives << i16(prim.int_value())
			} else if type_idx == 8 {
				row_primitives << int(prim.int_value())
			} else if type_idx == 9 {
				row_primitives << prim.int_value()
			} else if type_idx == 11 {
				row_primitives << u8(prim.int_value())
			} else if type_idx == 12 {
				row_primitives << u16(prim.int_value())
			} else if type_idx == 13 {
				row_primitives << u32(prim.int_value())
			} else if type_idx == 14 {
				row_primitives << u64(prim.int_value())
			} else if type_idx == 16 {
				row_primitives << f32(prim.f64_value())
			} else if type_idx == 17 {
				row_primitives << prim.f64_value()
			} else if type_idx == 19 {
				row_primitives << prim.bool_value() == .is_true
			} else {
				row_primitives << prim.string_value()
			}
		}
		ret << row_primitives
	}
	// println(ret)
	return ret
}

fn serial_name(table string) string {
	return '${table}_SERIAL'
}

fn get_table_columns(mut db Connection, table string, data []orm.QueryData) !map[string]Value {
	mut mp := map[string]Value{}
	mut tbl := Table{}
	mut cat := db.catalog()
	tables := cat.schema_tables('PUBLIC') or { [] }
	for t in tables {
		if t.name.entity_name == table.to_upper() {
			tbl = t
			break
		}
	}
	if tbl.name.entity_name != table.to_upper() {
		return error('Table ${table} not found')
	}
	for d in data {
		for i, f in d.fields {
			for c in tbl.columns {
				if c.name.sub_entity_name == f.to_upper() {
					mp[f] = primitive_to_value(c.typ, d.data[i])!
				}
			}
		}
	}

	return mp
}

// insert is used internally by V's ORM for processing `INSERT` queries
pub fn (mut db Connection) insert(table string, data orm.QueryData) ! {
	// println(data)
	// mut tbl := get_table_columns(mut db, table, [data]) or { return err }
	// println(tbl)

	mut values := primitive_array_to_string_array(data.data)
	if data.auto_fields.len > 1 {
		return error('multiple AUTO fields are not supported')
	} else if data.auto_fields.len == 1 {
		// println(data)
		values[data.auto_fields[0]] = 'NEXT VALUE FOR "${serial_name(table)}"'
	}
	mut nums := []string{}
	for i, _ in data.fields {
		nums << '${i}'
	}
	insert_sql := 'INSERT INTO ${table} (${data.fields.join(', ')}) VALUES (${values.join(', ')})'
	println(insert_sql)
	// println(tbl)
	$if trace_vsql_orm ? {
		eprintln('> vsql insert: ${query}')
	}
	db.query(insert_sql) or { return err }
	// mut stmt := db.prepare(insert_sql) or { return err }
	// stmt.query(tbl) or { return err }
}

// update is used internally by V's ORM for processing `UPDATE` queries
pub fn (mut db Connection) update(table string, data orm.QueryData, where orm.QueryData) ! {
	mut query, _ := orm.orm_stmt_gen(.sqlite, table, '', .update, true, ':', 1, data,
		where)

	// values := get_table_columns(mut db, table, [data, where]) or { return err }
	query = query_converter(query, [data, where])!
	println(query)

	$if trace_vsql_orm ? {
		eprintln('> vsql update: ${query}')
	}
	db.query(query) or { return err }
	// mut stmt := db.prepare(query) or { return err }
	// stmt.query(values) or { return err }
}

// delete is used internally by V's ORM for processing `DELETE ` queries
pub fn (mut db Connection) delete(table string, where orm.QueryData) ! {
	mut query, _ := orm.orm_stmt_gen(.sqlite, table, '', .delete, true, ':', 1, orm.QueryData{},
		where)

	query = query_converter(query, [where])!
	// values := get_table_columns(mut db, table, [where]) or { return err }

	$if trace_vsql_orm ? {
		eprintln('> vsql delete: ${query}')
	}
	db.query(query) or { return err }
	// mut stmt := db.prepare(query) or { return err }
	// stmt.query(values) or { return err }
}

// `last_id` is used internally by V's ORM for post-processing `INSERT` queries
// TODO i dont think vsql supports this
pub fn (mut db Connection) last_id() int {
	return 0
}

// create is used internally by V's ORM for processing table creation queries (DDL)
pub fn (mut db Connection) create(table string, fields []orm.TableField) ! {
	check_for_not_supported(mut db, table, fields) or { return err }
	mut new_table := table
	if is_reserved_word(table) {
		new_table = '"${table}"'
	}
	mut query := orm.orm_table_gen(new_table, '', true, 0, fields, vsql_type_from_v, false) or {
		return err
	}
	// 'IF NOT EXISTS' is not supported in vsql, so we remove it
	query = query.replace(' IF NOT EXISTS ', ' ')
	// `TEXT` is not supported in vsql, so we replace it with `VARCHAR(255) if its somehow used`
	query = query.replace('TEXT', 'VARCHAR(${varchar_default_len})')

	$if trace_vsql_orm ? {
		eprintln('> vsql create: ${query}')
	}
	// println(query)
	// println(table)
	// println(fields)
	db.query(query) or { return err }
}

// drop is used internally by V's ORM for processing table destroying queries (DDL)
pub fn (mut db Connection) drop(table string) ! {
	query := 'DROP TABLE ${table};'
	$if trace_vsql_orm ? {
		eprintln('> vsql drop: ${query}')
	}

	db.query(query) or { return err }

	// // check to see if there is a SEQUENCE for the table (for the @[sql: 'serial'] attribute)
	db.query('EXPLAIN DROP SEQUENCE "${serial_name(table)}"') or { return }
	// if we have not returned then we can drop the sequence
	db.query('DROP SEQUENCE "${serial_name(table)}"') or { return err }
}

fn check_for_not_supported(mut db Connection, table string, fields []orm.TableField) ! {
	for field in fields {
		if field.typ == orm.enum_ {
			return error('enum is not supported in vsql')
		}
		if is_reserved_word(field.name) {
			return error('reserved word ${field.name} cannot be used as a field name at ${table}.${field.name}')
		}
		for attr in field.attrs {
			if attr.name == 'sql' {
				if attr.arg == 'serial' {
					db.query('CREATE SEQUENCE "${serial_name(table)}"')!
				}
				if is_reserved_word(attr.arg) {
					return error('${attr.arg} is a reserved word in vsql')
				}
			}
			if attr.name == 'default' {
				return error('default is not supported in vsql')
			}
			if attr.name == 'unique' {
				return error('unique is not supported in vsql')
			}
			if attr.name == 'primary' {
				eprintln('primary is supported, but currently will break delete queries')
				// return error('primary is supported, but currently will break delete queries')
			}
		}
	}
}

// primitive_to_value returns the Value of a Primitive based on the intended
// destination type. Primitives are used by the ORM.
//
// It's important to note that while types may be compatible, they can still be
// out of range, such as assigning an overflowing integer value to SMALLINT.
fn primitive_to_value(typ Type, p orm.Primitive) !Value {
	// The match should be exhaustive for typ and p so that we can make sure we
	// cover all combinations now and in the future.
	match p {
		orm.Null {
			// In standard SQL, NULL's must be typed.
			return new_null_value(typ.typ)
		}
		bool {
			match typ.typ {
				.is_boolean {
					return new_boolean_value(p)
				}
				else {}
			}
		}
		f32, f64 {
			match typ.typ {
				.is_real {
					return new_real_value(f32(p))
				}
				.is_double_precision {
					return new_double_precision_value(f64(p))
				}
				else {}
			}
		}
		i16, i8, u8 {
			match typ.typ {
				.is_smallint {
					return new_smallint_value(i16(p))
				}
				else {}
			}
		}
		int, u16 {
			match typ.typ {
				.is_smallint {
					return new_smallint_value(i16(p))
				}
				.is_integer {
					return new_integer_value(int(p))
				}
				else {}
			}
		}
		u32, i64 {
			match typ.typ {
				.is_bigint {
					return new_bigint_value(i64(p))
				}
				else {}
			}
		}
		u64 {
			match typ.typ {
				.is_smallint {
					return new_smallint_value(i16(p))
				}
				else {}
			}
		}
		string {
			match typ.typ {
				.is_varchar {
					return new_varchar_value(p)
				}
				.is_numeric {
					return new_numeric_value(p)
				}
				else {}
			}
		}
		time.Time {
			match typ.typ {
				.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
					return new_timestamp_value(p.str())!
				}
				else {}
			}
		}
		orm.InfixType {}
	}

	return error('cannot assign ${p} to ${typ}')
}
