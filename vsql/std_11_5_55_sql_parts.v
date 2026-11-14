module vsql

// ISO/IEC 9075-11:2006(E), 5.55, SQL_PARTS view
//
// The SQL_PARTS view lists the parts of the standard, and whether vsql supports
// them. It's the PART rows of the SQL_CONFORMANCE base table (ISO/IEC
// 9075-11:2006(E), 6.43), which only exists as this view, SQL_FEATURES and
// SQL_PACKAGES.
//
// The parts are the ones in ISO/IEC 9075-1:2023(E), 5.2 to 5.10, with their
// names, without the parts that SQL:2023 added in 5.11 and 5.12 (#1505). Supporting a part means supporting all of its mandatory features
// (ISO/IEC 9075-1:2023(E), 9.3, Conformance to parts), so a part that has a
// docs/sql-compliance-9075-*.rst page is supported when the page says that all
// of its mandatory features are, and the COMMENTS has the count from that
// sentence. A part without a page isn't supported, and has no comments.

// SqlPart is a part of the standard, which is a row of
// INFORMATION_SCHEMA.SQL_PARTS.
struct SqlPart {
	id   string
	name string
	// rst is the docs/sql-compliance-9075-*.rst page of the part, or empty if
	// it doesn't have one.
	rst string
}

const sql_parts = [
	SqlPart{'1', 'Framework (SQL/Framework)', ''},
	SqlPart{'2', 'Foundation (SQL/Foundation)', $embed_file('../docs/sql-compliance-9075-2.rst').to_string()},
	SqlPart{'3', 'Call Level Interface (SQL/CLI)', $embed_file('../docs/sql-compliance-9075-3.rst').to_string()},
	SqlPart{'4', 'Persistent Stored Modules (SQL/PSM)', ''},
	SqlPart{'9', 'Management of External Data (SQL/MED)', ''},
	SqlPart{'10', 'Object Language Bindings (SQL/OLB)', ''},
	SqlPart{'11', 'Information and Definition Schemas (SQL/Schemata)', $embed_file('../docs/sql-compliance-9075-11.rst').to_string()},
	SqlPart{'13', 'Java Routines and Types Using the Java Programming Language (SQL/JRT)', ''},
	SqlPart{'14', 'XML-Related Specifications (SQL/XML)', ''},
]

// mandatory_features_supported returns the number of mandatory features that a
// compliance page says are supported, and how many there are, from its
// "vsql supports N of the M mandatory features" sentence, or 0 and 0 if it
// doesn't have one.
fn mandatory_features_supported(rst string) (int, int) {
	// It's the first sentence like this on the page.
	words := rst.all_after('**vsql supports ').fields()

	return (words[0] or { '' }).int(), (words[3] or { '' }).int()
}

// all_mandatory_features_supported is true if a compliance page says that all
// of its mandatory features are supported.
fn all_mandatory_features_supported(rst string) bool {
	supported, total := mandatory_features_supported(rst)

	return supported == total
}

// is_core_sql_supported is true if all of the mandatory features of Part 2 and
// Part 11 are supported, which are Core SQL (ISO/IEC 9075-1:2023(E), 9.2,
// Minimum conformance).
fn is_core_sql_supported() bool {
	return sql_parts.filter(it.id in ['2', '11']).all(all_mandatory_features_supported(it.rst))
}

// sql_parts_view_row is a row of the SQL_PARTS view. Nothing is verified by a
// conformance test, so IS_VERIFIED_BY is NULL.
//
// ISO/IEC 9075-11:2006(E), 6.43, SQL_CONFORMANCE base table, Description, 1-8
fn sql_parts_view_row(part SqlPart) []Value {
	mut is_supported := false
	mut comments := new_null_value(.is_varchar)
	if part.rst != '' {
		supported, total := mandatory_features_supported(part.rst)
		is_supported = all_mandatory_features_supported(part.rst)
		comments = new_varchar_value('${supported} of the ${total} mandatory features are supported.')
	}

	return [
		new_varchar_value(part.id), // PART
		new_varchar_value(part.name), // NAME
		yes_or_no(is_supported), // IS_SUPPORTED
		new_null_value(.is_varchar), // IS_VERIFIED_BY
		comments, // COMMENTS
	]
}
