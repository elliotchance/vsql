module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.15, DescribeCol
//
// Get column attributes.

@[export: 'SQLDescribeCol']
fn sql_describe_col(statement_handle SQLInteger, column_number i16, column_name &char, buffer_length i16, name_length &i16, data_type &i16, column_size &SQLInteger, decimal_digits &i16, nullable &i16) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return describe_col(mut stmt, column_number, column_name, buffer_length, name_length,
		data_type, column_size, decimal_digits, nullable) or { stmt.diag.error(err) }
}

fn describe_col(mut stmt Stmt, column_number i16, column_name &char, buffer_length i16, name_length &i16, data_type &i16, column_size &SQLInteger, decimal_digits &i16, nullable &i16) !i16 {
	// - 2. If there is no prepared or executed statement associated with S, then
	// an exception condition is raised: CLI-specific condition — function
	// sequence error.
	if !stmt.executed {
		return cli_error('HY010', 'function sequence error')
	}

	// - 4. If N is zero, then an exception condition is raised: dynamic SQL
	// error — prepared statement not a cursor specification.
	cursor := stmt.cursor or {
		return cli_error('07005', 'prepared statement not a cursor specification')
	}

	// - 6. If CN is less than 1 (one) or greater than N, then an exception
	// condition is raised: dynamic SQL error — invalid descriptor index.
	column := result_column(cursor, column_number)!

	// Only the NameLength may be a null pointer (see 4.4.3, "Null pointers").
	if column_name == unsafe { nil } || data_type == unsafe { nil }
		|| column_size == unsafe { nil } || decimal_digits == unsafe { nil }
		|| nullable == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	unsafe {
		*data_type = data_type_code(column.typ)
		*column_size = SQLInteger(column_size_of(column.typ))
		*decimal_digits = decimal_digits_of(column.typ)
		*nullable = if column.not_null { sql_no_nulls } else { sql_nullable }
	}

	// - 9.e. The name is retrieved by the General Rules of Subclause 5.9,
	// "Character string retrieval".
	retrieve_string(mut stmt.diag, column_name, column.name.sub_entity_name, buffer_length,
		name_length, 2)!

	return stmt.diag.result()
}

fn result_column(cursor vsql.Result, column_number int) !vsql.Column {
	if column_number < 1 || column_number > cursor.columns.len {
		return cli_error('07009', 'invalid descriptor index')
	}

	return cursor.columns[column_number - 1]
}

// column_size_of is the maximum length of a character string in octets, the
// precision of a number in decimal digits, or the length in positions of a
// datetime.
fn column_size_of(typ vsql.Type) int {
	fraction := if typ.size > 0 { typ.size + 1 } else { 0 }

	return match typ.typ {
		.is_character, .is_varchar, .is_decimal, .is_numeric { typ.size }
		.is_smallint { 5 }
		.is_integer { 10 }
		.is_bigint { 19 }
		.is_real { 7 }
		.is_double_precision { 15 }
		.is_boolean { 5 }
		.is_date { 10 }
		.is_time_without_time_zone { 8 + fraction }
		.is_time_with_time_zone { 14 + fraction }
		.is_timestamp_without_time_zone { 19 + fraction }
		.is_timestamp_with_time_zone { 25 + fraction }
	}
}

// decimal_digits_of is the scale of an exact number, or the fractional seconds
// precision of a datetime.
fn decimal_digits_of(typ vsql.Type) i16 {
	return match typ.typ {
		.is_decimal, .is_numeric { typ.scale }
		.is_time_without_time_zone, .is_time_with_time_zone, .is_timestamp_without_time_zone,
		.is_timestamp_with_time_zone {
			i16(typ.size)
		}
		else {
			0
		}
	}
}
