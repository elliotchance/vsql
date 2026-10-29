// queries.v contains the SELECT, INSERT, UPDATE and DELETE statements of the
// ORM.

module vorm

import orm
import vsql

// select is used internally by V's ORM for processing `SELECT` queries.
pub fn (mut db DB) select(config orm.SelectConfig, data orm.QueryData, where orm.QueryData) ![][]orm.Primitive {
	query := orm.orm_select_gen_with_dialect(.vsql, config, quote, true, placeholder, 1,
		where)
	sql_stmt, params := dynamic_parameters(query, db.params(config.table.name, [where, data])!)
	mut stmt := db.conn.prepare(sql_stmt)!
	mut result := stmt.query(params)!

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

			params['?${params.len + 1}'] = db.to_column_value(value, column_types[field])!
			values << '?'
		}

		mut stmt := db.conn.prepare('INSERT INTO ${quote}${table.name}${quote} (${columns.join(', ')}) VALUES (${values.join(', ')})')!
		stmt.query(params)!
	}
}

// update is used internally by V's ORM for processing `UPDATE` queries.
pub fn (mut db DB) update(table orm.Table, data orm.QueryData, where orm.QueryData) ! {
	query, _ := orm.orm_stmt_gen(.vsql, table, quote, .update, true, placeholder, 1, data,
		where)
	sql_stmt, params := dynamic_parameters(query, db.params(table.name, [data, where])!)
	mut stmt := db.conn.prepare(sql_stmt)!
	stmt.query(params)!
}

// delete is used internally by V's ORM for processing `DELETE` queries.
pub fn (mut db DB) delete(table orm.Table, where orm.QueryData) ! {
	query, _ := orm.orm_stmt_gen(.vsql, table, quote, .delete, true, placeholder, 1,
		orm.QueryData{}, where)
	sql_stmt, params := dynamic_parameters(query, db.params(table.name, [where])!)
	mut stmt := db.conn.prepare(sql_stmt)!
	stmt.query(params)!
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
			// Updating rows from an array sets each field with a CASE that has a
			// WHEN (the key) and a THEN (the field) for each row.
			typ := if d.batch_rows > 0 {
				if i % 2 == 0 {
					?vsql.Type(column_types[d.batch_key])
				} else {
					column_types[fields[i / (2 * d.batch_rows)]]
				}
			} else if i < fields.len {
				column_types[fields[i]]
			} else {
				none
			}

			// The array of an "in" or "!in" has a placeholder for each value.
			if p is []orm.Primitive {
				for element in p {
					values['p${values.len + 1}'] = db.to_column_value(element, typ)!
				}
				continue
			}

			values['p${values.len + 1}'] = db.to_column_value(p, typ)!
		}
	}

	return values
}

// dynamic_parameters replaces each placeholder (:p1, :p2, etc) in a statement
// from the ORM with a dynamic parameter ("?"), and returns the values named by
// their position ("?1", "?2", etc). The row count of an OFFSET or FETCH FIRST
// can't be a dynamic parameter, so its value is written in the statement
// instead.
fn dynamic_parameters(query string, values map[string]vsql.Value) (string, map[string]vsql.Value) {
	mut sql_stmt := ''
	mut params := map[string]vsql.Value{}
	mut in_name := false
	mut i := 0
	for i < query.len {
		// A delimited identifier can contain anything that looks like a
		// placeholder.
		if query[i] == `"` {
			in_name = !in_name
		}

		if in_name || !query[i..].starts_with(placeholder) {
			sql_stmt += query[i].ascii_str()
			i++
			continue
		}

		mut end := i + placeholder.len
		for end < query.len && query[end].is_digit() {
			end++
		}

		value := values[query[i + 1..end]]
		if sql_stmt.ends_with('OFFSET ') || sql_stmt.ends_with('FETCH FIRST ') {
			sql_stmt += value.str()
		} else {
			sql_stmt += '?'
			params['?${params.len + 1}'] = value
		}
		i = end
	}

	return sql_stmt, params
}
