module vsql

import os

// ISO/IEC 9075-11:2008(E), 6.44, SQL_IMPLEMENTATION_INFO base table
//
// There's one row for each SQL-implementation information item, with its value
// in either INTEGER_VALUE or CHARACTER_VALUE (the other one is NULL), and a
// comment of our own (Description, 1 to 4). The items, and what their values
// mean, are the ones that SQL/CLI defines:
//
//   ISO/IEC 9075-3:2003, 7.1, SQL_IMPLEMENTATION_INFO base table
//
// That list doesn't have SEARCH PATTERN ESCAPE (14), but GetInfo reads it from
// this table too, so it's here as well:
//
//   ISO/IEC 9075-3:2003, 6.38, GetInfo, General Rules, 10.b
//
// The implementation-defined items have IDs from 11000 (Description, 2 of
// 7.1). The ones with a name that starts with BUILD were set when vsql was
// compiled, and the others are read when they're used.
// SQLGetInfo (libvsql) reads the same rows, so the INFORMATION_SCHEMA and the
// CLI can't disagree.

// ImplementationInfo is an SQL-implementation information item, which is a row
// of INFORMATION_SCHEMA.SQL_IMPLEMENTATION_INFO.
pub struct ImplementationInfo {
pub:
	// id is the IMPLEMENTATION_INFO_ID, which is also the code of the
	// information type for SQLGetInfo. The column is a character string.
	id int
	// name is the IMPLEMENTATION_INFO_NAME, such as "DBMS NAME".
	name string
	// integer_value is the INTEGER_VALUE, or none if the value is a character
	// string.
	integer_value ?int
	// character_value is the CHARACTER_VALUE, or none if the value is an
	// integer.
	character_value ?string
	// comments is the COMMENTS, which explains the value.
	comments string
}

