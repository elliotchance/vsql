module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.30, GetData
//
// Retrieve a column value.
//
// A character value can be retrieved in pieces by calling GetData again for the
// same column. Columns can be retrieved in any order, and once a value has been
// retrieved completely, retrieving it again starts from the beginning.

@[export: 'SQLGetData']
fn sql_get_data(statement_handle SQLInteger, column_number i16, target_type i16, target_value voidptr, buffer_length SQLInteger, str_len_or_ind &SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	rc := get_data(mut stmt, column_number, target_type, target_value, i64(buffer_length),
		str_len_or_ind) or { stmt.diag.error(err) }

	// The conditions apply to the column (see 4.3, "Diagnostics areas in
	// SQL/CLI").
	if cursor := stmt.cursor {
		if column_number >= 1 && column_number <= cursor.columns.len {
			for mut record in stmt.diag.records {
				record.column_number = column_number
			}
		}
	}

	return rc
}

fn get_data(mut stmt Stmt, column_number i16, target_type i16, target_value voidptr, buffer_length i64, str_len_or_ind &SQLInteger) !i16 {
	// - 2.a. If there is no fetched rowset associated with S, then an exception
	// condition is raised: CLI-specific condition — function sequence error.
	cursor := stmt.cursor or { return cli_error('HY010', 'function sequence error') }
	if !stmt.fetched {
		return cli_error('HY010', 'function sequence error')
	}

	// - 2.b. If the fetched rowset associated with S is empty, then a completion
	// condition is raised: no data.
	row := stmt.row or { return stmt.diag.no_data() }

	// - 10. If CN is less than 1 (one) or greater than D, then an exception
	// condition is raised: dynamic SQL error — invalid descriptor index.
	column := result_column(cursor, column_number)!
	cn := int(column_number)

	if target_value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 18. If T isn't DEFAULT or ARD TYPE, it must be an application data type
	// with a C data type, otherwise an exception condition is raised:
	// CLI-specific condition — invalid data type in application descriptor.
	//
	// There are no CLI descriptor areas, so the ARD TYPE is always DEFAULT. A
	// DEFAULT (- 21) is the type of the column, which may not have a C data
	// type.
	is_default := target_type == sql_default || target_type == sql_ard_type
	tt := if is_default { data_type_code(column.typ) } else { target_type }
	typ := c_type(tt) or {
		if is_default {
			return cli_error('07006', 'restricted data type attribute violation')
		}
		return cli_error('HY003', 'invalid data type in application descriptor')
	}

	// - 15.b, 25.a. Continue retrieving a character value in pieces.
	if stmt.fetched_column < 0 {
		afcn := -stmt.fetched_column
		stmt.fetched_column = afcn
		if cn == afcn {
			if typ != .is_varchar {
				return cli_error('07009', 'invalid descriptor index')
			}

			return retrieve_piece(mut stmt, cn, target_value, buffer_length, str_len_or_ind)
		}
	}

	// - 26. CN becomes the fetched column number associated with the fetched
	// row associated with S.
	value := row.get_column(column)!
	stmt.fetched_column = cn

	// - 27. If TV is the null value, then StrLen_or_Ind is set to SQL NULL DATA.
	if value.is_null {
		if str_len_or_ind == unsafe { nil } {
			return cli_error('22002', 'null value, no indicator parameter')
		}
		unsafe {
			*str_len_or_ind = sql_null_data
		}
		return sql_success
	}

	// - 30.b.ii. A character value is retrieved by the General Rules of 5.9,
	// "Character string retrieval".
	if typ == .is_varchar {
		stmt.fetched_value = value.str()
		stmt.fetched_length = 0
		return retrieve_piece(mut stmt, cn, target_value, buffer_length, str_len_or_ind)
	}

	// - 25.b.vi.2. The value is the result of CAST ( SV AS TDT ).
	if column.typ.typ in [.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
		.is_timestamp_without_time_zone, .is_timestamp_with_time_zone, .is_boolean] {
		return cli_error('07006', 'restricted data type attribute violation')
	}
	mut conn := dbcs[stmt.dbc] or { return cli_error('08003', 'connection does not exist') }.conn or {
		return cli_error('08003', 'connection does not exist')
	}
	tv := conn.store_assignment(value, vsql.Type{ typ: typ })!

	// - 30.a. StrLen_or_Ind is set to 0 (zero).
	if str_len_or_ind != unsafe { nil } {
		unsafe {
			*str_len_or_ind = 0
		}
	}

	unsafe {
		match typ {
			.is_smallint { *&i16(target_value) = i16(tv.int_value()) }
			.is_integer { *&SQLInteger(target_value) = SQLInteger(tv.int_value()) }
			.is_bigint { *&i64(target_value) = tv.int_value() }
			.is_real { *&f32(target_value) = f32(tv.f64_value()) }
			else { *&f64(target_value) = tv.f64_value() }
		}
	}

	return sql_success
}

// retrieve_piece retrieves the rest of the fetched value from the fetched
// length.
fn retrieve_piece(mut stmt Stmt, cn int, target_value voidptr, buffer_length i64, str_len_or_ind &SQLInteger) !i16 {
	retrieve_string(mut stmt.diag, target_value, stmt.fetched_value[stmt.fetched_length..],
		buffer_length, str_len_or_ind, 4)!

	// - 30.b.ii.4, 5. If FL is less than DL, then –CN becomes the fetched column
	// number.
	stmt.fetched_length += int(buffer_length - 1)
	stmt.fetched_column = if stmt.fetched_length < stmt.fetched_value.len { -cn } else { cn }

	return stmt.diag.result()
}
