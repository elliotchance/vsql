module main

// ISO/IEC 9075-3:2003(E), 6.9, ColAttribute
//
// Get a column attribute.

@[export: 'SQLColAttribute']
fn sql_col_attribute(statement_handle SQLInteger, column_number i16, field_identifier i16, character_attribute &char, buffer_length i16, string_length &i16, numeric_attribute &SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return col_attribute(mut stmt, column_number, field_identifier, character_attribute,
		buffer_length, string_length, numeric_attribute) or { stmt.diag.error(err) }
}

fn col_attribute(mut stmt Stmt, column_number i16, fi i16, character_attribute &char, buffer_length i16, string_length &i16, numeric_attribute &SQLInteger) !i16 {
	// - 2. If there is no prepared or executed statement associated with S, then
	// an exception condition is raised: CLI-specific condition — function
	// sequence error.
	if !stmt.executed {
		return cli_error('HY010', 'function sequence error')
	}

	// - 3. Let N be the TOP_LEVEL_COUNT of the IRD.
	ird := descs[stmt.ird] or { return cli_error('HY010', 'function sequence error') }
	n := ird.header_int(sql_desc_top_level_count)

	// - 5. If FI is not one of the code values in Table 20, then an exception
	// condition is raised: CLI-specific condition — invalid descriptor field
	// identifier.
	info := desc_fields[fi] or { return cli_error('HY091', 'invalid descriptor field identifier') }

	// - 9, 10. The column number must be a column of the IRD. A header field
	// also needs a column number.
	if !info.header && n == 0 {
		return cli_error('07005', 'prepared statement not a cursor specification')
	}
	if column_number < 1 {
		return cli_error('07009', 'invalid descriptor index')
	}
	if column_number > n {
		return no_data()
	}
	rn := if info.header { 0 } else { int(column_number) }

	// - 12. The information is retrieved from the IRD by implicitly executing
	// GetDescField. A TYPE is the concise code (with a code for each datetime
	// type).
	mut v := desc_field_value(ird, rn, fi)!
	if fi == sql_desc_type {
		v = DescValue(concise_type_code(ird.record_int(rn, sql_desc_type), ird.record_int(rn,
			sql_desc_datetime_interval_code)))
	}
	if info.kind == .string {
		write_desc_field(mut stmt.diag, stmt.null_termination(), fi, v, character_attribute,
			buffer_length, string_length, 2, false)!
	} else {
		write_desc_field(mut stmt.diag, stmt.null_termination(), fi, v, numeric_attribute,
			0, unsafe { nil }, 0, true)!
	}

	return stmt.diag.result()
}
