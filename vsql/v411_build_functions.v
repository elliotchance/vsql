module vsql

// The functions that return how vsql was built (V411-01 to V411-06). They have
// the same names as the build functions in V (see version.v), and return the
// same values as the BUILD items of SQL_IMPLEMENTATION_INFO, so the version and
// commit are NULL when vsql wasn't built for a release.
//
// A value is fixed for the build, but it changes when vsql is upgraded, so
// they're NOT DETERMINISTIC and can't be in a CHECK constraint or a generated
// column.

fn register_build_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}

	conn.register_func(Func{'BUILD_VERSION', [], false, func_build_version, varchar, false, false, [
		vsql_build_version,
	], [], false})!
	conn.register_func(Func{'BUILD_COMMIT', [], false, func_build_commit, varchar, false, false, [
		vsql_build_commit,
	], [], false})!
	conn.register_func(Func{'BUILD_DATE', [], false, func_build_date, varchar, false, false, [
		vsql_build_date,
	], [], false})!
	conn.register_func(Func{'BUILD_V_VERSION', [], false, func_build_v_version, varchar, false, false, [
		vsql_build_v_version,
	], [], false})!
	conn.register_func(Func{'BUILD_V_COMMIT', [], false, func_build_v_commit, varchar, false, false, [
		vsql_build_v_commit,
	], [], false})!
	conn.register_func(Func{'BUILD_C_COMPILER', [], false, func_build_c_compiler, varchar, false, false, [
		vsql_build_c_compiler,
	], [], false})!
}

// build_value is s as a CHARACTER VARYING, or NULL when it's empty (see
// release_info).
fn build_value(s string) Value {
	if s == '' {
		return new_null_value(.is_varchar)
	}

	return new_varchar_value(s)
}

// BUILD_VERSION() CHARACTER VARYING
fn func_build_version(_ FunctionContext, _ []Value) !Value {
	return build_value(build_version())
}

// BUILD_COMMIT() CHARACTER VARYING
fn func_build_commit(_ FunctionContext, _ []Value) !Value {
	return build_value(build_commit())
}

// BUILD_DATE() CHARACTER VARYING
fn func_build_date(_ FunctionContext, _ []Value) !Value {
	return build_value(build_date())
}

// BUILD_V_VERSION() CHARACTER VARYING
fn func_build_v_version(_ FunctionContext, _ []Value) !Value {
	return build_value(build_v_version())
}

// BUILD_V_COMMIT() CHARACTER VARYING
fn func_build_v_commit(_ FunctionContext, _ []Value) !Value {
	return build_value(build_v_commit())
}

// BUILD_C_COMPILER() CHARACTER VARYING
fn func_build_c_compiler(_ FunctionContext, _ []Value) !Value {
	return build_value(build_c_compiler())
}
