module main

// ISO/IEC 9075-3:2003(E), 6.13, CopyDesc
//
// Copy a CLI descriptor.

@[export: 'SQLCopyDesc']
fn sql_copy_desc(source_desc_handle SQLInteger, target_desc_handle SQLInteger) i16 {
	entry := enter(sql_handle_desc, i64(target_desc_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.13, CopyDesc, General Rules, 1 and 2: both
	// handles must identify an allocated CLI descriptor area.
	source := descs[i64(source_desc_handle)] or { return sql_invalid_handle }
	mut target := descs[i64(target_desc_handle)] or { return sql_invalid_handle }
	target.diag.clear()

	// ISO/IEC 9075-3:2003(E), 6.13, CopyDesc, General Rules, 3 and 4 (ISO/IEC
	// 9075-3:2003(E), 5.11, Deferred parameter check)
	check_desc_deferred(i64(source_desc_handle)) or { return target.diag.error(err) }
	check_desc_deferred(i64(target_desc_handle)) or { return target.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.13, CopyDesc, General Rules, 5: the target
	// can't be an implementation row descriptor.
	if target.typ == .ird {
		// The standard doesn't give this condition a SQLSTATE (it's not in Table 4,
		// "SQLSTATE class and subclass values for SQL/CLI-specific conditions"), so
		// it's HY016, the same as ODBC.
		return target.diag.error(cli_error('HY016', 'cannot modify an implementation row descriptor'))
	}

	// ISO/IEC 9075-3:2003(E), 6.13, CopyDesc, General Rules, 6-8: the contents
	// of TD are replaced by a copy of the contents of SD, except for the
	// ALLOC_TYPE.
	alloc_type := target.header[sql_desc_alloc_type] or { DescValue(i64(sql_desc_alloc_user)) }
	target.header = source.header.clone()
	target.header[sql_desc_alloc_type] = alloc_type
	target.records = source.records.map(it.clone())

	return sql_success
}
