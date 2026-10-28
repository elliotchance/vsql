module main

import vsql

// ISO/IEC 9075-3:2003(E), 4.4.7, CLI descriptor areas
//
// A CLI descriptor area describes the dynamic parameters (the application and
// implementation parameter descriptors, APD and IPD) or the result columns
// (the application and implementation row descriptors, ARD and IRD) of a
// statement. Each statement has one of each that's automatically allocated,
// and the application can allocate more to use as the ARD or APD.
//
// The fields are stored by their code (Table 20, "Codes used for SQL/CLI
// descriptor fields"). A field that isn't stored is initially undefined.

// Codes from Table 20, "Codes used for SQL/CLI descriptor fields".
const sql_desc_array_size = i16(20)
const sql_desc_array_status_pointer = i16(21)
const sql_desc_datetime_interval_precision = i16(26)
const sql_desc_rows_processed_pointer = i16(34)
const sql_desc_count = i16(1001)
const sql_desc_type = i16(1002)
const sql_desc_length = i16(1003)
const sql_desc_octet_length_pointer = i16(1004)
const sql_desc_precision = i16(1005)
const sql_desc_scale = i16(1006)
const sql_desc_datetime_interval_code = i16(1007)
const sql_desc_nullable = i16(1008)
const sql_desc_indicator_pointer = i16(1009)
const sql_desc_data_pointer = i16(1010)
const sql_desc_name = i16(1011)
const sql_desc_unnamed = i16(1012)
const sql_desc_octet_length = i16(1013)
const sql_desc_collation_catalog = i16(1015)
const sql_desc_collation_schema = i16(1016)
const sql_desc_collation_name = i16(1017)
const sql_desc_character_set_catalog = i16(1018)
const sql_desc_character_set_schema = i16(1019)
const sql_desc_character_set_name = i16(1020)
const sql_desc_parameter_mode = i16(1021)
const sql_desc_parameter_ordinal_position = i16(1022)
const sql_desc_parameter_specific_catalog = i16(1023)
const sql_desc_parameter_specific_schema = i16(1024)
const sql_desc_parameter_specific_name = i16(1025)
const sql_desc_udt_catalog = i16(1026)
const sql_desc_udt_schema = i16(1027)
const sql_desc_udt_name = i16(1028)
const sql_desc_key_type = i16(1029)
const sql_desc_key_member = i16(1030)
const sql_desc_dynamic_function = i16(1031)
const sql_desc_dynamic_function_code = i16(1032)
const sql_desc_scope_catalog = i16(1033)
const sql_desc_scope_schema = i16(1034)
const sql_desc_scope_name = i16(1035)
const sql_desc_specific_type_catalog = i16(1036)
const sql_desc_specific_type_schema = i16(1037)
const sql_desc_specific_type_name = i16(1038)
const sql_desc_current_transform_group = i16(1039)
const sql_desc_cardinality = i16(1040)
const sql_desc_degree = i16(1041)
const sql_desc_level = i16(1042)
const sql_desc_returned_cardinality_pointer = i16(1043)
const sql_desc_top_level_count = i16(1044)
const sql_desc_user_defined_type_code = i16(1045)
const sql_desc_alloc_type = i16(1099)

// Codes from Table 26, "Miscellaneous codes used in CLI".
const sql_desc_alloc_auto = i16(1)
const sql_desc_alloc_user = i16(2)
const sql_unnamed = i16(1)
const sql_named = i16(0)

// Codes from Table 8, "Codes associated with datetime data types in SQL/CLI".
const sql_code_date = i16(1)
const sql_code_time = i16(2)
const sql_code_timestamp = i16(3)
const sql_code_time_zone = i16(4)
const sql_code_timestamp_zone = i16(5)

// The type of a descriptor. A descriptor allocated by the application is an
// .ard, although it can also be used as an APD (the fields that can be set and
// retrieved are the same).
enum DescType {
	ard
	ird
	apd
	ipd
}

// The value of a descriptor field. A pointer is stored as its address.
type DescValue = i64 | string

