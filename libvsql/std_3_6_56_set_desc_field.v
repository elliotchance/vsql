module main

// ISO/IEC 9075-3:2003(E), 6.56, SetDescField
//
// Set a field in a CLI descriptor area.
//
// An INTEGER or SMALLINT field is passed as the Value itself (rather than a
// pointer to it), the same as ODBC. A pointer field is passed as the pointer.

@[export: 'SQLSetDescField']
fn sql_set_desc_field(descriptor_handle SQLInteger, record_number i16, field_identifier i16, value voidptr, buffer_length SQLInteger) i16 {
	mut desc := descs[i64(descriptor_handle)] or { return sql_invalid_handle }
	desc.diag.clear()

	return set_desc_field(mut desc, record_number, field_identifier, value, i64(buffer_length)) or {
		desc.diag.error(err)
	}
}

fn set_desc_field(mut desc Desc, rn int, fi int, value voidptr, buffer_length i64) !i16 {
	// - 4. If FI is not one of the code values in Table 20, then an exception
	// condition is raised: CLI-specific condition — invalid descriptor field
	// identifier.
	info := desc_fields[fi] or { return cli_error('HY091', 'invalid descriptor field identifier') }

	// - 5, 6, 7. The field must be settable for the type of descriptor (Table
	// 21, "Ability to set SQL/CLI descriptor fields").
	if info.settable[desc.field_index()] == `n` {
		return cli_error('HY091', 'invalid descriptor field identifier')
	}

	// - 10. If TYPE is 'ITEM' and RN is less than 1 (one), then an exception
	// condition is raised: dynamic SQL error — invalid descriptor index.
	if !info.header && rn < 1 {
		return cli_error('07009', 'invalid descriptor index')
	}

	// - 12. The value is checked before anything is set, so that the descriptor
	// is unchanged by an exception condition.
	v := if info.kind == .string {
		DescValue(desc_string_value(mut desc.diag, fi, value, buffer_length)!)
	} else {
		DescValue(i64(value))
	}
	n := if v is i64 { v } else { 0 }
	match fi {
		sql_desc_count {
			if n < 0 || n > 32767 {
				return cli_error('07008', 'invalid descriptor count')
			}
		}
		sql_desc_array_size {
			if n < 1 {
				return cli_error('HY024', 'invalid attribute value')
			}
		}
		sql_desc_level {
			// - 14. There are no ROW, ARRAY or MULTISET types, so every item
			// descriptor area has a LEVEL of 0 (zero): dynamic SQL error —
			// invalid LEVEL value.
			if n != 0 {
				return cli_error('0700E', 'invalid LEVEL value')
			}
		}
		sql_desc_type {
			// - 19.b.x. Otherwise, an exception condition is raised: CLI-specific
			// condition — invalid data type.
			check_desc_type(desc, n)!
		}
		sql_desc_data_pointer {
			// - 17. If FI indicates DATA_POINTER, and Value is not a null
			// pointer, and IDA is not consistent, then an exception condition is
			// raised: CLI-specific condition — inconsistent descriptor
			// information.
			if n != 0 {
				record := if rn <= desc.count() {
					desc.records[rn - 1]
				} else {
					desc.default_record()
				}
				if !desc.is_consistent(record) {
					return cli_error('HY021', 'inconsistent descriptor information')
				}
			}
		}
		else {}
	}

	// - 13. Information is set in D.
	if info.header {
		if fi == sql_desc_count {
			desc.set_count(int(n))
		} else {
			desc.header[fi] = v
		}
		return desc.diag.result()
	}

	// - 15. If TYPE is 'ITEM' and RN is greater than N, then the COUNT field of
	// D is set to RN.
	if rn > desc.count() {
		desc.set_count(rn)
	}
	desc.records[rn - 1][fi] = v

	// - 16. Setting the data type (or parameter) of the item also sets the
	// DATA_POINTER field of IDA to zero.
	if fi in [int(sql_desc_type), sql_desc_length, sql_desc_octet_length, sql_desc_precision,
		sql_desc_scale, sql_desc_datetime_interval_code, sql_desc_datetime_interval_precision,
		sql_desc_parameter_mode, sql_desc_parameter_ordinal_position,
		sql_desc_parameter_specific_catalog, sql_desc_parameter_specific_schema,
		sql_desc_parameter_specific_name, sql_desc_character_set_catalog,
		sql_desc_character_set_schema, sql_desc_character_set_name, sql_desc_udt_catalog,
		sql_desc_udt_schema, sql_desc_udt_name, sql_desc_scope_catalog, sql_desc_scope_schema,
		sql_desc_scope_name] && desc.typ != .ird {
		desc.records[rn - 1][sql_desc_data_pointer] = i64(0)
	}

	// - 19. Setting the TYPE sets the other fields to the defaults for the type.
	if fi == sql_desc_type {
		desc.set_type_defaults(rn, n)
	}

	// - 20. Setting the DATETIME_INTERVAL_CODE of a datetime sets its
	// PRECISION.
	if fi == sql_desc_datetime_interval_code && desc.record_int(rn, sql_desc_type) == sql_datetime {
		desc.records[rn - 1][sql_desc_precision] = i64(if n in [
			i64(sql_code_timestamp),
			sql_code_timestamp_zone,
		] {
			6
		} else {
			0
		})
	}

	return desc.diag.result()
}

