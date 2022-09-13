// create_table.v contains the implementation for the CREATE TABLE statement.

module vsql

import time

fn execute_create_table(mut c Connection, stmt CreateTableStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut table_name := stmt.table_name

	// TODO(elliotchance): This isn't really ideal. Replace with a proper
	//  identifier chain when we support that.
	if table_name.contains('.') {
		parts := table_name.split('.')

		if parts[0] !in c.storage.schemas {
			return sqlstate_3f000(parts[0]) // scheme does not exist
		}
	} else {
		table_name = 'PUBLIC.$table_name'
	}

	// Make sure the table doesn't exist at any visibility (so we cannot use
	// get_table_by_name) This is to avoid concurrent transactions from creating
	// a table of the same name.
	for _, table in c.storage.tables {
		if table.name == table_name {
			return sqlstate_42p07(table_name) // duplicate table
		}
	}

	mut columns := []Column{}
	mut primary_key := []string{}
	for table_element in stmt.table_elements {
		match table_element {
			Column {
				column_name := table_element.name

				columns << Column{column_name, table_element.typ, table_element.not_null}
			}
			UniqueConstraintDefinition {
				if primary_key.len > 0 {
					return sqlstate_42601('only one PRIMARY KEY can be defined')
				}

				if table_element.columns.len > 1 {
					return sqlstate_42601('PRIMARY KEY only supports one column')
				}

				for column in table_element.columns {
					// Only some types are allowed in the PRIMARY KEY.
					mut found := false
					for e in stmt.table_elements {
						if e is Column {
							if e.name == column.name {
								match e.typ.typ {
									.is_smallint, .is_integer, .is_bigint {
										primary_key << column.name
									}
									else {
										return sqlstate_42601('PRIMARY KEY does not support $e.typ')
									}
								}

								found = true
							}
						}
					}

					if !found {
						return sqlstate_42601('unknown column $column.name in PRIMARY KEY')
					}
				}
			}
		}
	}

	c.storage.create_table(table_name, columns, primary_key)!

	return new_result_msg('CREATE TABLE 1', elapsed_parse, t.elapsed())
}
