// orm.v implements the V language ORM: https://modules.vlang.io/orm.html

module vsql

import orm
import v.ast
import time

/*
interface Connection {
	@select(config SelectConfig, data QueryData, where QueryData) ?[][]Primitive
	insert(table string, data QueryData) ?
	update(table string, data QueryData, where QueryData) ?
	delete(table string, where QueryData) ?
	create(table string, fields []TableField) ?
	drop(table string) ?
	last_id() Primitive
}
*/

pub fn (mut c Connection) @select(config orm.SelectConfig, data orm.QueryData, where orm.QueryData) ?[][]orm.Primitive {
	stmt := orm.orm_select_gen(config, '"', true, ':p', 0, where)

	mut bound := map[string]Value{}
	for i, _ in where.fields {
		bound['p$i'] = new_primitive_value(where.data[i]) ?
	}

	mut prepared := c.prepare(stmt)?
	result := prepared.query(bound)?
	mut all_rows := [][]orm.Primitive{}

	for row in result {
		mut primitive_row := []orm.Primitive{}
		for column in result.columns {
			primitive_row << row.get_primitive(column.name) ?
		}

		all_rows << primitive_row
	}

	return all_rows
}

pub fn (mut c Connection) insert(table string, data orm.QueryData) ? {
	values := data.data.map(fn (p orm.Primitive) string {
		match p {
			orm.InfixType {
				// TODO(elliotchance): Not sure what this is?
				return '$p'
			}
			time.Time {
				// TODO(elliotchance): This doesn't work.
				return '$p'
			}
			bool {
				if p {
					return 'TRUE'
				}
				
				return 'FALSE'
			}
			string {
				// TODO(elliotchance): Does not escape correctly.
				return '\'$p\''
			}
			f32 {
				return '$p'
			}
			f64 {
				return '$p'
			}
			i16 {
				return '$p'
			}
			i64 {
				return '$p'
			}
			i8 {
				return '$p'
			}
			int {
				return '$p'
			}
			u16 {
				return '$p'
			}
			u32 {
				return '$p'
			}
			u64 {
				return '$p'
			}
			u8 {
				return '$p'
			}
		}
	})

	c.query('INSERT INTO "$table" (${data.fields.join(', ')}) VALUES (${values.join(', ')})') ?
}

pub fn (mut c Connection) update(table string, data orm.QueryData, where orm.QueryData) ? {
	panic('update')
}

pub fn (mut c Connection) delete(table string, where orm.QueryData) ? {
	panic('delete')
}

pub fn (mut c Connection) create(table string, fields []orm.TableField) ? {
	mut sql_fields := []string{}
	for field in fields {
		mut typ := ""
		match field.typ {
			ast.i8_type_idx, ast.i16_type_idx, ast.byte_type_idx, ast.u16_type_idx {
				typ = 'SMALLINT'
			}
			ast.int_type_idx {
				typ = 'INTEGER'
			}
			ast.i64_type_idx, ast.u32_type_idx, ast.u64_type_idx {
				typ = 'BIGINT'
			}
			ast.f32_type_idx {
				typ = 'FLOAT'
			}
			ast.f64_type_idx {
				typ = 'DOUBLE PRECISION'
			}
			ast.bool_type_idx {
				typ = 'BOOLEAN'
			}
			ast.string_type_idx {
				typ = 'VARCHAR(255)'
			}
			else {
				return error('unsupported type: $field.typ')
			}
		}

		for attr in field.attrs {
			if attr.name == 'sql' {
				typ = attr.arg
			}
		}

		sql_fields << '$field.name $typ'
	}

	c.query('CREATE TABLE "$table" (${sql_fields.join(', ')})') ?
}

pub fn (mut c Connection) drop(table string) ? {
	panic('drop')
}

pub fn (mut c Connection) last_id() orm.Primitive {
	panic('last_id')
}
