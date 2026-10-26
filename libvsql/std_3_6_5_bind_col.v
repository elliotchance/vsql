module main

// ISO/IEC 9075-3:2003(E), 6.5, BindCol
//
// Describe a target specification or array of target specifications.
//
// BindCol sets the item descriptor area of the ARD for a column, so that Fetch
// and FetchScroll assign the value of the column to TargetValue (and
// StrLen_or_Ind). A null TargetValue unbinds the column.

@[export: 'SQLBindCol']
fn sql_bind_col(statement_handle SQLInteger, column_number i16, target_type i16, target_value voidptr, buffer_length SQLInteger, str_len_or_ind &SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return bind_col(mut stmt, column_number, target_type, target_value, i64(buffer_length),
		str_len_or_ind) or { stmt.diag.error(err) }
}

fn bind_col(mut stmt Stmt, column_number i16, target_type i16, target_value voidptr, buffer_length i64, str_len_or_ind &SQLInteger) !i16 {
	mut ard := descs[stmt.ard] or { return cli_error('HY010', 'function sequence error') }

	// - 5. If CN is less than 1 (one), then an exception condition is raised:
	// dynamic SQL error — invalid descriptor index.
	cn := int(column_number)
	if cn < 1 {
		return cli_error('07009', 'invalid descriptor index')
	}

	// - 9. TT must be DEFAULT or an application data type that has a C data
	// type, otherwise an exception condition is raised: CLI-specific condition
	// — invalid data type in application descriptor.
	typ := c_type(target_type)
	if target_type != sql_default && typ == none {
		return cli_error('HY003', 'invalid data type in application descriptor')
	}

	// - 11. If BL is not greater than zero, then an exception condition is
	// raised: CLI-specific condition — invalid string length or buffer length.
	if buffer_length <= 0 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	// - 6. If CN is greater than N, then the ARD has a record for each column up
	// to CN.
	if cn > ard.count() {
		ard.set_count(cn)
	}

	// - 14 to 19. The TYPE, OCTET_LENGTH (BL), LENGTH (the maximum length of a
	// string, in octets), DATA_POINTER, INDICATOR_POINTER and
	// OCTET_LENGTH_POINTER are set. The indicator and the length share
	// StrLen_or_Ind.
	mut record := ard.records[cn - 1].clone()
	record[sql_desc_type] = i64(target_type)
	record[sql_desc_octet_length] = buffer_length
	record[sql_desc_length] = if target_type == sql_char { buffer_length } else { i64(0) }
	record[sql_desc_data_pointer] = i64(target_value)
	record[sql_desc_indicator_pointer] = i64(voidptr(str_len_or_ind))
	record[sql_desc_octet_length_pointer] = i64(voidptr(str_len_or_ind))
	ard.records[cn - 1] = record

	return sql_success
}
