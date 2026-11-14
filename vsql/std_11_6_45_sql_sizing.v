module vsql

// ISO/IEC 9075-11:2006(E), 6.45, SQL_SIZING base table
//
// There's one row for each sizing item, with the size that vsql supports: 0
// (zero) for no limit, or NULL if vsql doesn't support anything that the item
// applies to (Description, 1 to 4). The items are the ones that SQL/CLI
// defines, and there are no implementation-defined items:
//
//   ISO/IEC 9075-3:2003(E), 7.2, SQL_SIZING base table
//
// A name is an <identifier>, which can have up to max_identifier_length
// characters, and a table can have up to max_columns columns. SQLGetInfo
// (libvsql) reads the same rows, so the INFORMATION_SCHEMA and the CLI can't
// disagree. The rows are the same in every catalog.

// SizingItem is a sizing item, which is a row of INFORMATION_SCHEMA.SQL_SIZING.
pub struct SizingItem {
pub:
	// id is the SIZING_ID, which is also the code of the information type for
	// SQLGetInfo.
	id int
	// name is the SIZING_NAME, such as "MAXIMUM COLUMN NAME LENGTH".
	name string
	// supported_value is the SUPPORTED_VALUE: the maximum, 0 (zero) if there
	// isn't one, or none if it doesn't apply.
	supported_value ?int
	// comments is the COMMENTS, which explains the value.
	comments string
}

// sql_sizing returns the rows of INFORMATION_SCHEMA.SQL_SIZING, ordered by
// their ID.
pub fn sql_sizing() []SizingItem {
	name_length := 'Characters in a name.'
	no_limit := 'There is no limit.'

	return [
		SizingItem{0, 'MAXIMUM DRIVER CONNECTIONS', 0, no_limit},
		SizingItem{1, 'MAXIMUM CONCURRENT ACTIVITIES', 0, no_limit},
		SizingItem{30, 'MAXIMUM COLUMN NAME LENGTH', max_identifier_length, name_length},
		SizingItem{31, 'MAXIMUM CURSOR NAME LENGTH', max_identifier_length, name_length},
		SizingItem{32, 'MAXIMUM SCHEMA NAME LENGTH', max_identifier_length, name_length},
		SizingItem{34, 'MAXIMUM CATALOG NAME LENGTH', max_identifier_length, name_length},
		SizingItem{35, 'MAXIMUM TABLE NAME LENGTH', max_identifier_length, name_length},
		SizingItem{97, 'MAXIMUM COLUMNS IN GROUP BY', 0, no_limit},
		SizingItem{99, 'MAXIMUM COLUMNS IN ORDER BY', 0, no_limit},
		SizingItem{100, 'MAXIMUM COLUMNS IN SELECT', 0, no_limit},
		SizingItem{101, 'MAXIMUM COLUMNS IN TABLE', max_columns, 'Columns in a table.'},
		SizingItem{106, 'MAXIMUM TABLES IN SELECT', 0, no_limit},
		SizingItem{107, 'MAXIMUM USER NAME LENGTH', 0, no_limit},
		SizingItem{10005, 'MAXIMUM IDENTIFIER LENGTH', max_identifier_length, name_length},
		SizingItem{20000, 'MAXIMUM STATEMENT OCTETS', 0, no_limit},
		SizingItem{20001, 'MAXIMUM STATEMENT OCTETS DATA', 0, no_limit},
		SizingItem{20002, 'MAXIMUM STATEMENT OCTETS SCHEMA', 0, no_limit},
		SizingItem{25000, 'MAXIMUM CURRENT DEFAULT TRANSFORM GROUP LENGTH', none, 'Transform groups are not supported.'},
		SizingItem{25001, 'MAXIMUM CURRENT TRANSFORM GROUP LENGTH', none, 'Transform groups are not supported.'},
		SizingItem{25002, 'MAXIMUM CURRENT PATH LENGTH', none, 'CURRENT_PATH is not supported.'},
		SizingItem{25003, 'MAXIMUM CURRENT ROLE LENGTH', none, 'Roles are not supported.'},
		SizingItem{25004, 'MAXIMUM SESSION USER LENGTH', none, 'SESSION_USER is not supported.'},
		SizingItem{25005, 'MAXIMUM SYSTEM USER LENGTH', none, 'SYSTEM_USER is not supported.'},
	]
}

// sql_sizing_view_row is a row of the SQL_SIZING view.
fn sql_sizing_view_row(item SizingItem) []Value {
	return [
		new_integer_value(item.id), // SIZING_ID
		new_varchar_value(item.name), // SIZING_NAME
		if v := item.supported_value {
			new_integer_value(v)
		} else {
			new_null_value(.is_integer)
		}, // SUPPORTED_VALUE
		new_varchar_value(item.comments), // COMMENTS
	]
}
