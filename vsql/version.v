module vsql

import v.util.version as v_util_version

// The build functions are the BUILD items of SQL_IMPLEMENTATION_INFO, and the
// VSQL_BUILD variables of "vsql version -v", with the same names.

// build_version returns the version of vsql (such as "v0.34.0"), or an empty
// string if it wasn't built for a release.
pub fn build_version() string {
	// This value is replaced for a release, see set_version.sh.
	return release_value('MISSING_VERSION')
}

// build_commit returns the git commit of vsql that was released (such as
// "6b3d76f0a1..."), or an empty string if it wasn't built for a release.
pub fn build_commit() string {
	// This value is replaced for a release, see set_version.sh.
	return release_value('MISSING_COMMIT')
}

// build_date returns the date (in UTC) that vsql was compiled, such as
// "2026-11-12". Every build has one. For a release, it's the date of the
// release.
pub fn build_date() string {
	return @BUILD_DATE
}

// build_v_version returns the version of the V compiler that built vsql (such
// as "0.5.2").
pub fn build_v_version() string {
	return v_util_version.v_version
}

// build_v_commit returns the commit of the V compiler that built vsql (such as
// "5634a1f"), the same as "v version" shows.
pub fn build_v_commit() string {
	return @VCURRENTHASH
}

// build_c_compiler returns the C compiler that compiled vsql, such as "clang".
pub fn build_c_compiler() string {
	return @CCOMPILER
}

// release_value returns s, or an empty string if set_version.sh didn't replace
// it.
fn release_value(s string) string {
	if s.contains('MISSING') {
		return ''
	}

	return s
}