// desc_string_value is the string Value of BufferLength octets (or
// SQL_NTS). The CHARACTER_SET_CATALOG, CHARACTER_SET_SCHEMA and
// CHARACTER_SET_NAME must be an <identifier> (see 13.i).
fn desc_string_value(mut diag Diagnostics, fi int, value voidptr, buffer_length i64) !string {
	s := input_string(unsafe { &char(value) }, buffer_length)!
	if fi !in [int(sql_desc_character_set_catalog), sql_desc_character_set_schema,
		sql_desc_character_set_name] {
		return s
	}

	// - 13.i.iii. If L is zero, then an exception condition is raised:
	// CLI-specific condition — invalid string length or buffer length.
	if s.len == 0 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	// - 13.i.v. The value is trimmed, and truncated to 128 characters with a
	// warning.
	mut fv := s.trim(' ')
	if fv.runes().len > 128 {
		fv = fv.runes()[..128].string()
		diag.warning('01004', 'string data, right truncation')
	}

	// - 13.i.vi. FV must conform to the Format and Syntax Rules of an
	// <identifier>.
	if !is_identifier(fv) {
		return match fi {
			sql_desc_character_set_catalog { cli_error('3D000', 'invalid catalog name') }
			sql_desc_character_set_schema { cli_error('3F000', 'invalid schema name') }
			else { cli_error('2C000', 'invalid character set name') }
		}
	}

	return fv
}

// is_identifier is true for a <regular identifier> or a <delimited
// identifier>.
fn is_identifier(s string) bool {
	if s.len > 1 && s[0] == `"` && s[s.len - 1] == `"` {
		return s[1..s.len - 1].replace('""', '').count('"') == 0
	}

	return s.len > 0 && (s[0].is_letter() || s[0] > 127)
		&& s.bytes().all(it.is_letter() || it.is_digit() || it == `_` || it > 127)
}

// check_desc_type returns an error if the code isn't a data type for the type
// of descriptor: the application data types (Table 7) and DEFAULT for an ARD
// and APD, or the implementation data types (Table 6) for an IPD.
fn check_desc_type(desc &Desc, code i64) ! {
	supported := if desc.is_application() {
		[i64(sql_default), sql_char, sql_numeric, sql_decimal, sql_integer, sql_smallint, sql_float,
			sql_real, sql_double, sql_bigint]
	} else {
		[i64(sql_char), sql_numeric, sql_decimal, sql_integer, sql_smallint, sql_float, sql_real,
			sql_double, sql_datetime, sql_varchar, sql_boolean, sql_bigint]
	}
	if code in supported {
		return
	}

	// The other data types in Table 6 and Table 7 (intervals, large objects,
	// locators, user-defined, reference, row, array and multiset types) aren't
	// supported by vsql.
	if code in [i64(10), 17, 18, 19, 20, 30, 31, 40, 41, 50, 51, 55, 56] {
		return cli_error('HYC00', 'optional feature not implemented')
	}

	return cli_error('HY004', 'invalid data type')
}

