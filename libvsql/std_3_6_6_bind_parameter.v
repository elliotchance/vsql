module main

// ISO/IEC 9075-3:2003(E), 6.6, BindParameter
//
// Describe a dynamic parameter specification and its value.
//
// BindParameter sets the item descriptor area of the IPD for a dynamic
// parameter ("?", numbered from 1) to its SQL data type (ParameterType,
// ColumnSize and DecimalDigits), and the item descriptor area of the APD to
// its value (ParameterValue, of ValueType). StrLen_or_Ind is the length of a
// string (or SQL_NTS), SQL_NULL_DATA for a NULL, or SQL_DATA_AT_EXEC for a
// value that's given with ParamData and PutData when the statement is
// executed.
//
// ParameterType is checked with the codes for the IPD rather than Table 37
// (General Rules, 12), which is #753. The COUNT of the IPD and APD is set to
// PN, but their TOP_LEVEL_COUNT isn't changed (General Rules, 14.b and 15.b),
// which is #752. Memory isn't limited (General Rules, 14.a and 15.a). There
// are no interval types (General Rules, 18.b and 28). Everything is checked
// before anything is set, so an exception condition doesn't change the
// descriptors (General Rules, 20). The parameter mode is set in the IPD
// (General Rules, 21 says IDA2, the APD, but 5.6 and 5.13 use the
// PARAMETER_MODE of the IPD). The restrictions between the APD and IPD (General
// Rules, 29) are those of 5.6.

@[export: 'SQLBindParameter']
fn sql_bind_parameter(statement_handle SQLInteger, parameter_number i16, input_output_mode i16, value_type i16, parameter_type i16, column_size SQLInteger, decimal_digits i16, parameter_value voidptr, buffer_length SQLInteger, str_len_or_ind &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return bind_parameter(mut stmt, parameter_number, input_output_mode, value_type,
		parameter_type, i64(column_size), decimal_digits, parameter_value, i64(buffer_length),
		str_len_or_ind) or { stmt.diag.error(err) }
}

fn bind_parameter(mut stmt Stmt, parameter_number i16, iom i16, value_type i16, parameter_type i16, column_size i64, decimal_digits i16, parameter_value voidptr, buffer_length i64, str_len_or_ind &SQLInteger) !i16 {
	stmt.invoke(false)!
	mut apd := descs[stmt.apd] or { return cli_error('HY010', 'function sequence error') }
	mut ipd := descs[stmt.ipd] or { return cli_error('HY010', 'function sequence error') }

	// - 5. If PN is less than 1 (one), then an exception condition is raised:
	// dynamic SQL error — invalid descriptor index.
	pn := int(parameter_number)
	if pn < 1 {
		return cli_error('07009', 'invalid descriptor index')
	}

	// - 7. If IOM is not one of the code values in Table 10, then an exception
	// condition is raised: CLI-specific condition — invalid parameter mode.
	if iom !in [sql_param_mode_in, sql_param_mode_inout, sql_param_mode_out] {
		return cli_error('HY105', 'invalid parameter mode')
	}

	// - 10. VT must be DEFAULT or an application data type that has a C data
	// type, otherwise an exception condition is raised: CLI-specific condition
	// — invalid data type in application descriptor.
	if value_type != sql_default && c_type(value_type) == none {
		return cli_error('HY003', 'invalid data type in application descriptor')
	}

	// - 12. PT must be one of the codes in Table 37, "Codes used for concise
	// data types", otherwise an exception condition is raised: CLI-specific
	// condition — invalid data type.
	mut ipd_record := map[int]DescValue{}
	if parameter_type >= sql_type_date && parameter_type <= sql_type_timestamp_with_timezone {
		// - 18.a. A datetime is DATETIME with the DATETIME_INTERVAL_CODE of the
		// concise code. The precision of a DATE is zero.
		dic := parameter_type - 90
		ipd_record[sql_desc_type] = i64(sql_datetime)
		ipd_record[sql_desc_datetime_interval_code] = i64(dic)
		ipd_record[sql_desc_length] = column_size
		ipd_record[sql_desc_precision] = i64(if dic == sql_code_date { 0 } else { decimal_digits })
	} else {
		check_desc_type(ipd, parameter_type)!

		// - 18.c. The length of a string is CS, and the precision and scale of a
		// number are CS and DD.
		ipd_record[sql_desc_type] = i64(parameter_type)
		if parameter_type in [sql_char, sql_varchar] {
			ipd_record[sql_desc_length] = column_size
		} else if parameter_type != sql_boolean {
			ipd_record[sql_desc_precision] = column_size
			ipd_record[sql_desc_scale] = i64(decimal_digits)
		}
	}
	ipd_record[sql_desc_parameter_mode] = i64(iom)

	// - 26. If IOM is PARAM MODE OUT or PARAM MODE INOUT and BL is not greater
	// than zero, then an exception condition is raised: CLI-specific condition
	// — invalid string length or buffer length.
	if iom != sql_param_mode_in && buffer_length <= 0 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	// - 14, 15. The IPD and APD have an item descriptor area for each parameter
	// up to PN.
	if pn > ipd.count() {
		ipd.set_count(pn)
	}
	if pn > apd.count() {
		apd.set_count(pn)
	}
	for field, value in ipd_record {
		ipd.records[pn - 1][field] = value
	}

	// - 21 to 27. The TYPE, DATA_POINTER, INDICATOR_POINTER,
	// OCTET_LENGTH_POINTER and OCTET_LENGTH of the APD.
	mut record := apd.records[pn - 1].clone()
	record[sql_desc_type] = i64(value_type)
	record[sql_desc_data_pointer] = i64(parameter_value)
	record[sql_desc_indicator_pointer] = i64(voidptr(str_len_or_ind))
	record[sql_desc_octet_length_pointer] = i64(voidptr(str_len_or_ind))
	record[sql_desc_octet_length] = buffer_length
	apd.records[pn - 1] = record

	return sql_success
}
