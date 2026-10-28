module main

// ISO/IEC 9075-3:2003(E), 6.32, GetDescRec
//
// Get commonly-used fields from a CLI descriptor area.

@[export: 'SQLGetDescRec']
fn sql_get_desc_rec(descriptor_handle SQLInteger, record_number i16, name &char, buffer_length i16, name_length &i16, type_ &i16, sub_type &i16, length &SQLInteger, precision &i16, scale &i16, nullable &i16) i16 {
	mut desc := descs[i64(descriptor_handle)] or { return sql_invalid_handle }
	desc.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.ii.
	desc.invoke() or { return desc.diag.error(err) }

	// See 5.11, "Deferred parameter check".
	check_desc_deferred(i64(descriptor_handle)) or { return desc.diag.error(err) }

	return get_desc_rec(mut desc, record_number, name, buffer_length, name_length, type_,
		sub_type, length, precision, scale, nullable) or { desc.diag.error(err) }
}

fn get_desc_rec(mut desc Desc, rn i16, name &char, buffer_length i16, name_length &i16, type_ &i16, sub_type &i16, length &SQLInteger, precision &i16, scale &i16, nullable &i16) !i16 {
	// - 4. If RN is less than 1 (one), then an exception condition is raised:
	// dynamic SQL error — invalid descriptor index. If RN is greater than N,
	// then a completion condition is raised: no data.
	if rn < 1 {
		return cli_error('07009', 'invalid descriptor index')
	}
	if rn > desc.count() {
		return desc.diag.no_data()
	}

	// - 5. If D is an implementation row descriptor and there is no prepared or
	// executed statement, then an exception condition is raised: CLI-specific
	// condition — associated statement is not prepared.
	if desc.typ == .ird && !desc.has_prepared_or_executed() {
		return cli_error('HY007', 'associated statement is not prepared')
	}

	// - 8. Each output that isn't a null pointer is set from the item
	// descriptor area. An undefined field is 0 (zero).
	unsafe {
		if type_ != nil {
			*type_ = i16(desc.record_int(rn, sql_desc_type))
		}
		if sub_type != nil {
			*sub_type = i16(desc.record_int(rn, sql_desc_datetime_interval_code))
		}
		if length != nil {
			*length = SQLInteger(desc.record_int(rn, sql_desc_octet_length))
		}
		if precision != nil {
			*precision = i16(desc.record_int(rn, sql_desc_precision))
		}
		if scale != nil {
			*scale = i16(desc.record_int(rn, sql_desc_scale))
		}
		if nullable != nil {
			*nullable = i16(desc.record_int(rn, sql_desc_nullable))
		}
	}

	// - 8.g. The NAME is retrieved by the General Rules of Subclause 5.9,
	// "Character string retrieval", unless null termination is False and BL is
	// zero.
	nts := desc_null_termination(desc)
	if name != unsafe { nil } && (nts || buffer_length != 0) {
		v := desc.records[rn - 1][sql_desc_name] or { DescValue('') }
		retrieve_string(mut desc.diag, nts, name, v as string, buffer_length, name_length,
			2)!
	}

	return desc.diag.result()
}
