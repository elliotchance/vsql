module vsql

// version returns the version of vsql (such as "v0.34.0"), or an empty string
// if it wasn't built for a release.
pub fn version() string {
	// This value is replaced for a release, see set_version.sh. Be careful not
	// to use it again in this file, since every copy of it would be replaced.
	v := 'MISSING_VERSION'
	if v.contains('MISSING') {
		return ''
	}

	return v
}

// version_date returns the date that vsql was released (such as
// "2026-10-28"), or an empty string if it wasn't built for a release.
pub fn version_date() string {
	// This value is replaced for a release, see set_version.sh.
	d := 'MISSING_DATE'
	if d.contains('MISSING') {
		return ''
	}

	return d
}
