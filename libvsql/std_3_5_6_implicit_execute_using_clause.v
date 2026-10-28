module main

import vsql

// ISO/IEC 9075-3:2003(E), 5.6, Implicit EXECUTE USING and OPEN USING clauses
//
// The values of the dynamic parameters ("?") of a statement come from the APD,
// which is the C value of each parameter, and the IPD, which is its SQL data
// type. The C value is cast to the SQL data type.

// Codes from Table 10, "Codes associated with <parameter mode> in SQL/CLI".
const sql_param_mode_in = i16(1)
const sql_param_mode_inout = i16(2)
const sql_param_mode_out = i16(4)

// Codes from Table 26, "Miscellaneous codes used in CLI".
const sql_data_at_exec = -2

// parameter_values returns the value of each dynamic parameter of a statement
// (named "?1", "?2", etc.), and the numbers of the deferred parameters (that
// have a length of DATA AT EXEC) that don't have a value yet.
fn parameter_values(mut stmt Stmt, prepared vsql.PreparedStmt) !(map[string]vsql.Value, []int) {
	apd := descs[stmt.apd] or { return cli_error('HY010', 'function sequence error') }
	ipd := descs[stmt.ipd] or { return cli_error('HY010', 'function sequence error') }
	d := prepared.dynamic_parameter_count()

	// - 4.c. If NIPD is less than D, then an exception condition is raised:
	// dynamic SQL error — using clause does not match dynamic parameter
	// specifications.
	if ipd.count() < d || apd.count() < d {
		return using_clause_error()
	}

	mut params := map[string]vsql.Value{}
	mut deferred := []int{}
	for i in 1 .. d + 1 {
		// - 4.e. Each item descriptor area of the IPD must be valid. A
		// parameter with a mode of OUT can't be used, since there are no
		// output parameters.
		if !ipd.is_consistent(ipd.records[i - 1])
			|| ipd.record_int(i, sql_desc_parameter_mode) == sql_param_mode_out {
			return using_clause_error()
		}
		tdt := ipd_type(ipd, i)

		// - 4.g, 4.h. A TYPE of DEFAULT in the APD is the type from the IPD, and
		// it must have a C type.
		typ := application_type(apd, ipd, i) or { return using_clause_error() }

		// - 4.j. NULL and DEFERRED.
		indicator := voidptr(apd.record_int(i, sql_desc_indicator_pointer))
		length := voidptr(apd.record_int(i, sql_desc_octet_length_pointer))
		if indicator != unsafe { nil } && unsafe { *&SQLInteger(indicator) } == sql_null_data {
			params['?${i}'] = vsql.new_null_value(tdt.typ)
			continue
		}
		if length != unsafe { nil } && unsafe { *&SQLInteger(length) } == sql_data_at_exec {
			deferred << i
			continue
		}

		// - 4.m. Otherwise, the value is the host variable addressed by
		// DATA_POINTER (5.13, Syntax Rule 12.d says it can't be zero).
		data := voidptr(apd.record_int(i, sql_desc_data_pointer))
		if data == unsafe { nil } {
			return using_clause_error()
		}
		sv := read_c_value(typ, data, if length == unsafe { nil } {
			sql_nts
		} else {
			unsafe { *&SQLInteger(length) }
		})!

		// - 4.p. The value of the parameter is CAST ( SV AS TDT ).
		params['?${i}'] = cast_parameter(stmt, sv, tdt)!
	}

	return params, deferred
}

fn using_clause_error() IError {
	return cli_error('07001', 'using clause does not match dynamic parameter specifications')
}

// application_type is the C type of the i-th item descriptor area of an APD,
// where DEFAULT is the type of the IPD.
fn application_type(apd &Desc, ipd &Desc, i int) ?vsql.SQLType {
	mut code := apd.record_int(i, sql_desc_type)
	if code == sql_default {
		code = ipd.record_int(i, sql_desc_type)
	}

	return c_type(i16(code))
}

// ipd_type is the SQL data type of the i-th item descriptor area of an IPD.
fn ipd_type(ipd &Desc, i int) vsql.Type {
	length := int(ipd.record_int(i, sql_desc_length))
	precision := int(ipd.record_int(i, sql_desc_precision))
	scale := i16(ipd.record_int(i, sql_desc_scale))

	return match ipd.record_int(i, sql_desc_type) {
		sql_char {
			vsql.Type{
				typ:  .is_character
				size: length
			}
		}
		sql_varchar {
			vsql.Type{
				typ:  .is_varchar
				size: length
			}
		}
		sql_numeric, sql_decimal {
			vsql.Type{
				typ:   if ipd.record_int(i, sql_desc_type) == sql_numeric {
					.is_numeric
				} else {
					.is_decimal
				}
				size:  precision
				scale: scale
			}
		}
		sql_smallint {
			vsql.Type{
				typ: .is_smallint
			}
		}
		sql_integer {
			vsql.Type{
				typ: .is_integer
			}
		}
		sql_bigint {
			vsql.Type{
				typ: .is_bigint
			}
		}
		sql_real {
			vsql.Type{
				typ: .is_real
			}
		}
		sql_boolean {
			vsql.Type{
				typ: .is_boolean
			}
		}
		sql_datetime {
			vsql.Type{
				typ:  match ipd.record_int(i, sql_desc_datetime_interval_code) {
					sql_code_date { .is_date }
					sql_code_time { .is_time_without_time_zone }
					sql_code_time_zone { .is_time_with_time_zone }
					sql_code_timestamp_zone { .is_timestamp_with_time_zone }
					else { .is_timestamp_without_time_zone }
				}
				size: precision
			}
		}
		else {
			// FLOAT and DOUBLE PRECISION.
			vsql.Type{
				typ: .is_double_precision
			}
		}
	}
}

// read_c_value is the value of a host variable of a C type. A string has a
// length in octets, or SQL_NTS.
fn read_c_value(typ vsql.SQLType, data voidptr, length i64) !vsql.Value {
	return unsafe {
		match typ {
			.is_smallint {
				vsql.new_smallint_value(*&i16(data))
			}
			.is_integer {
				vsql.new_bigint_value(i64(*&SQLInteger(data)))
			}
			.is_bigint {
				vsql.new_bigint_value(*&i64(data))
			}
			.is_real {
				vsql.new_real_value(*&f32(data))
			}
			.is_double_precision {
				vsql.new_double_precision_value(*&f64(data))
			}
			else {
				vsql.new_varchar_value(input_string(&char(data), length)!)
			}
		}
	}
}

// cast_parameter is CAST ( SV AS TDT ). A number can't be cast to a datetime
// or BOOLEAN: dynamic SQL error — restricted data type attribute violation.
fn cast_parameter(stmt &Stmt, sv vsql.Value, tdt vsql.Type) !vsql.Value {
	if !sv.is_null && sv.typ.typ != .is_varchar
		&& tdt.typ in [.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
			.is_timestamp_without_time_zone, .is_timestamp_with_time_zone, .is_boolean] {
		return cli_error('07006', 'restricted data type attribute violation')
	}
	mut conn := stmt_connection(stmt)!

	return conn.cast(sv, tdt)!
}
