module vsql

// ISO/IEC 9075-11:2006(E), 5.52, SQL_FEATURES view
//
// The SQL_FEATURES view lists the features and subfeatures of the standard, and
// whether vsql supports them. It's the FEATURE and SUBFEATURE rows of the
// SQL_CONFORMANCE base table (ISO/IEC 9075-11:2006(E), 6.43), which only exists
// as this view.
//
// There's one source of truth: the rows are read from the tables in the
// docs/sql-compliance-9075-*.rst pages (one for each part of the standard),
// which are embedded when vsql is built. A ✅ is supported ('YES'), and a ⭕ or
// ❌ isn't ('NO'). A feature that's in more than one table (for different parts
// of the standard) is only supported if it's supported in all of them, and has
// the name from the first table. There are no packages or parts in the view.

const sql_compliance_rst = $embed_file('../docs/sql-compliance-9075-2.rst').to_string() +
	$embed_file('../docs/sql-compliance-9075-3.rst').to_string() +
	$embed_file('../docs/sql-compliance-9075-11.rst').to_string()

// SqlFeature is a feature ("E011") or subfeature ("E011-01") from the
// compliance tables.
struct SqlFeature {
	id           string
	name         string
	is_supported bool
}

// parse_sql_features returns the features and subfeatures of the compliance
// tables, ordered by their ID (so a feature is before its subfeatures). Each
// row of a table is a "* - " line with the status and ID, followed by a "- "
// line with the name.
fn parse_sql_features(rst string) []SqlFeature {
	mut names := map[string]string{}
	mut supported := map[string]bool{}
	lines := rst.split_into_lines()
	for i, line in lines {
		trimmed := line.trim_space()
		if !trimmed.starts_with('* - ') || i + 1 >= lines.len {
			continue
		}
		fields := trimmed[4..].split(' ')
		if fields.len < 2 || fields[0] !in ['✅', '⭕', '❌'] {
			continue
		}
		id := fields[1].trim('*')
		is_feature := id.len == 4 && id[0].is_letter() && id[1..].bytes().all(it.is_digit())
		is_subfeature := id.len == 7 && id[4] == `-` && id[0].is_letter()
		if !is_feature && !is_subfeature {
			continue
		}
		if id !in names {
			names[id] = lines[i + 1].trim_space().trim_string_left('- ').replace('**',
				'').replace('``', '')
		}
		supported[id] = fields[0] == '✅' && supported[id] or { true }
	}

	mut ids := names.keys()
	ids.sort()

	return ids.map(SqlFeature{
		id:           it
		name:         names[it]
		is_supported: supported[it]
	})
}

// sql_features_view_rows are the rows of the SQL_FEATURES view. A subfeature has
// the ID and name of its feature, and its own subfeature ID ("01") and name. A
// feature's SUB_FEATURE_ID and SUB_FEATURE_NAME are a single space. Nothing is
// verified by a conformance test, and there are no comments, so IS_VERIFIED_BY
// and COMMENTS are NULL.
//
// ISO/IEC 9075-11:2006(E), 6.43, SQL_CONFORMANCE base table, Description, 1-8
fn sql_features_view_rows(features []SqlFeature) [][]Value {
	mut feature_names := map[string]string{}
	mut rows := [][]Value{}
	for feature in features {
		mut feature_id := feature.id
		mut sub_feature_id := ' '
		mut sub_feature_name := ' '
		if feature.id.len == 4 {
			feature_names[feature.id] = feature.name
		} else {
			feature_id = feature.id[..4]
			sub_feature_id = feature.id[5..]
			sub_feature_name = feature.name
		}
		rows << [
			new_varchar_value(feature_id), // FEATURE_ID
			new_varchar_value(feature_names[feature_id] or { '' }), // FEATURE_NAME
			new_varchar_value(sub_feature_id), // SUB_FEATURE_ID
			new_varchar_value(sub_feature_name), // SUB_FEATURE_NAME
			yes_or_no(feature.is_supported), // IS_SUPPORTED
			new_null_value(.is_varchar), // IS_VERIFIED_BY
			new_null_value(.is_varchar), // COMMENTS
		]
	}

	return rows
}

// register_sql_features_view adds the SQL_FEATURES view to the
// INFORMATION_SCHEMA of a catalog.
fn (mut catalog CatalogConnection) register_sql_features_view() ! {
	cd := information_schema_character_data
	yn := information_schema_yes_or_no
	catalog.add_information_schema_table('CREATE TABLE SQL_FEATURES (
		FEATURE_ID ${cd},
		FEATURE_NAME ${cd} NOT NULL,
		SUB_FEATURE_ID ${cd},
		SUB_FEATURE_NAME ${cd},
		IS_SUPPORTED ${yn} NOT NULL,
		IS_VERIFIED_BY ${cd},
		COMMENTS ${cd}
	)',
		fn (mut t VirtualTable) ! {
			for row in sql_features_view_rows(parse_sql_features(sql_compliance_rst)) {
				t.next_values(row)
			}
			t.done()
		})!
}
