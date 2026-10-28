module main

// ISO/IEC 9075-3:2003(E), 6.57, SetDescRec
//
// Set commonly-used fields in a CLI descriptor area.

@[export: 'SQLSetDescRec']
fn sql_set_desc_rec(descriptor_handle SQLInteger, record_number i16, type_ i16, sub_type i16, length SQLInteger, precision i16, scale i16, data voidptr, string_length &SQLInteger, indicator &SQLInteger) i16 {
	mut desc := descs[i64(descriptor_handle)] or { return sql_invalid_handle }
	desc.diag.clear()

	// See 5.11, "Deferred parameter check".
	check_desc_deferred(i64(descriptor_handle)) or { return desc.diag.error(err) }

	return set_desc_rec(mut desc, record_number, type_, sub_type, i64(length), precision,
		scale, data, string_length, indicator) or { desc.diag.error(err) }
}

fn set_desc_rec(mut desc Desc, rn int, type_ i16, sub_type i16, length i64, precision i16, scale i16, data voidptr, string_length &SQLInteger, indicator &SQLInteger) !i16 {
	// - 3. If D is an implementation row descriptor, then an exception
	// condition is raised: CLI-specific condition — cannot modify an
	// implementation row descriptor.
	if desc.typ == .ird {
		// The standard doesn't give this condition a SQLSTATE (it's not in Table 4,
		// "SQLSTATE class and subclass values for SQL/CLI-specific conditions"), so
		// it's HY016, the same as ODBC.
		return cli_error('HY016', 'cannot modify an implementation row descriptor')
	}

	// - 5. If RN is less than 1 (one), then an exception condition is raised:
	// dynamic SQL error — invalid descriptor index.
	if rn < 1 {
		return cli_error('07009', 'invalid descriptor index')
	}

	// - 8. The data type, precision, scale and datetime data type are set. The
	// length is in characters (or positions) for an IPD, otherwise it's in
	// octets.
	mut record := if rn <= desc.count() {
		desc.records[rn - 1].clone()
	} else {
		desc.default_record()
	}
	record[sql_desc_type] = i64(type_)
	record[sql_desc_datetime_interval_code] = i64(sub_type)
	record[sql_desc_precision] = i64(precision)
	record[sql_desc_scale] = i64(scale)
	record[if desc.typ == .ipd { int(sql_desc_length) } else { sql_desc_octet_length }] = length
	if string_length != unsafe { nil } {
		record[sql_desc_octet_length_pointer] = i64(voidptr(string_length))
	}
	record[sql_desc_data_pointer] = i64(data)
	if indicator != unsafe { nil } {
		record[sql_desc_indicator_pointer] = i64(voidptr(indicator))
	}

	// - 9, 10. If Data is not a null pointer and IDA is not consistent, then an
	// exception condition is raised: CLI-specific condition — inconsistent
	// descriptor information (and the descriptor is unchanged).
	if data != unsafe { nil } && !desc.is_consistent(record) {
		return cli_error('HY021', 'inconsistent descriptor information')
	}

	// - 6. If RN is greater than N, then the COUNT field of D is set to RN.
	if rn > desc.count() {
		desc.set_count(rn)
	}
	desc.records[rn - 1] = record

	return sql_success
}
