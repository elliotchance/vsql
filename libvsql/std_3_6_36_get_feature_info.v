module main

// ISO/IEC 9075-3:2003(E), 6.36, GetFeatureInfo
//
// Get information about features supported by the CLI implementation.
//
// vsql doesn't have the SQL_FEATURES view of the INFORMATION_SCHEMA, so the
// features (and subfeatures) and whether they're supported are read from the
// tables in docs/sql-compliance.rst, which is embedded when libvsql is built.
// A feature that's in more than one table (for different parts of the
// standard) is only supported if it's supported in all of them. There are no
// packages.

const compliance_rst = $embed_file('../docs/sql-compliance.rst').to_string()

// supported_features is whether each feature ("E011") and subfeature ("E011-01") is
// supported.
const supported_features = parse_sql_features(compliance_rst)

fn parse_sql_features(rst string) map[string]bool {
	mut features := map[string]bool{}
	for line in rst.split_into_lines() {
		trimmed := line.trim_space()
		if !trimmed.starts_with('* - ') {
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
		features[id] = fields[0] == '✅' && features[id] or { true }
	}

	return features
}

@[export: 'SQLGetFeatureInfo']
fn sql_get_feature_info(connection_handle SQLInteger, feature_type &char, feature_type_length i16, feature_id &char, feature_id_length i16, sub_feature_id &char, sub_feature_id_length i16, supported &i16) i16 {
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	return get_feature_info(mut dbc, feature_type, feature_type_length, feature_id,
		feature_id_length, sub_feature_id, sub_feature_id_length, supported) or {
		dbc.diag.error(err)
	}
}

fn get_feature_info(mut dbc Dbc, feature_type &char, feature_type_length i16, feature_id &char, feature_id_length i16, sub_feature_id &char, sub_feature_id_length i16, supported &i16) !i16 {
	// - 2. If there is no established SQL-connection associated with C, then an
	// exception condition is raised: connection exception — connection does
	// not exist.
	if dbc.conn == none {
		return cli_error('08003', 'connection does not exist')
	}

	// - 3. If EC is not the current SQL-connection, then the General Rules of
	// Subclause 5.3, "Implicit set connection", are applied to EC as the
	// dormant SQL-connection.
	implicit_set_connection(dbc.handle)!

	// - 4 to 11. The arguments, which can't be zero-length strings.
	ft := feature_info_arg(feature_type, feature_type_length)!
	if ft !in ['FEATURE', 'SUBFEATURE', 'PACKAGE'] {
		return cli_error('HY024', 'invalid attribute value')
	}
	fi := feature_info_arg(feature_id, feature_id_length)!
	id := if ft == 'SUBFEATURE' {
		'${fi}-${feature_info_arg(sub_feature_id, sub_feature_id_length)!}'
	} else {
		fi
	}

	// - 12. If there is no such feature, then an exception condition is
	// raised: CLI-specific condition — invalid attribute value.
	if ft == 'PACKAGE' || id !in supported_features {
		return cli_error('HY024', 'invalid attribute value')
	}
	is_supported := supported_features[id] or { false }

	if supported == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 17. If the value of IS is 'YES', then Supported is set to 1 (one);
	// otherwise, Supported is set to 0 (zero).
	unsafe {
		*supported = if is_supported { 1 } else { 0 }
	}

	return sql_success
}

// feature_info_arg is a trimmed string argument, which can't be a zero-length
// string: CLI-specific condition — invalid string length or buffer length.
fn feature_info_arg(s &char, length i16) !string {
	if s == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}
	if length < 0 && length != sql_nts {
		return cli_error('HY090', 'invalid string length or buffer length')
	}
	v := input_string(s, i64(length))!.trim(' ')
	if v == '' {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	return v
}
