module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.15, DescribeCol
//
// Get column attributes.

@[export: 'SQLDescribeCol']
fn sql_describe_col(statement_handle SQLInteger, column_number i16, column_name &char, buffer_length i16, name_length &i16, data_type &i16, column_size &SQLInteger, decimal_digits &i16, nullable &i16) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.6.
	stmt.check_deferred() or { return stmt.diag.error(err) }

	return describe_col(mut stmt, column_number, column_name, buffer_length, name_length,
		data_type, column_size, decimal_digits, nullable) or { stmt.diag.error(err) }
}

fn describe_col(mut stmt Stmt, column_number i16, column_name &char, buffer_length i16, name_length &i16, data_type &i16, column_size &SQLInteger, decimal_digits &i16, nullable &i16) !i16 {
	// - 2. If there is no prepared or executed statement associated with S, then
	// an exception condition is raised: CLI-specific condition — function
	// sequence error.
	if !stmt.executed && stmt.prepared == none {
		return cli_error('HY010', 'function sequence error')
	}

	// - 3, 4. If N (the TOP_LEVEL_COUNT of the IRD) is zero, then an exception
	// condition is raised: dynamic SQL error — prepared statement not a cursor
	// specification.
	ird := descs[stmt.ird] or { return cli_error('HY010', 'function sequence error') }
	n := ird.header_int(sql_desc_top_level_count)
	if n == 0 {
		return cli_error('07005', 'prepared statement not a cursor specification')
	}

	// - 6. If CN is less than 1 (one) or greater than N, then an exception
	// condition is raised: dynamic SQL error — invalid descriptor index.
	if column_number < 1 || column_number > n {
		return cli_error('07009', 'invalid descriptor index')
	}

	// Only the NameLength may be a null pointer (see 4.4.3, "Null pointers").
	if column_name == unsafe { nil } || data_type == unsafe { nil }
		|| column_size == unsafe { nil } || decimal_digits == unsafe { nil }
		|| nullable == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 9. Information is retrieved from the IRD.
	cn := int(column_number)
	typ := ird.record_int(cn, sql_desc_type)
	unsafe {
		*data_type = i16(concise_type_code(typ, ird.record_int(cn, sql_desc_datetime_interval_code)))
		*column_size = SQLInteger(describe_column_size(ird, cn))
		*decimal_digits = i16(if typ in [i64(sql_numeric), sql_decimal, sql_datetime] {
			ird.record_int(cn, if typ == sql_datetime { sql_desc_precision } else { sql_desc_scale })
		} else {
			0
		})
		*nullable = i16(ird.record_int(cn, sql_desc_nullable))
	}

	// - 9.e. The name is retrieved by the General Rules of Subclause 5.9,
	// "Character string retrieval".
	name := ird.records[cn - 1][sql_desc_name] or { DescValue('') }
	retrieve_string(mut stmt.diag, stmt.null_termination(), column_name, name as string,
		buffer_length, name_length, 2)!

	return stmt.diag.result()
}

// - 9.b. describe_column_size is the maximum length in octets of a character
// string, the maximum length in decimal digits of a number, or the length in
// positions of a datetime. For a BOOLEAN, it's the length of FALSE.
fn describe_column_size(ird &Desc, cn int) i64 {
	return match ird.record_int(cn, sql_desc_type) {
		sql_char, sql_varchar { ird.record_int(cn, sql_desc_octet_length) }
		sql_smallint { 5 }
		sql_integer { 10 }
		sql_bigint { 19 }
		sql_real { 7 }
		sql_double { 15 }
		sql_numeric, sql_decimal { ird.record_int(cn, sql_desc_precision) }
		sql_datetime { ird.record_int(cn, sql_desc_length) }
		else { 5 }
	}
}

fn result_column(cursor vsql.Result, column_number int) !vsql.Column {
	if column_number < 1 || column_number > cursor.columns.len {
		return cli_error('07009', 'invalid descriptor index')
	}

	return cursor.columns[column_number - 1]
}

// datetime_length is the length in positions of a datetime type, including
// the fractional seconds.
fn datetime_length(typ vsql.Type) int {
	fraction := if typ.size > 0 { typ.size + 1 } else { 0 }

	return match typ.typ {
		.is_date { 10 }
		.is_time_without_time_zone { 8 + fraction }
		.is_time_with_time_zone { 14 + fraction }
		.is_timestamp_without_time_zone { 19 + fraction }
		.is_timestamp_with_time_zone { 25 + fraction }
		else { 0 }
	}
}