// An allocated CLI descriptor area.
struct Desc {
mut:
	diag Diagnostics
	dbc  i64
	typ  DescType
	// stmt is the statement that automatically allocated the descriptor, or 0
	// (zero) if it was allocated by the application.
	stmt    i64
	header  map[int]DescValue
	records []map[int]DescValue
}

enum DescFieldKind {
	smallint
	integer
	pointer
	string
}

// DescField describes a descriptor field. settable (from Table 21, "Ability
// to set SQL/CLI descriptor fields") and retrievable (from Table 22, "Ability
// to retrieve SQL/CLI descriptor fields") have a character for the ARD, IRD,
// APD and IPD (in that order): 'y' (yes), 'n' (no) or, for retrievable, 'p'
// (only when the IRD has a prepared or executed statement).
struct DescField {
	header      bool
	kind        DescFieldKind
	settable    string = 'ynyy'
	retrievable string = 'ypyy'
}

const desc_fields = {
	int(sql_desc_alloc_type):              DescField{
		header:   true
		kind:     .smallint
		settable: 'nnnn'
	}
	sql_desc_array_size:                   DescField{
		header:      true
		kind:        .integer
		settable:    'ynyn'
		retrievable: 'ynyn'
	}
	sql_desc_array_status_pointer:         DescField{
		header:      true
		kind:        .pointer
		settable:    'yyyy'
		retrievable: 'yyyy'
	}
	sql_desc_count:                        DescField{
		header: true
		kind:   .smallint
	}
	sql_desc_dynamic_function:             DescField{
		header:      true
		kind:        .string
		settable:    'nnnn'
		retrievable: 'nyny'
	}
	sql_desc_dynamic_function_code:        DescField{
		header:      true
		kind:        .integer
		settable:    'nnnn'
		retrievable: 'nyny'
	}
	sql_desc_key_type:                     DescField{
		header:      true
		kind:        .smallint
		settable:    'nnnn'
		retrievable: 'npnn'
	}
	sql_desc_rows_processed_pointer:       DescField{
		header:      true
		kind:        .pointer
		settable:    'nyny'
		retrievable: 'nyny'
	}
	sql_desc_top_level_count:              DescField{
		header: true
		kind:   .smallint
	}
	sql_desc_cardinality:                  DescField{
		kind:        .integer
		settable:    'nnny'
		retrievable: 'npny'
	}
	sql_desc_character_set_catalog:        DescField{
		kind: .string
	}
	sql_desc_character_set_schema:         DescField{
		kind: .string
	}
	sql_desc_character_set_name:           DescField{
		kind: .string
	}
	sql_desc_collation_catalog:            DescField{
		kind: .string
	}
	sql_desc_collation_schema:             DescField{
		kind: .string
	}
	sql_desc_collation_name:               DescField{
		kind: .string
	}
	sql_desc_current_transform_group:      DescField{
		kind:     .string
		settable: 'nnnn'
	}
	sql_desc_data_pointer:                 DescField{
		kind:        .pointer
		retrievable: 'ynyn'
	}
	sql_desc_datetime_interval_code:       DescField{
		kind: .smallint
	}
	sql_desc_datetime_interval_precision:  DescField{
		kind: .smallint
	}
	sql_desc_degree:                       DescField{
		kind:        .integer
		settable:    'nnny'
		retrievable: 'npny'
	}
	sql_desc_indicator_pointer:            DescField{
		kind:        .pointer
		settable:    'ynyn'
		retrievable: 'ynyn'
	}
	sql_desc_key_member:                   DescField{
		kind:        .smallint
		settable:    'nnnn'
		retrievable: 'npnn'
	}
	sql_desc_length:                       DescField{
		kind: .integer
	}
	sql_desc_level:                        DescField{
		kind: .integer
	}
	sql_desc_name:                         DescField{
		kind: .string
	}
	sql_desc_nullable:                     DescField{
		kind: .smallint
	}
	sql_desc_octet_length:                 DescField{
		kind: .integer
	}
	sql_desc_octet_length_pointer:         DescField{
		kind:        .pointer
		settable:    'ynyn'
		retrievable: 'ynyn'
	}
	sql_desc_parameter_mode:               DescField{
		kind:        .smallint
		settable:    'nnny'
		retrievable: 'npny'
	}
	sql_desc_parameter_ordinal_position:   DescField{
		kind:        .smallint
		settable:    'nnny'
		retrievable: 'npny'
	}
	sql_desc_parameter_specific_catalog:   DescField{
		kind:        .string
		settable:    'nnny'
		retrievable: 'npny'
	}
	sql_desc_parameter_specific_schema:    DescField{
		kind:        .string
		settable:    'nnny'
		retrievable: 'npny'
	}
	sql_desc_parameter_specific_name:      DescField{
		kind:        .string
		settable:    'nnny'
		retrievable: 'npny'
	}
	sql_desc_precision:                    DescField{
		kind: .smallint
	}
	sql_desc_returned_cardinality_pointer: DescField{
		kind:        .pointer
		settable:    'ynyn'
		retrievable: 'ynyn'
	}
	sql_desc_scale:                        DescField{
		kind: .smallint
	}
	sql_desc_scope_catalog:                DescField{
		kind: .string
	}
	sql_desc_scope_schema:                 DescField{
		kind: .string
	}
	sql_desc_scope_name:                   DescField{
		kind: .string
	}
	sql_desc_specific_type_catalog:        DescField{
		kind:     .string
		settable: 'nnnn'
	}
	sql_desc_specific_type_schema:         DescField{
		kind:     .string
		settable: 'nnnn'
	}
	sql_desc_specific_type_name:           DescField{
		kind:     .string
		settable: 'nnnn'
	}
	sql_desc_type:                         DescField{
		kind: .smallint
	}
	sql_desc_unnamed:                      DescField{
		kind: .smallint
	}
	sql_desc_udt_catalog:                  DescField{
		kind: .string
	}
	sql_desc_udt_schema:                   DescField{
		kind: .string
	}
	sql_desc_udt_name:                     DescField{
		kind: .string
	}
	sql_desc_user_defined_type_code:       DescField{
		kind:     .smallint
		settable: 'nnnn'
	}
}

