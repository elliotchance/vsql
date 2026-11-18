module vsql

// ISO/IEC 9075-11:2006, 5.49, ROUTINES view
//
// The ROUTINES view has a row for each routine of the VSQL schema (see
// vsql_routines), which are the functions that vsql has beyond the standard.
// There's no CREATE FUNCTION yet (T321), so there are no other routines. Each
// one is an external FUNCTION (ROUTINE_TYPE and ROUTINE_BODY, Description, 5
// and 7 of ISO/IEC 9075-11:2006, 6.40, ROUTINES base table), as if it had been
// created with:
//
//   CREATE FUNCTION VSQL.CBRT (DOUBLE PRECISION) RETURNS DOUBLE PRECISION
//     SPECIFIC CBRT_1 LANGUAGE C PARAMETER STYLE GENERAL DETERMINISTIC
//     NO SQL RETURNS NULL ON NULL INPUT EXTERNAL NAME 'CBRT'
//
// That is:
//
// - The external name is the name of the function, and the language is C,
//   which is what vsql is compiled to (Description, 12.a). The arguments are
//   passed as values, without indicators or an SQLSTATE, which is PARAMETER
//   STYLE GENERAL.
//
// - IS_DETERMINISTIC is NO for a function that can return a different result
//   for the same arguments, such as NOW (Description, 9). A function that's
//   registered with register_function (or a PostgreSQL function) is never
//   deterministic.
//
// - A built-in function (including a PostgreSQL function) doesn't read or
//   change any data (NO SQL). A function that's registered with
//   register_function can use its connection for anything, so it's MODIFIES
//   SQL DATA (Description, 8).
//
// - IS_NULL_CALL is YES for a function that returns NULL when any of its
//   arguments is NULL, which is every built-in function except the PostgreSQL
//   ones, and NO for a function that's always called, such as one that's
//   registered with register_function (Description, 10).
//
// - The security characteristic is IMPLEMENTATION DEFINED, since vsql doesn't
//   have authorization identifiers yet (#732), so a routine runs the same for
//   every user (Description, 18).
//
// - The routines are built into vsql, so they weren't created or altered at any
//   time, and CREATED and LAST_ALTERED are NULL (Description, 24 and 25).
//
// - Feature T272, "Enhanced savepoint management", isn't supported, so
//   NEW_SAVEPOINT_LEVEL is NULL (Description, 21).
//
// - There are no modules (Description, 3), user-defined types (Description, 4
//   and 22), transforms (Description, 19), result casts (Description, 23) or
//   locators (Description, 20), and none of the routines are user-defined casts
//   (Description, 16 and 17), so their columns are NULL or NO.
//
// The data type of the result is described like the data type of a column
// (see routine_data_type). The DTD_IDENTIFIER is implementation-dependent, but
// must identify the data type within the routine, so it's 0 for the result,
// and the ordinal position of a parameter (see PARAMETERS).
//
// The view only has the routines that the current user has the EXECUTE
// privilege on. There are no privileges (#732), so it has every routine.
fn (mut catalog CatalogConnection) register_routines_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	cd := information_schema_character_data
	cn := information_schema_cardinal_number
	yn := information_schema_yes_or_no
	ts := information_schema_time_stamp
	catalog.add_information_schema_table('CREATE TABLE ROUTINES (
		SPECIFIC_CATALOG ${id} NOT NULL,
		SPECIFIC_SCHEMA ${id} NOT NULL,
		SPECIFIC_NAME ${id} NOT NULL,
		ROUTINE_CATALOG ${id},
		ROUTINE_SCHEMA ${id},
		ROUTINE_NAME ${id},
		ROUTINE_TYPE ${cd} NOT NULL,
		MODULE_CATALOG ${id},
		MODULE_SCHEMA ${id},
		MODULE_NAME ${id},
		UDT_CATALOG ${id},
		UDT_SCHEMA ${id},
		UDT_NAME ${id},
		DATA_TYPE ${cd},
		CHARACTER_MAXIMUM_LENGTH ${cn},
		CHARACTER_OCTET_LENGTH ${cn},
		CHARACTER_SET_CATALOG ${id},
		CHARACTER_SET_SCHEMA ${id},
		CHARACTER_SET_NAME ${id},
		COLLATION_CATALOG ${id},
		COLLATION_SCHEMA ${id},
		COLLATION_NAME ${id},
		NUMERIC_PRECISION ${cn},
		NUMERIC_PRECISION_RADIX ${cn},
		NUMERIC_SCALE ${cn},
		DATETIME_PRECISION ${cn},
		INTERVAL_TYPE ${cd},
		INTERVAL_PRECISION ${cn},
		TYPE_UDT_CATALOG ${id},
		TYPE_UDT_SCHEMA ${id},
		TYPE_UDT_NAME ${id},
		SCOPE_CATALOG ${id},
		SCOPE_SCHEMA ${id},
		SCOPE_NAME ${id},
		MAXIMUM_CARDINALITY ${cn},
		DTD_IDENTIFIER ${id},
		ROUTINE_BODY ${cd} NOT NULL,
		ROUTINE_DEFINITION ${cd},
		EXTERNAL_NAME ${id},
		EXTERNAL_LANGUAGE ${cd},
		PARAMETER_STYLE ${cd},
		IS_DETERMINISTIC ${yn} NOT NULL,
		SQL_DATA_ACCESS ${cd} NOT NULL,
		IS_NULL_CALL ${yn},
		SQL_PATH ${cd},
		SCHEMA_LEVEL_ROUTINE ${yn},
		MAX_DYNAMIC_RESULT_SETS ${cn},
		IS_USER_DEFINED_CAST ${yn},
		IS_IMPLICITLY_INVOCABLE ${yn},
		SECURITY_TYPE ${cd},
		TO_SQL_SPECIFIC_CATALOG ${id},
		TO_SQL_SPECIFIC_SCHEMA ${id},
		TO_SQL_SPECIFIC_NAME ${id},
		AS_LOCATOR ${yn},
		CREATED ${ts},
		LAST_ALTERED ${ts},
		NEW_SAVEPOINT_LEVEL ${yn},
		IS_UDT_DEPENDENT ${yn} NOT NULL,
		RESULT_CAST_FROM_DATA_TYPE ${cd},
		RESULT_CAST_AS_LOCATOR ${yn},
		RESULT_CAST_CHAR_MAX_LENGTH ${cn},
		RESULT_CAST_CHAR_OCTET_LENGTH ${cn},
		RESULT_CAST_CHAR_SET_CATALOG ${id},
		RESULT_CAST_CHAR_SET_SCHEMA ${id},
		RESULT_CAST_CHARACTER_SET_NAME ${id},
		RESULT_CAST_COLLATION_CATALOG ${id},
		RESULT_CAST_COLLATION_SCHEMA ${id},
		RESULT_CAST_COLLATION_NAME ${id},
		RESULT_CAST_NUMERIC_PRECISION ${cn},
		RESULT_CAST_NUMERIC_RADIX ${cn},
		RESULT_CAST_NUMERIC_SCALE ${cn},
		RESULT_CAST_DATETIME_PRECISION ${cn},
		RESULT_CAST_INTERVAL_TYPE ${cd},
		RESULT_CAST_INTERVAL_PRECISION ${cn},
		RESULT_CAST_TYPE_UDT_CATALOG ${id},
		RESULT_CAST_TYPE_UDT_SCHEMA ${id},
		RESULT_CAST_TYPE_UDT_NAME ${id},
		RESULT_CAST_SCOPE_CATALOG ${id},
		RESULT_CAST_SCOPE_SCHEMA ${id},
		RESULT_CAST_SCOPE_NAME ${id},
		RESULT_CAST_MAX_CARDINALITY ${cn},
		RESULT_CAST_DTD_IDENTIFIER ${id}
	)',
		fn [c] (mut t VirtualTable) ! {
			for routine in t.conn.vsql_routines() {
				t.next_values(routines_view_row(c.catalog_name, routine))
			}
			t.done()
		})!
}

