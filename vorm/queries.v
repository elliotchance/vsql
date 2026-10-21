// queries.v contains the SELECT, INSERT, UPDATE and DELETE statements of the
// ORM.

module vorm

import orm
import vsql

// select is used internally by V's ORM for processing `SELECT` queries.
pub fn (mut db DB) select(config orm.SelectConfig, data orm.QueryData, where orm.QueryData) ![][]orm.Primitive {
	query := orm.orm_select_gen_with_dialect(.vsql, config, quote, true, placeholder, 1,
		where)
	mut stmt := db.conn.prepare(query)!
	mut result := stmt.query(db.params(config.table.name, [where, data])!)!

	mut rows := [][]orm.Primitive{}
	for row in result {
		mut primitives := []orm.Primitive{}
		for i, column in result.columns {
			typ := if i < config.types.len { config.types[i] } else { orm.type_string }
			primitives << to_primitive(row.get(column.name.sub_entity_name)!, typ)!
		}
		rows << primitives
	}

	return rows
}

// insert is used internally by V's ORM for processing `INSERT` queries.
//
// Each row is inserted with its own statement. A serial field that has no value
// is given the next value of its sequence (see create).
pub fn (mut db DB) insert(table orm.Table, data orm.QueryData) ! {
	row_count := if data.batch_rows > 0 { data.batch_rows } else { 1 }
	for row in 0 .. row_count {
		mut columns := []string{}
		mut values := []string{}
		mut params := map[string]vsql.Value{}
		column_types := db.column_types(table.name)!
		for i, field in data.fields {
			index := row * data.fields.len + i
			value := if index < data.data.len { data.data[index] } else { orm.null_primitive }
			columns << '${quote}${field}${quote}'

			if i in data.auto_fields && is_auto_value(value) {
				db.last_serial = int(db.next_serial(table.name, field)!)
				values << db.last_serial.str()
				continue
			}

			name := 'p${params.len + 1}'
			params[name] = db.to_column_value(value, column_types[field])!
			values << ':${name}'
		}

		mut stmt := db.conn.prepare('INSERT INTO ${quote}${table.name}${quote} (${columns.join(', ')}) VALUES (${values.join(', ')})')!
		stmt.query(params)!
	}
}

// update is used internally by V's ORM for processing `UPDATE` queries.
pub fn (mut db DB) update(table orm.Table, data orm.QueryData, where orm.QueryData) ! {
	query, _ := orm.orm_stmt_gen(.vsql, table, quote, .update, true, placeholder, 1, data,
		where)
	mut stmt := db.conn.prepare(query)!
	stmt.query(db.params(table.name, [data, where])!)!
}

// delete is used internally by V's ORM for processing `DELETE` queries.
pub fn (mut db DB) delete(table orm.Table, where orm.QueryData) ! {
	query, _ := orm.orm_stmt_gen(.vsql, table, quote, .delete, true, placeholder, 1,
		orm.QueryData{}, where)
	mut stmt := db.conn.prepare(query)!
	stmt.query(db.params(table.name, [where])!)!
}

// params turns the values of each QueryData into the placeholders :p1, :p2,
// etc, in the same order that the ORM numbers them.
fn (mut db DB) params(table string, data []orm.QueryData) !map[string]vsql.Value {
	column_types := db.column_types(table)!
	mut values := map[string]vsql.Value{}
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
			values['p${values.len + 1}'] = db.to_column_value(p, typ)!
		}
	}

	return values
}
