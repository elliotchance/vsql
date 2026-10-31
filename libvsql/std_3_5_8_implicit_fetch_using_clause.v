module main

import vsql

// ISO/IEC 9075-3:2003(E), 5.8, Implicit FETCH USING clause
//
// Specify the rules for an implicit FETCH USING clause.
//
// The rows of the rowset that a cursor has been positioned on (by Fetch or
// FetchScroll) are assigned to the bound targets: the item descriptor areas of
// the ARD that have a DATA_POINTER. For a rowset of more than one row, each
// bound target (and its indicator and length) is an array with an element for
// each row.
//
// COUNT can't be negative (see SetDescField), so General Rules 3.a can't
// happen. There are no locators, so the type of a bound target can change
// between fetches (General Rules, 3.h.v). A zero-length character string isn't
// an exception condition, which is implementation-defined (General Rules,
// 3.h.viii.2.B.II.1.a).

// Codes from Table 25, "Multi-row fetch status codes", for the status of each
// row of a rowset (ISO/IEC 9075-3:2003(E), 4.4.8, Obtaining diagnostics during
// multi-row fetch).
const sql_row_success = i16(0)
const sql_row_no_row = i16(3)
const sql_row_error = i16(5)
const sql_row_success_with_info = i16(6)

// BoundTarget is an item descriptor area of the ARD that has a DATA_POINTER,
// and the column that it's bound to.
struct BoundTarget {
	column_number    int
	column           vsql.Column
	typ              vsql.SQLType
	octet_length     i64
	data_pointer     voidptr
	indicator        voidptr
	length_indicator voidptr
}

// bound_targets returns the bound targets of the ARD of a statement, which
// must be valid (ISO/IEC 9075-3:2003(E), 5.13, Description of CLI item
// descriptor areas, Syntax Rules, 13), otherwise an exception condition is
// raised: dynamic SQL error — using clause does not match target
// specifications.
fn bound_targets(stmt &Stmt) ![]BoundTarget {
	ard := descs[stmt.ard] or { return cli_error('HY010', 'function sequence error') }
	ird := descs[stmt.ird] or { return cli_error('HY010', 'function sequence error') }
	columns := if cursor := stmt.cursor { cursor.columns } else { []vsql.Column{} }

	mut targets := []BoundTarget{}
	for i in 1 .. ard.count() + 1 {
		data_pointer := ard.record_int(i, sql_desc_data_pointer)
		if data_pointer == 0 {
			continue
		}

		// A bound target must be for a column of the cursor.
		if i > columns.len {
			return cli_error('07009', 'invalid descriptor index')
		}

		// - 3.c. A TYPE of DEFAULT is the type of the column (from the IRD).
		mut code := ard.record_int(i, sql_desc_type)
		if code == sql_default {
			code = ird.record_int(i, sql_desc_type)
		}
		typ := c_type(i16(code)) or {
			return cli_error('07002', 'using clause does not match target specifications')
		}

		targets << BoundTarget{
			column_number:    i
			column:           columns[i - 1]
			typ:              typ
			octet_length:     ard.record_int(i, sql_desc_octet_length)
			data_pointer:     voidptr(data_pointer)
			indicator:        voidptr(ard.record_int(i, sql_desc_indicator_pointer))
			length_indicator: voidptr(ard.record_int(i, sql_desc_octet_length_pointer))
		}
	}

	return targets
}