// The allocated CLI descriptor areas.
__global descs = map[i64]&Desc{}

// new_desc allocates a CLI descriptor area with the default values from Table
// 23, "SQL/CLI descriptor field default values".
fn new_desc(dbc i64, typ DescType, stmt i64) i64 {
	h := new_handle()
	descs[h] = &Desc{
		dbc:  dbc
		typ:  typ
		stmt: stmt
	}
	mut desc := descs[h] or { return h }
	desc.reset()

	return h
}

// reset sets the fields of the descriptor to their default values.
fn (mut desc Desc) reset() {
	desc.records = []
	desc.header = {
		int(sql_desc_alloc_type):      DescValue(i64(if desc.stmt == 0 {
			sql_desc_alloc_user
		} else {
			sql_desc_alloc_auto
		}))
		sql_desc_array_status_pointer: i64(0)
		sql_desc_count:                i64(0)
	}
	if desc.is_application() {
		desc.header[sql_desc_array_size] = i64(1)
		desc.header[sql_desc_top_level_count] = i64(0)
	} else {
		desc.header[sql_desc_rows_processed_pointer] = i64(0)
	}
}

fn (desc &Desc) is_application() bool {
	return desc.typ in [.ard, .apd]
}

// count is the COUNT field, the number of item descriptor areas.
fn (desc &Desc) count() int {
	return desc.records.len
}

// set_count changes the number of item descriptor areas. New item descriptor
// areas have the default values.
fn (mut desc Desc) set_count(n int) {
	if n < desc.records.len {
		desc.records = desc.records[..n]
	}
	for desc.records.len < n {
		desc.records << desc.default_record()
	}
	desc.header[sql_desc_count] = i64(n)
}

// default_record is a new item descriptor area. Only the application
// descriptors have default values.
fn (desc &Desc) default_record() map[int]DescValue {
	if !desc.is_application() {
		return map[int]DescValue{}
	}

	return {
		int(sql_desc_data_pointer):            DescValue(i64(0))
		sql_desc_indicator_pointer:            i64(0)
		sql_desc_octet_length_pointer:         i64(0)
		sql_desc_returned_cardinality_pointer: i64(0)
		sql_desc_level:                        i64(0)
		sql_desc_type:                         i64(sql_default)
	}
}

