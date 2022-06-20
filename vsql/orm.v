// orm.v implements the V language ORM: https://modules.vlang.io/orm.html

module vsql

import orm
import time

pub struct ORMConnection {
mut:
	c Connection
}

fn (c ORMConnection) connection() Connection {
	return c.c
}

pub fn (c ORMConnection) @select(config orm.SelectConfig, data orm.QueryData, where orm.QueryData) ![][]orm.Primitive {
	mut stmt := orm.orm_select_gen(config, '', true, ':p', 0, where)

	// TODO(elliotchance): This is a (crude) work around until
	// https://github.com/vlang/v/pull/20321 is fixed.
	stmt = stmt.replace(' != ', ' <> ')

	mut catalog := unsafe { c.c.catalog() }
	table_definition := catalog.schema_table('PUBLIC', orm_table_name(config.table))!

	mut bound := map[string]Value{}
	for i, name in where.fields {
		// TODO(elliotchance): IS NULL does not have a data counterpart.
		if i < where.data.len {
			bound['p${i}'] = primitive_to_value(table_definition.column(name.to_upper())!.typ,
				where.data[i])!
		}
	}

	mut prepared := unsafe { c.c.prepare(stmt)! }
	result := prepared.query(bound)!
	mut all_rows := [][]orm.Primitive{}

	for row in result {
		mut primitive_row := []orm.Primitive{}
		for column in result.columns {
			primitive_row << row.get_primitive(column.name.str())!
		}

		all_rows << primitive_row
	}

	return all_rows
}

