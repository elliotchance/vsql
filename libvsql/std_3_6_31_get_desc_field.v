module main

// ISO/IEC 9075-3:2003(E), 6.31, GetDescField
//
// Get a field from a CLI descriptor area.

@[export: 'SQLGetDescField']
fn sql_get_desc_field(descriptor_handle SQLInteger, record_number i16, field_identifier i16, value voidptr, buffer_length SQLInteger, string_length &SQLInteger) i16 {
	mut desc := descs[i64(descriptor_handle)] or { return sql_invalid_handle }
	desc.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.ii.
	desc.invoke() or { return desc.diag.error(err) }

	// See 5.11, "Deferred parameter check".
	check_desc_deferred(i64(descriptor_handle)) or { return desc.diag.error(err) }

	v := desc_field_value(desc, record_number, field_identifier) or {
		return desc.diag.error(err)
	}

	write_desc_field(mut desc.diag, desc_null_termination(desc), field_identifier, v, value,
		buffer_length, string_length, 4, false) or { return desc.diag.error(err) }

	return desc.diag.result()
}

// desc_field_value is the value of a field of a descriptor (the header field,
// or the field of the RN-th item descriptor area), or NoData for an item
// descriptor area that doesn't exist.
fn desc_field_value(desc &Desc, rn int, fi int) !DescValue {
	// - 3. If FI is not one of the code values in Table 20, then an exception
	// condition is raised: CLI-specific condition — invalid descriptor field
	// identifier.
	info := desc_fields[fi] or { return cli_error('HY091', 'invalid descriptor field identifier') }

	// - 7. An item descriptor area must exist.
	if !info.header {
		if rn < 1 {
			return cli_error('07009', 'invalid descriptor index')
		}
		if rn > desc.count() {
			return no_data()
		}
	}

	// - 9, 10, 11. The field must be retrievable from the type of descriptor
	// (Table 22, "Ability to retrieve SQL/CLI descriptor fields").
	match info.retrievable[desc.field_index()] {
		`n` {
			return cli_error('HY091', 'invalid descriptor field identifier')
		}
		`p` {
			if !desc.has_prepared_or_executed() {
				return cli_error('HY007', 'associated statement is not prepared')
			}
		}
		else {}
	}

	// - 12. If FI indicates a descriptor field whose value is the initially
	// undefined value created when the descriptor was created, then an
	// exception condition is raised: CLI-specific condition — invalid
	// descriptor field identifier.
	fields := if info.header { desc.header } else { desc.records[rn - 1] }

	return fields[fi] or { return cli_error('HY091', 'invalid descriptor field identifier') }
}

// write_desc_field sets the output of GetDescField (or ColAttribute) to the
// value of a field. A string is retrieved by the General Rules of Subclause
// 5.9, "Character string retrieval". If widen is true, a SMALLINT is written as
// an INTEGER.
fn write_desc_field(mut diag Diagnostics, nts bool, fi int, v DescValue, value voidptr, buffer_length i64, string_length voidptr, string_length_size int, widen bool) ! {
	if value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	info := desc_fields[fi] or { return }
	match v {
		string {
			retrieve_string(mut diag, nts, value, v, buffer_length, string_length, string_length_size)!
		}
		i64 {
			unsafe {
				match info.kind {
					.smallint {
						if widen {
							*&SQLInteger(value) = SQLInteger(v)
						} else {
							*&i16(value) = i16(v)
						}
					}
					.pointer {
						*&voidptr(value) = voidptr(v)
					}
					else {
						*&SQLInteger(value) = SQLInteger(v)
					}
				}
			}
		}
	}
}

// desc_null_termination is the NULL TERMINATION of the SQL-environment of a
// descriptor.
fn desc_null_termination(desc &Desc) bool {
	return null_termination((dbcs[desc.dbc] or { return true }).env)
}