// record_int is an integer (or pointer) field of the RN-th item descriptor
// area, or 0 (zero) if it doesn't exist or is undefined.
fn (desc &Desc) record_int(rn int, field int) i64 {
	if rn < 1 || rn > desc.records.len {
		return 0
	}
	value := desc.records[rn - 1][field] or { return 0 }

	return if value is i64 { value } else { 0 }
}

fn (desc &Desc) header_int(field int) i64 {
	value := desc.header[field] or { return 0 }

	return if value is i64 { value } else { 0 }
}

// field_index is the position of the descriptor type in the settable and
// retrievable columns of DescField.
fn (desc &Desc) field_index() int {
	return match desc.typ {
		.ard { 0 }
		.ird { 1 }
		.apd { 2 }
		.ipd { 3 }
	}
}

// describe sets the IRD and IPD of a statement after it's executed, see 5.5,
// "Implicit DESCRIBE USING clause". The IPD isn't populated, since POPULATE IPD
// is False.
fn describe(stmt &Stmt, mut conn vsql.Connection, columns []vsql.Column) {
	mut ird := descs[stmt.ird] or { return }
	mut ipd := descs[stmt.ipd] or { return }

	// - 4. The value of DYNAMIC_FUNCTION and DYNAMIC_FUNCTION_CODE in IRD and
	// IPD identify the prepared statement.
	ipd.header[sql_desc_dynamic_function] = stmt.diag.dynamic_function
	ipd.header[sql_desc_dynamic_function_code] = i64(stmt.diag.dynamic_function_code)

	// - 5. The IRD describes the result columns, if any. vsql doesn't know if a
	// result column is part of a key, so KEY_TYPE and KEY_MEMBER are 0 (zero).
	// The application's ARRAY_STATUS_POINTER and ROWS_PROCESSED_POINTER are
	// kept.
	status_pointer := ird.header_int(sql_desc_array_status_pointer)
	rows_processed_pointer := ird.header_int(sql_desc_rows_processed_pointer)
	ird.reset()
	ird.header[sql_desc_array_status_pointer] = status_pointer
	ird.header[sql_desc_rows_processed_pointer] = rows_processed_pointer
	ird.header[sql_desc_dynamic_function] = stmt.diag.dynamic_function
	ird.header[sql_desc_dynamic_function_code] = i64(stmt.diag.dynamic_function_code)
	ird.header[sql_desc_key_type] = i64(0)
	ird.header[sql_desc_top_level_count] = i64(columns.len)
	ird.set_count(columns.len)
	for i, column in columns {
		ird.records[i] = describe_column(column, conn.current_catalog_name())
	}
}

// describe_column is the item descriptor area of an IRD for a column.
fn describe_column(column vsql.Column, catalog string) map[int]DescValue {
	typ := column.typ

	// Fields that aren't applicable to the data type are implementation-
	// dependent values (zero, or a zero-length string).
	mut record := map[int]DescValue{}
	for field, info in desc_fields {
		if !info.header && info.retrievable[1] == `p` {
			record[field] = if info.kind == .string { DescValue('') } else { DescValue(i64(0)) }
		}
	}

	// - 5.c. vsql gives every column a name (an expression without an AS has a
	// name like COL1), so it's never UNNAMED.
	record[sql_desc_level] = i64(0)
	record[sql_desc_type] = i64(implementation_type_code(typ))
	record[sql_desc_nullable] = i64(if column.not_null { sql_no_nulls } else { sql_nullable })
	record[sql_desc_name] = column.name.sub_entity_name
	record[sql_desc_unnamed] = i64(sql_named)
	record[sql_desc_key_member] = i64(0)

	// - 5.c.iv. Other fields depend on the TYPE.
	match typ.typ {
		.is_character, .is_varchar {
			// Character strings are UTF-8, which uses up to 4 octets for each
			// character (the same as the INFORMATION_SCHEMA).
			record[sql_desc_length] = i64(typ.size)
			record[sql_desc_octet_length] = i64(typ.size) * 4
			record[sql_desc_character_set_catalog] = catalog
			record[sql_desc_character_set_schema] = 'INFORMATION_SCHEMA'
			record[sql_desc_character_set_name] = 'UTF8'
		}
		.is_smallint, .is_integer, .is_bigint, .is_decimal, .is_numeric, .is_real,
		.is_double_precision {
			record[sql_desc_precision] = i64(numeric_precision_of(typ))
			record[sql_desc_scale] = i64(typ.scale)
		}
		.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
		.is_timestamp_without_time_zone, .is_timestamp_with_time_zone {
			record[sql_desc_length] = i64(datetime_length(typ))
			record[sql_desc_datetime_interval_code] = i64(datetime_interval_code(typ))
			record[sql_desc_precision] = i64(typ.size)
		}
		.is_boolean {}
	}

	return record
}

