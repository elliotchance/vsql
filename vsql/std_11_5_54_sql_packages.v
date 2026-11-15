module vsql

// ISO/IEC 9075-11:2008(E), 5.54, SQL_PACKAGES view
//
// The SQL_PACKAGES view lists the packages of the standard, and whether vsql
// supports them. It's the PACKAGE rows of the SQL_CONFORMANCE base table
// (ISO/IEC 9075-11:2008(E), 6.43), which only exists as this view, SQL_FEATURES
// and SQL_PARTS.
//
// The packages are the ones of SQL:2003 (Part 1, Subclause 8.4, Conformance to
// SQL packages, Table 3), with their features (8.4.1 to 8.4.7). SQL:2023 has
// no packages (#1505), but this view is still in Part 11. A package is Core
// SQL and its features, so it's only supported when Core SQL is (see
// is_core_sql_supported) and each of its features is supported in the
// compliance tables (see SQL_FEATURES). A feature that isn't in them (such as
// the features of Part 4, SQL/PSM) isn't supported. The COMMENTS has how many of
// its features are supported.

// SqlPackage is a package of the standard, which is a row of
// INFORMATION_SCHEMA.SQL_PACKAGES.
struct SqlPackage {
	id       string
	name     string
	features []string
}

// The features of "Enhanced object support" are all of the features of "Basic
// object support", and some more (8.4.5).
const sql_packages = [
	SqlPackage{
		id:       'PKG001'
		name:     'Enhanced datetime facilities'
		features: ['F052', 'F411', 'F555']
	},
	SqlPackage{
		id:       'PKG002'
		name:     'Enhanced integrity management'
		features: ['F191', 'F521', 'F701', 'F491', 'F671', 'T201', 'T211', 'T212', 'T191']
	},
	SqlPackage{
		id:       'PKG004'
		name:     'PSM'
		features: ['T322', 'P001', 'P002', 'P003']
	},
	SqlPackage{
		id:       'PKG006'
		name:     'Basic object support'
		features: ['S023', 'S041', 'S051', 'S151', 'T041']
	},
	SqlPackage{
		id:       'PKG007'
		name:     'Enhanced object support'
		features: ['S023', 'S041', 'S051', 'S151', 'T041', 'S024', 'S043', 'S071', 'S081', 'S111',
			'S161', 'S211', 'S231', 'S241']
	},
	SqlPackage{
		id:       'PKG008'
		name:     'Active database'
		features: ['T211']
	},
	SqlPackage{
		id:       'PKG010'
		name:     'OLAP'
		features: ['T431', 'T611']
	},
]

// sql_packages_view_rows are the rows of the SQL_PACKAGES view. Nothing is
// verified by a conformance test, so IS_VERIFIED_BY is NULL.
//
// ISO/IEC 9075-11:2008(E), 6.43, SQL_CONFORMANCE base table, Description, 1-8
fn sql_packages_view_rows(features []SqlFeature) [][]Value {
	mut supported := map[string]bool{}
	for feature in features {
		supported[feature.id] = feature.is_supported
	}

	is_core_sql := is_core_sql_supported()
	mut rows := [][]Value{}
	for package in sql_packages {
		count := package.features.filter(supported[it] or { false }).len
		rows << [
			new_varchar_value(package.id), // ID
			new_varchar_value(package.name), // NAME
			yes_or_no(is_core_sql && count == package.features.len), // IS_SUPPORTED
			new_null_value(.is_varchar), // IS_VERIFIED_BY
			new_varchar_value('${count} of the ${package.features.len} features are supported.'), // COMMENTS
		]
	}

	return rows
}