fn routines_view_row(catalog_name string, routine VsqlRoutine) []Value {
	f := routine.func
	// A function that's registered with register_function is called on a NULL
	// argument, unlike a built-in function, and isn't flagged, unlike a
	// PostgreSQL function (see is_vsql_routine).
	is_registered := f.called_on_null_input && f.features.len == 0
	null_varchar := new_null_value(.is_varchar)
	null_integer := new_null_value(.is_integer)
	mut row := [
		new_varchar_value(catalog_name), // SPECIFIC_CATALOG
		new_varchar_value(vsql_schema_name), // SPECIFIC_SCHEMA
		new_varchar_value(routine.specific_name), // SPECIFIC_NAME
		new_varchar_value(catalog_name), // ROUTINE_CATALOG
		new_varchar_value(vsql_schema_name), // ROUTINE_SCHEMA
		new_varchar_value(f.name), // ROUTINE_NAME
		new_varchar_value('FUNCTION'), // ROUTINE_TYPE
		null_varchar, // MODULE_CATALOG
		null_varchar, // MODULE_SCHEMA
		null_varchar, // MODULE_NAME
		null_varchar, // UDT_CATALOG
		null_varchar, // UDT_SCHEMA
		null_varchar, // UDT_NAME
	]
	row << routine_data_type(catalog_name, f.return_type)
	row << [
		null_varchar, // TYPE_UDT_CATALOG
		null_varchar, // TYPE_UDT_SCHEMA
		null_varchar, // TYPE_UDT_NAME
		null_varchar, // SCOPE_CATALOG
		null_varchar, // SCOPE_SCHEMA
		null_varchar, // SCOPE_NAME
		null_integer, // MAXIMUM_CARDINALITY
		new_varchar_value('0'), // DTD_IDENTIFIER
		new_varchar_value('EXTERNAL'), // ROUTINE_BODY
		null_varchar, // ROUTINE_DEFINITION
		new_varchar_value(f.name), // EXTERNAL_NAME
		new_varchar_value('C'), // EXTERNAL_LANGUAGE
		new_varchar_value('GENERAL'), // PARAMETER_STYLE
		yes_or_no(f.is_deterministic), // IS_DETERMINISTIC
		new_varchar_value(if is_registered { 'MODIFIES SQL DATA' } else { 'NO SQL' }), // SQL_DATA_ACCESS
		yes_or_no(!f.called_on_null_input), // IS_NULL_CALL
		null_varchar, // SQL_PATH
		yes_or_no(true), // SCHEMA_LEVEL_ROUTINE
		new_integer_value(0), // MAX_DYNAMIC_RESULT_SETS
		yes_or_no(false), // IS_USER_DEFINED_CAST
		null_varchar, // IS_IMPLICITLY_INVOCABLE
		new_varchar_value('IMPLEMENTATION DEFINED'), // SECURITY_TYPE
		null_varchar, // TO_SQL_SPECIFIC_CATALOG
		null_varchar, // TO_SQL_SPECIFIC_SCHEMA
		null_varchar, // TO_SQL_SPECIFIC_NAME
		yes_or_no(false), // AS_LOCATOR
		new_null_value(.is_timestamp_with_time_zone), // CREATED
		new_null_value(.is_timestamp_with_time_zone), // LAST_ALTERED
		null_varchar, // NEW_SAVEPOINT_LEVEL
		yes_or_no(false), // IS_UDT_DEPENDENT
	]
	// RESULT_CAST_FROM_DATA_TYPE to RESULT_CAST_DTD_IDENTIFIER.
	for column in routines_result_cast_columns {
		row << if column.ends_with('LENGTH') || column.ends_with('PRECISION')
			|| column.ends_with('RADIX') || column.ends_with('SCALE')
			|| column.ends_with('CARDINALITY') {
			null_integer
		} else {
			null_varchar
		}
	}

	return row
}