// sql_implementation_info returns the rows of
// INFORMATION_SCHEMA.SQL_IMPLEMENTATION_INFO, ordered by their ID.
// server_name is the name of the SQL-server that was connected to (the path of
// the database file, or ":memory:"), which is the DATA SOURCE NAME and SERVER
// NAME. The FILE READ VERSION and FILE WRITE VERSION are of the file of the
// catalog, which are NULL for ":memory:" (it has no file).
pub fn sql_implementation_info(server_name string, catalog &CatalogConnection) []ImplementationInfo {
	in_memory := catalog.path == ':memory:'
	return [
		ImplementationInfo{
			id:              2
			name:            'DATA SOURCE NAME'
			character_value: server_name
			comments:        'The name of the SQL-server that was connected to.'
		},
		ImplementationInfo{
			id:              13
			name:            'SERVER NAME'
			character_value: server_name
			comments:        'The name of the SQL-server that was connected to.'
		},
		ImplementationInfo{
			id:              14
			name:            'SEARCH PATTERN ESCAPE'
			character_value: '\\'
			comments:        'The escape character of the patterns of the catalog routines of SQL/CLI.'
		},
		ImplementationInfo{
			id:              17
			name:            'DBMS NAME'
			character_value: 'vsql'
			comments:        'The name of the software.'
		},
		ImplementationInfo{
			id:              18
			name:            'DBMS VERSION'
			character_value: dbms_version(build_version())
			comments:        'The version of the software, as NN.NN.NNNN (00.00.0000 when it was not built for a release).'
		},
		ImplementationInfo{
			id:            23
			name:          'CURSOR COMMIT BEHAVIOR'
			integer_value: 2
			comments:      '2: cursors stay open and prepared statements are kept.'
		},
		ImplementationInfo{
			id:            26
			name:          'DEFAULT TRANSACTION ISOLATION'
			integer_value: 4
			comments:      '4: SERIALIZABLE.'
		},
		ImplementationInfo{
			id:            28
			name:          'IDENTIFIER CASE'
			integer_value: 1
			comments:      '1: regular identifiers are stored in upper case.'
		},
		ImplementationInfo{
			id:            46
			name:          'TRANSACTION CAPABLE'
			integer_value: 2
			comments:      '2: a transaction can include both DML and DDL.'
		},
		ImplementationInfo{
			id:            85
			name:          'NULL COLLATION'
			integer_value: 1
			comments:      '1: NULLs sort before every other value.'
		},
		ImplementationInfo{
			id:              94
			name:            'SPECIAL CHARACTERS'
			character_value: ''
			comments:        'There are no other characters that can be used in a regular identifier.'
		},
		ImplementationInfo{
			id:              10003
			name:            'CATALOG NAME'
			character_value: 'Y'
			comments:        'Y: catalog names are supported.'
		},
		ImplementationInfo{
			id:              10004
			name:            'COLLATING SEQUENCE'
			character_value: ''
			comments:        'Collations are not supported.'
		},
		ImplementationInfo{
			id:              11000
			name:            'BUILD VERSION'
			character_value: release_info(build_version())
			comments:        'The release of vsql, such as v1.2.3 (NULL when it was not built for a release).'
		},
		ImplementationInfo{
			id:              11001
			name:            'BUILD COMMIT'
			character_value: release_info(build_commit())
			comments:        'The git commit of the release (NULL when it was not built for a release).'
		},
		ImplementationInfo{
			id:              11002
			name:            'BUILD DATE'
			character_value: build_date()
			comments:        'The date (in UTC) that vsql was compiled.'
		},
		ImplementationInfo{
			id:              11003
			name:            'BUILD V VERSION'
			character_value: build_v_version()
			comments:        'The version of the V compiler that compiled vsql.'
		},
		ImplementationInfo{
			id:              11004
			name:            'BUILD V COMMIT'
			character_value: build_v_commit()
			comments:        'The commit of the V compiler that compiled vsql.'
		},
		ImplementationInfo{
			id:              11005
			name:            'BUILD C COMPILER'
			character_value: build_c_compiler()
			comments:        'The C compiler that compiled vsql.'
		},
		ImplementationInfo{
			id:              11006
			name:            'OPERATING SYSTEM'
			character_value: os.user_os()
			comments:        'The operating system that vsql is running on.'
		},
		ImplementationInfo{
			id:              11007
			name:            'MACHINE'
			character_value: os.uname().machine
			comments:        'The hardware that vsql is running on.'
		},
		ImplementationInfo{
			id:            11008
			name:          'FILE READ VERSION'
			integer_value: if in_memory {
				?int(none)
			} else {
				int(catalog.storage.header.read_version)
			}
			comments:      'The oldest file format that can read the database file (NULL for :memory:).'
		},
		ImplementationInfo{
			id:            11009
			name:          'FILE WRITE VERSION'
			integer_value: if in_memory {
				?int(none)
			} else {
				int(catalog.storage.header.write_version)
			}
			comments:      'The oldest file format that can change the database file (NULL for :memory:).'
		},
	]
}

// implementation_info_view_row is a row of the SQL_IMPLEMENTATION_INFO view.
fn implementation_info_view_row(item ImplementationInfo) []Value {
	return [
		new_varchar_value(item.id.str()), // IMPLEMENTATION_INFO_ID
		new_varchar_value(item.name), // IMPLEMENTATION_INFO_NAME
		if v := item.integer_value {
			new_integer_value(v)
		} else {
			new_null_value(.is_integer)
		}, // INTEGER_VALUE
		if v := item.character_value {
			new_varchar_value(v)
		} else {
			new_null_value(.is_varchar)
		}, // CHARACTER_VALUE
		new_varchar_value(item.comments), // COMMENTS
	]
}

// dbms_version is the DBMS VERSION for a version (such as "v1.2.3"): two
// digits, a period, two digits, a period and four digits (ISO/IEC
// 9075-3:2003, 7.1, SQL_IMPLEMENTATION_INFO base table). It's "00.00.0000"
// when vsql wasn't built for a release (see set_version.sh). The release is
// also BUILD VERSION, so it isn't added on the end.
fn dbms_version(version string) string {
	if version == '' {
		return '00.00.0000'
	}
	parts := version.trim_left('v').split('.')
	major := (parts[0] or { '0' }).int()
	minor := (parts[1] or { '0' }).int()
	patch := (parts[2] or { '0' }).int()

	return '${major:02}.${minor:02}.${patch:04}'
}

// release_info is the value of an item that's only known for a release, which
// is NULL (none) for any other build.
fn release_info(s string) ?string {
	if s == '' {
		return none
	}

	return s
}