// implementation_type_code is the code for the data type of a column from
// Table 6, "Codes used for implementation data types in SQL/CLI". Unlike
// data_type_code, each datetime type is DATETIME.
fn implementation_type_code(typ vsql.Type) i16 {
	return if datetime_interval_code(typ) > 0 { sql_datetime } else { data_type_code(typ) }
}

// datetime_interval_code is the code from Table 8, "Codes associated with
// datetime data types in SQL/CLI", or 0 (zero) if the type isn't a datetime.
fn datetime_interval_code(typ vsql.Type) i16 {
	return match typ.typ {
		.is_date { sql_code_date }
		.is_time_without_time_zone { sql_code_time }
		.is_timestamp_without_time_zone { sql_code_timestamp }
		.is_time_with_time_zone { sql_code_time_zone }
		.is_timestamp_with_time_zone { sql_code_timestamp_zone }
		else { 0 }
	}
}

// numeric_precision_of is the precision of a numeric type, which is in bits for
// SMALLINT, INTEGER, BIGINT, REAL and DOUBLE PRECISION (the same as the
// INFORMATION_SCHEMA).
fn numeric_precision_of(typ vsql.Type) int {
	return match typ.typ {
		.is_smallint { 16 }
		.is_integer { 32 }
		.is_bigint { 64 }
		.is_real { 24 }
		.is_double_precision { 53 }
		else {
			if typ.size == 0 { 1000 } else { typ.size }
		}
	}
}

// concise_type_code converts a TYPE (and DATETIME_INTERVAL_CODE) to the codes
// used by DescribeCol and ColAttribute, where each datetime type has its own
// code from Table 40, "Concise codes used with datetime data types in SQL/CLI".
fn concise_type_code(typ i64, datetime_interval_code i64) i64 {
	return if typ == sql_datetime { 90 + datetime_interval_code } else { typ }
}

// desc_statements is the statements for which the descriptor is the current
// ARD or APD.
// free_desc frees a descriptor allocated by the application. Each statement
// that used it as its ARD or APD, which may be a statement of another
// connection, goes back to its automatically allocated one (see 6.26,
// FreeHandle, General Rules 3.d.ix and 3.d.x).
fn free_desc(h i64) {
	for sh in desc_statements(h) {
		mut stmt := stmts[sh] or { continue }
		if stmt.ard == h {
			stmt.ard = stmt.auto_ard
		}
		if stmt.apd == h {
			stmt.apd = stmt.auto_apd
		}
	}

	descs.delete(h)
}

fn desc_statements(h i64) []i64 {
	mut result := []i64{}
	for sh, stmt in stmts {
		if stmt.ard == h || stmt.apd == h {
			result << sh
		}
	}
	result.sort()

	return result
}

// has_prepared_or_executed is true if the IRD is associated with a statement
// that's prepared or executed (for the fields that are "PS" in Table 22).
fn (desc &Desc) has_prepared_or_executed() bool {
	stmt := stmts[desc.stmt] or { return false }

	return stmt.executed || stmt.prepared != none
}

// check_desc_deferred raises an exception condition if the descriptor is the
// current APD, or the IPD, of a statement that has a deferred parameter number:
// CLI-specific condition — function sequence error (see 5.11, "Deferred
// parameter check").
fn check_desc_deferred(h i64) ! {
	for _, stmt in stmts {
		if (stmt.apd == h || stmt.ipd == h) && stmt.deferred() > 0 {
			return cli_error('HY010', 'function sequence error')
		}
	}
}