const routines_result_cast_columns = ['RESULT_CAST_FROM_DATA_TYPE', 'RESULT_CAST_AS_LOCATOR',
	'RESULT_CAST_CHAR_MAX_LENGTH', 'RESULT_CAST_CHAR_OCTET_LENGTH', 'RESULT_CAST_CHAR_SET_CATALOG',
	'RESULT_CAST_CHAR_SET_SCHEMA', 'RESULT_CAST_CHARACTER_SET_NAME', 'RESULT_CAST_COLLATION_CATALOG',
	'RESULT_CAST_COLLATION_SCHEMA', 'RESULT_CAST_COLLATION_NAME', 'RESULT_CAST_NUMERIC_PRECISION',
	'RESULT_CAST_NUMERIC_RADIX', 'RESULT_CAST_NUMERIC_SCALE', 'RESULT_CAST_DATETIME_PRECISION',
	'RESULT_CAST_INTERVAL_TYPE', 'RESULT_CAST_INTERVAL_PRECISION', 'RESULT_CAST_TYPE_UDT_CATALOG',
	'RESULT_CAST_TYPE_UDT_SCHEMA', 'RESULT_CAST_TYPE_UDT_NAME', 'RESULT_CAST_SCOPE_CATALOG',
	'RESULT_CAST_SCOPE_SCHEMA', 'RESULT_CAST_SCOPE_NAME', 'RESULT_CAST_MAX_CARDINALITY',
	'RESULT_CAST_DTD_IDENTIFIER']

// routine_data_type is the values of the ROUTINES and PARAMETERS views, from
// DATA_TYPE to INTERVAL_PRECISION, that describe the data type of a result or a
// parameter. They're the same as the COLUMNS view (see data_type_descriptor),
// in a different order. A character string parameter or result can have any
// length, so its maximum length is the longest character string.
fn routine_data_type(catalog_name string, t Type) []Value {
	mut typ := t
	if typ.typ.is_string() && typ.size == 0 {
		typ = Type{
			...typ
			size: max_character_length
		}
	}
	d := data_type_descriptor(catalog_name, typ)
	// DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH, then the
	// character set and collation, then NUMERIC_PRECISION to INTERVAL_PRECISION.
	return [d[0], d[1], d[2], d[9], d[10], d[11], d[12], d[13], d[14], d[3], d[4], d[5], d[6],
		d[7], d[8]]
}

