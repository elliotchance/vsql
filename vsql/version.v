module vsql

import v.util.version as v_util_version

// The build functions are the BUILD items of SQL_IMPLEMENTATION_INFO, and the
// VSQL_BUILD variables of "vsql version -v", with the same names.

// git_version and git_commit are the version (from "git describe", such as
// "v1.8.5-12-g1a2b3c4") and commit of a build from a git checkout, which the
// Makefile passes to V with -d. They're empty for any other build.
const git_version = $d('vsql_build_version', '')
const git_commit = $d('vsql_build_commit', '')

// build_version returns the version of vsql, such as "v0.34.0" for a release.
// A build from a git checkout (with make) has the version from "git describe",
// such as "v1.8.5-12-g1a2b3c4" (12 commits after v1.8.5), with "-dirty" when it
// has changes that aren't committed. It's an empty string for any other build.
pub fn build_version() string {
	// This value is replaced for a release, see set_version.sh.
	return release_value('MISSING_VERSION', git_version)
}

// build_commit returns the git commit of vsql that was released or built from
// (such as "6b3d76f0a1..."), or an empty string if it wasn't built for a
// release or from a git checkout.
pub fn build_commit() string {
	// This value is replaced for a release, see set_version.sh.
	return release_value('MISSING_COMMIT', git_commit)
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

// release_value returns s, or otherwise if set_version.sh didn't replace it.
fn release_value(s string, otherwise string) string {
	if s.contains('MISSING') {
		return otherwise
	}

	return s
}