// set_type_defaults sets the fields of the RN-th item descriptor area after its
// TYPE is set (see 6.56, "SetDescField", General Rule 19).
fn (mut desc Desc) set_type_defaults(rn int, code i64) {
	mut record := desc.records[rn - 1].clone()
	defer {
		desc.records[rn - 1] = record
	}
	for field in [int(sql_desc_length), sql_desc_octet_length, sql_desc_precision, sql_desc_scale,
		sql_desc_datetime_interval_code, sql_desc_datetime_interval_precision,
		sql_desc_character_set_catalog, sql_desc_character_set_schema, sql_desc_character_set_name,
		sql_desc_collation_catalog, sql_desc_collation_schema, sql_desc_collation_name] {
		record.delete(field)
	}

	match code {
		sql_char, sql_varchar {
			// - 19.b.i. The default character set and the maximum length.
			mut catalog := ''
			if dbc := dbcs[desc.dbc] {
				if mut conn := dbc.conn {
					catalog = conn.current_catalog_name()
				}
			}
			record[sql_desc_character_set_catalog] = catalog
			record[sql_desc_character_set_schema] = 'INFORMATION_SCHEMA'
			record[sql_desc_character_set_name] = 'UTF8'
			record[sql_desc_length] = i64(10485760)
		}
		sql_datetime {
			record[sql_desc_precision] = i64(0)
		}
		sql_numeric, sql_decimal, sql_smallint, sql_integer, sql_bigint {
			// - 19.b.v, 19.b.vi. The default precision of a NUMERIC or DECIMAL is
			// the maximum precision.
			record[sql_desc_scale] = i64(0)
			record[sql_desc_precision] = i64(match code {
				sql_smallint { 16 }
				sql_integer { 32 }
				sql_bigint { 64 }
				else { 1000 }
			})
		}
		sql_float, sql_double {
			record[sql_desc_precision] = i64(53)
		}
		sql_real {
			record[sql_desc_precision] = i64(24)
		}
		else {}
	}
}

// is_consistent is true if an item descriptor area of an ARD or APD has a data
// type that can be used in C (see 5.13, "Description of CLI item descriptor
// areas", Syntax Rule 7). An item descriptor area of an IPD must be valid (see
// Syntax Rule 5).
fn (desc &Desc) is_consistent(record map[int]DescValue) bool {
	typ := record[sql_desc_type] or { return false }
	code := if typ is i64 { typ } else { return false }

	if desc.is_application() {
		return code == sql_default || c_type(i16(code)) != none
	}

	int_field := fn [record] (field int) i64 {
		v := record[field] or { return -1 }
		return if v is i64 { v } else { -1 }
	}

	return match code {
		sql_char, sql_varchar {
			int_field(sql_desc_length) > 0
		}
		sql_numeric, sql_decimal {
			p := int_field(sql_desc_precision)
			s := int_field(sql_desc_scale)
			p >= 1 && p <= 1000 && s >= 0 && s <= p
		}
		sql_float {
			p := int_field(sql_desc_precision)
			p >= 1 && p <= 53
		}
		sql_datetime {
			int_field(sql_desc_datetime_interval_code) in [i64(sql_code_date), sql_code_time,
				sql_code_timestamp, sql_code_time_zone, sql_code_timestamp_zone]
		}
		sql_smallint, sql_integer, sql_bigint, sql_real, sql_double, sql_boolean {
			true
		}
		else {
			false
		}
	}
}