// fetch_using assigns the rows of the rowset that the cursor is positioned on to
// the bound targets, and sets the ARRAY_STATUS_POINTER and
// ROWS_PROCESSED_POINTER of the IRD (see 6.21, "Fetch", General Rules 11 to
// 14). A row that can't be assigned is a row error, and its conditions have
// its ROW_NUMBER.
fn fetch_using(mut stmt Stmt, targets []BoundTarget) !i16 {
	ard := descs[stmt.ard] or { return cli_error('HY010', 'function sequence error') }
	ird := descs[stmt.ird] or { return cli_error('HY010', 'function sequence error') }
	array_size := int(ard.header_int(sql_desc_array_size))
	status_pointer := voidptr(ird.header_int(sql_desc_array_status_pointer))
	rows_processed_pointer := voidptr(ird.header_int(sql_desc_rows_processed_pointer))
	nts := stmt.null_termination()

	// - 12. If RPP is not a null pointer, then set the value of the host
	// variable addressed by RPP to zero.
	set_integer(rows_processed_pointer, 0, 0)

	mut rows_processed := 0
	mut warnings := 0
	for rn in 1 .. stmt.rowset_len + 1 {
		row := stmt.rows[stmt.rowset_start + rn - 1]
		mut status := sql_row_success
		for target in targets {
			mut diag := Diagnostics{}
			assign_target(mut diag, stmt, nts, target, row, rn - 1) or {
				stmt.diag.row_condition(err, rn, target.column_number)
				status = sql_row_error
			}
			for record in diag.records {
				stmt.diag.row_condition(cli_error(record.sqlstate, record.msg), rn,
					target.column_number)
				if status == sql_row_success {
					status = sql_row_success_with_info
				}
			}
		}

		if status != sql_row_error {
			rows_processed++
		}
		if status == sql_row_success_with_info {
			warnings++
		}
		set_status(status_pointer, rn - 1, status)
	}

	// - 14.a.iv.1. The elements of ASP after the rowset are No row.
	for i in stmt.rowset_len .. array_size {
		set_status(status_pointer, i, sql_row_no_row)
	}
	set_integer(rows_processed_pointer, 0, rows_processed)

	// A rowset where no rows could be assigned is an error, otherwise any row
	// errors are a completion condition: warning.
	if rows_processed == 0 && stmt.rowset_len > 0 {
		stmt.diag.returncode = sql_error
		return sql_error
	}
	if rows_processed < stmt.rowset_len {
		stmt.diag.records.prepend(DiagnosticRecord{
			sqlstate: '01000'
			msg:      'warning'
		})
	}

	return stmt.diag.result()
}

// assign_target assigns the column of a row to the i-th element of a bound
// target (see 5.8, General Rule 3.h).
fn assign_target(mut diag Diagnostics, stmt &Stmt, nts bool, target BoundTarget, row vsql.Row, i int) ! {
	value := row.get_column(target.column)!
	element_size := if target.typ == .is_varchar {
		target.octet_length
	} else {
		c_type_size(target.typ)
	}
	data := unsafe { voidptr(&u8(target.data_pointer) + i * element_size) }

	// - 3.h.viii.2.A. A null value sets the indicator to SQL NULL DATA, which
	// must not be a null pointer: data exception — null value, no indicator
	// parameter.
	if value.is_null {
		if target.indicator == unsafe { nil } {
			return cli_error('22002', 'null value, no indicator parameter')
		}
		set_integer(target.indicator, i, sql_null_data)
		return
	}

	// - 3.h.viii.2.B. Otherwise, the indicator is set to 0 (zero) and the value
	// is assigned.
	if target.typ == .is_varchar {
		set_integer(target.indicator, i, 0)
		length := if target.length_indicator == unsafe { nil } {
			unsafe { nil }
		} else {
			unsafe { voidptr(&u8(target.length_indicator) + i * int(sizeof(SQLInteger))) }
		}
		retrieve_string(mut diag, nts, data, value.str(), target.octet_length, length,
			4)!
		return
	}

	tv := cast_value(stmt, value, target.column, target.typ)!
	set_integer(target.indicator, i, 0)
	assign_number(tv, target.typ, data)
}

// set_integer sets the i-th element of an SQLINTEGER array, unless it's a null
// pointer.
fn set_integer(array voidptr, i int, value int) {
	if array != unsafe { nil } {
		unsafe {
			*(&SQLInteger(array) + i) = SQLInteger(value)
		}
	}
}

// set_status sets the i-th element of the ARRAY_STATUS_POINTER, which is an
// array of INTEGER (see Table 5, "Fields in SQL/CLI row and parameter
// descriptor areas").
fn set_status(array voidptr, i int, status i16) {
	set_integer(array, i, status)
}
