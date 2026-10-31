module main

// ISO/IEC 9075-3:2003(E), 6.30, GetData
//
// Retrieve a column value.
//
// A character value can be retrieved in pieces by calling GetData again for the
// same column. Columns can be retrieved in any order, and once a value has been
// retrieved completely, retrieving it again starts from the beginning (General
// Rules 13.b, 15.a and 15.b.ii.1, which are implementation-defined).
//
// COUNT can't be negative (General Rules, 8), and there are no ROW, ARRAY or
// MULTISET types, locators, user-defined types or large objects (General Rules
// 12, 25.b.iii, 25.b.v, 25.b.vi.1, 25.b.vi.3 and 30.b.ii.2). There's no maximum
// length for CHARACTER VARYING (General Rules, 24.a.ii), and a zero-length
// character string isn't an exception condition (General Rules, 30.b.ii.1.A).

@[export: 'SQLGetData']
fn sql_get_data(statement_handle SQLInteger, column_number i16, target_type i16, target_value voidptr, buffer_length SQLInteger, str_len_or_ind &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(false) or { return stmt.diag.error(err) }

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
	if stmt.rowset_len == 0 {
		return no_data()
	}

	// - 4, 5, 6. The row is the P-th (the CURRENT OF POSITION) row of the
	// rowset. A rowset with more than one row can only be read from a
	// scrollable cursor, otherwise an exception condition is raised:
	// CLI-specific condition — invalid cursor position.
	mut ard := descs[stmt.ard] or { return cli_error('HY010', 'function sequence error') }
	array_size := ard.header_int(sql_desc_array_size)
	p := stmt.current_of_position
	if p > array_size || p > stmt.rowset_len
		|| (stmt.cursor_scrollable == sql_nonscrollable && array_size > 1) {
		return cli_error('HY109', 'invalid cursor position')
	}
	row := stmt.rows[stmt.rowset_start + int(p) - 1]

	// - 10. If CN is less than 1 (one) or greater than D, then an exception
	// condition is raised: dynamic SQL error — invalid descriptor index.
	column := result_column(cursor, column_number)!
	cn := int(column_number)

	if target_value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 12, 13. The item descriptor area of the ARD for the column can't be
	// bound (have a DATA_POINTER). Any other column can be retrieved, including
	// the columns before the highest bound column.
	if ard.record_int(cn, sql_desc_data_pointer) != 0 {
		return cli_error('07009', 'invalid descriptor index')
	}

	// - 18. If T isn't DEFAULT or ARD TYPE, it must be an application data type
	// with a C data type, otherwise an exception condition is raised:
	// CLI-specific condition — invalid data type in application descriptor.
	if target_type != sql_default && target_type != sql_ard_type && c_type(target_type) == none {
		return cli_error('HY003', 'invalid data type in application descriptor')
	}

	// - 19. If T does not indicate ARD TYPE, then the TYPE of the item
	// descriptor area of the ARD is set to T.
	mut tt := i64(target_type)
	if cn <= ard.count() {
		if target_type == sql_ard_type {
			tt = ard.record_int(cn, sql_desc_type)
		} else {
			ard.records[cn - 1][sql_desc_type] = i64(target_type)
		}
	} else if target_type == sql_ard_type {
		tt = sql_default
	}

	// - 21. If the TYPE is DEFAULT, then the type of the column (from the IRD)
	// is used instead.
	if tt == sql_default {
		ird := descs[stmt.ird] or { return cli_error('HY010', 'function sequence error') }
		tt = ird.record_int(cn, sql_desc_type)
	}

	// - 22. If the type doesn't have a C data type, then an exception condition
	// is raised: dynamic SQL error — using clause does not match target
	// specifications.
	typ := c_type(i16(tt)) or {
		return cli_error('07002', 'using clause does not match target specifications')
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
	tv := cast_value(stmt, value, column, typ)!

	// - 30.a. StrLen_or_Ind is set to 0 (zero).
	if str_len_or_ind != unsafe { nil } {
		unsafe {
			*str_len_or_ind = 0
		}
	}

	assign_number(tv, typ, target_value)

	return sql_success
}

// retrieve_piece retrieves the rest of the fetched value from the fetched
// length.
fn retrieve_piece(mut stmt Stmt, cn int, target_value voidptr, buffer_length i64, str_len_or_ind &SQLInteger) !i16 {
	retrieve_string(mut stmt.diag, stmt.null_termination(), target_value, stmt.fetched_value[stmt.fetched_length..],
		buffer_length, str_len_or_ind, 4)!

	// - 30.b.ii.4, 5. If FL is less than DL, then –CN becomes the fetched column
	// number.
	stmt.fetched_length += int(if stmt.null_termination() {
		buffer_length - 1
	} else {
		buffer_length
	})
	stmt.fetched_column = if stmt.fetched_length < stmt.fetched_value.len { -cn } else { cn }

	return stmt.diag.result()
}