// ISO/IEC 9075-11:2006, 5.35, PARAMETERS view
//
// The PARAMETERS view has a row for each parameter of each routine in the
// ROUTINES view, ordered the same way, then by the ordinal position of the
// parameter (Description, 2 of ISO/IEC 9075-11:2006, 6.31, PARAMETERS base
// table). Every parameter is an IN parameter (Description, 4) without a name
// (Description, 7.b), and isn't a RESULT parameter or passed AS LOCATOR
// (Description, 5 and 6). There are no transforms, so the from-sql and to-sql
// routines are NULL (Description, 8 and 9).
//
// The DTD_IDENTIFIER is the ordinal position of the parameter, since the
// result is 0 (see ROUTINES).
fn (mut catalog CatalogConnection) register_parameters_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	cd := information_schema_character_data
	cn := information_schema_cardinal_number
	yn := information_schema_yes_or_no
	catalog.add_information_schema_table('CREATE TABLE PARAMETERS (
		SPECIFIC_CATALOG ${id} NOT NULL,
		SPECIFIC_SCHEMA ${id} NOT NULL,
		SPECIFIC_NAME ${id} NOT NULL,
		ORDINAL_POSITION ${cn} NOT NULL,
		PARAMETER_MODE ${cd},
		IS_RESULT ${yn},
		AS_LOCATOR ${yn},
		PARAMETER_NAME ${id},
		FROM_SQL_SPECIFIC_CATALOG ${id},
		FROM_SQL_SPECIFIC_SCHEMA ${id},
		FROM_SQL_SPECIFIC_NAME ${id},
		TO_SQL_SPECIFIC_CATALOG ${id},
		TO_SQL_SPECIFIC_SCHEMA ${id},
		TO_SQL_SPECIFIC_NAME ${id},
		DATA_TYPE ${cd},
		CHARACTER_MAXIMUM_LENGTH ${cn},
		CHARACTER_OCTET_LENGTH ${cn},
		CHARACTER_SET_CATALOG ${id},
		CHARACTER_SET_SCHEMA ${id},
		CHARACTER_SET_NAME ${id},
		COLLATION_CATALOG ${id},
		COLLATION_SCHEMA ${id},
		COLLATION_NAME ${id},
		NUMERIC_PRECISION ${cn},
		NUMERIC_PRECISION_RADIX ${cn},
		NUMERIC_SCALE ${cn},
		DATETIME_PRECISION ${cn},
		INTERVAL_TYPE ${cd},
		INTERVAL_PRECISION ${cn},
		UDT_CATALOG ${id},
		UDT_SCHEMA ${id},
		UDT_NAME ${id},
		SCOPE_CATALOG ${id},
		SCOPE_SCHEMA ${id},
		SCOPE_NAME ${id},
		MAXIMUM_CARDINALITY ${cn},
		DTD_IDENTIFIER ${id}
	)',
		fn [c] (mut t VirtualTable) ! {
			null_varchar := new_null_value(.is_varchar)
			for routine in t.conn.vsql_routines() {
				for i, arg_type in routine.func.arg_types {
					mut row := [
						new_varchar_value(c.catalog_name), // SPECIFIC_CATALOG
						new_varchar_value(vsql_schema_name), // SPECIFIC_SCHEMA
						new_varchar_value(routine.specific_name), // SPECIFIC_NAME
						new_integer_value(i + 1), // ORDINAL_POSITION
						new_varchar_value('IN'), // PARAMETER_MODE
						yes_or_no(false), // IS_RESULT
						yes_or_no(false), // AS_LOCATOR
						null_varchar, // PARAMETER_NAME
						null_varchar, // FROM_SQL_SPECIFIC_CATALOG
						null_varchar, // FROM_SQL_SPECIFIC_SCHEMA
						null_varchar, // FROM_SQL_SPECIFIC_NAME
						null_varchar, // TO_SQL_SPECIFIC_CATALOG
						null_varchar, // TO_SQL_SPECIFIC_SCHEMA
						null_varchar, // TO_SQL_SPECIFIC_NAME
					]
					row << routine_data_type(c.catalog_name, arg_type)
					row << [
						null_varchar, // UDT_CATALOG
						null_varchar, // UDT_SCHEMA
						null_varchar, // UDT_NAME
						null_varchar, // SCOPE_CATALOG
						null_varchar, // SCOPE_SCHEMA
						null_varchar, // SCOPE_NAME
						new_null_value(.is_integer), // MAXIMUM_CARDINALITY
						new_varchar_value('${i + 1}'), // DTD_IDENTIFIER
					]
					t.next_values(row)
				}
			}
			t.done()
		})!
}
