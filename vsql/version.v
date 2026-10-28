module vsql

// version returns the version of vsql (such as "v0.34.0"), or an empty string
// if it wasn't built for a release.
pub fn version() string {
	// This value is replaced for a release, see set_version.sh.
	return release_value('MISSING_VERSION')
}

// version_date returns the date that vsql was released (such as
// "2026-10-28"), or an empty string if it wasn't built for a release.
pub fn version_date() string {
	// This value is replaced for a release, see set_version.sh.
	return release_value('MISSING_DATE')
}

// release_value returns s, or an empty string if set_version.sh didn't replace
// it.
fn release_value(s string) string {
	if s.contains('MISSING') {
		return ''
	}

	return s
}