pub fn (c ORMConnection) insert(table string, data orm.QueryData) ! {
	mut values := data.data.map(fn (p orm.Primitive) string {
		match p {
			orm.InfixType {
				// TODO(elliotchance): Not sure what this is?
				return '${p}'
			}
			time.Time {
				// TODO(elliotchance): This doesn't work.
				return '${p}'
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
				// TODO(elliotchance): Does not escape correctly.
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

	// Substitute SERIAL/AUTO.
	if data.auto_fields.len > 1 {
		return error('multiple AUTO fields are not supported')
	} else if data.auto_fields.len == 1 {
		values[data.auto_fields[0]] = 'NEXT VALUE FOR "${serial_name(table)}"'
	}

	insert_sql := 'INSERT INTO ${table} (${data.fields.join(', ')}) VALUES (${values.join(', ')})'
	c.execute(insert_sql)!
}

fn extract_bound_params(table_definition Table, offset int, data orm.QueryData) !map[string]Value {
	mut bound := map[string]Value{}
	for i, name in data.fields {
		// TODO(elliotchance): IS NULL does not have a data counterpart.
		if i < data.data.len {
			bound['p${i + offset}'] = primitive_to_value(table_definition.column(name.to_upper())!.typ,
				data.data[i])!
		}
	}

	return bound
}

pub fn (c ORMConnection) update(table string, data orm.QueryData, where orm.QueryData) ! {
	stmt, _ := orm.orm_stmt_gen(.default, table, '', .update, true, ':p', 0, data, where)
	mut catalog := unsafe { c.c.catalog() }
	table_definition := catalog.schema_table('PUBLIC', orm_table_name(table))!
	mut bound := extract_bound_params(table_definition, 0, data)!
	for k, v in extract_bound_params(table_definition, bound.len, where)! {
		bound[k] = v
	}

	mut prepared := unsafe { c.c.prepare(stmt)! }
	prepared.query(bound)!
}

pub fn (c ORMConnection) delete(table string, where orm.QueryData) ! {
	stmt, _ := orm.orm_stmt_gen(.default, table, '', .delete, true, ':p', 0, orm.QueryData{},
		where)
	mut catalog := unsafe { c.c.catalog() }
	table_definition := catalog.schema_table('PUBLIC', orm_table_name(table))!
	bound := extract_bound_params(table_definition, 0, where)!

	mut prepared := unsafe { c.c.prepare(stmt)! }
	prepared.query(bound)!
}

fn serial_name(table string) string {
	return '${table}_SERIAL'
}

fn (c ORMConnection) execute(stmt string) ! {
	unsafe {
		c.c.query(stmt) or { return error('${err}: ${stmt}') }
	}
}

pub fn (c ORMConnection) create(table string, fields []orm.TableField) ! {
	mut sql_fields := []string{}
	mut primary_key := ''

	for field in fields {
		mut typ := orm_type_to_sql(field.name, field.typ, field.nullable)!

		// The double quotes and uppercase are required to make sure that reserved
		// words are possible.
		mut column_name := "\"${field.name.to_upper()}\""

		for attr in field.attrs {
			match attr.name {
				'sql' {
					// "sql" is used to overload a bunch of different things.
					if attr.arg == 'serial' {
						c.execute('CREATE SEQUENCE "${serial_name(table)}"')!
						primary_key = column_name
					} else if orm.type_idx[attr.arg] != 0 {
						typ = orm_type_to_sql(field.name, orm.type_idx[attr.arg], field.nullable)!
					} else {
						// Unlike above, we do not convert this to uppercase because we do
						// not have the same V language naming limitations in the attribute.
						// This means that in almost all cases you want the custom name to
						// be in UPPERCASE if you want to use mixed cases in queries.
						column_name = "\"${attr.arg}\""
					}
				}
				'sql_type' {
					typ = attr.arg + if field.nullable { '' } else { ' NOT NULL' }
				}
				'primary' {
					primary_key = column_name
				}
				'unique' {
					// Unique is not supported yet. It's better to throw an error so the
					// data stays consistent.
					return error('for ${field.name}: UNIQUE is not supported')
				}
				'default' {
					return error('for ${field.name}: DEFAULT is not supported')
				}
				else {}
			}
		}

		sql_fields << '${column_name} ${typ}'
	}

	if primary_key != '' {
		sql_fields << 'PRIMARY KEY (${primary_key})'
	}

	table_name := orm_table_name(table)

	create_table_sql := 'CREATE TABLE ${table_name} (${sql_fields.join(', ')})'
	c.execute(create_table_sql)!
}

fn orm_table_name(table string) string {
	// It's not possible to know if the table name has been generated from the
	// struct name or extracted from @[table]. This creates a problem because we
	// need to uppercase all generated names so they are safe to double-quote.
	// However, this means that @[table] can never explicitly specify a case
	// sensitive table name. The way around this is to require the table name to
	// already be quoted if that was in the intention from @[table].
	if table[0] == `"` {
		return table
	}

	return requote_identifier(table.to_upper())
}

fn orm_type_to_sql(field_name string, typ int, nullable bool) !string {
	mut base_type := ''

	match typ {
		orm.serial {
			// This comes from @[sql: serial] which is supported, but it shouldn't
			// come through this function as it's handled separately. Although if it
			// does and we do need a type INTEGER should be a sensible default.
			//
			// NOT NULL is implied because this has to be part of the PRIMARY KEY.
			return 'INTEGER NOT NULL'
		}
		orm.enum_ {
			return error('for ${field_name}: ENUM is not supported')
		}
		orm.time_ {
			// Let's choose the highest precision time possible (microseconds).
			base_type = 'TIMESTAMP(6) WITH TIME ZONE'
		}
		orm.type_idx['i8'], orm.type_idx['u8'], orm.type_idx['i16'] {
			base_type = 'SMALLINT'
		}
		orm.type_idx['u16'], orm.type_idx['int'] {
			base_type = 'INTEGER'
		}
		orm.type_idx['i64'], orm.type_idx['u32'] {
			base_type = 'BIGINT'
		}
		orm.type_idx['u64'] {
			// u64 will not fit into a BIGINT so we have to use a larger exact type.
			// It's worth noting that the database will allow a greater range than
			// u64 (including negatives) but unless you're constructing SQL manually
			// the u64 type will prevent you from doing this.
			base_type = 'NUMERIC(20)'
		}
		orm.type_idx['f32'] {
			base_type = 'REAL'
		}
		orm.type_idx['f64'] {
			base_type = 'DOUBLE PRECISION'
		}
		orm.type_idx['bool'] {
			base_type = 'BOOLEAN'
		}
		orm.type_idx['string'] {
			base_type = 'VARCHAR(${orm.string_max_len})'
		}
		else {
			// V's Type is an alias for int so we must include an else clause. There
			// are also types that are not included in this switch that do not
			// apply, or otherwise have no corresponding SQL type.
			return error('unsupported type for ${field_name}: ${typ}')
		}
	}

	if !nullable {
		return base_type + ' NOT NULL'
	}

	return base_type
}

pub fn (c ORMConnection) drop(table string) ! {
	c.execute('DROP TABLE ${orm_table_name(table)}')!
}

pub fn (c ORMConnection) last_id() int {
	// TODO(elliotchance): This is not implemented yet.
	//
	// There is no SQL statement for extracting the current SEQUENCE value so we
	// have to refactor insert() to call NEXT VALUE before the execution.
	return 0
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
