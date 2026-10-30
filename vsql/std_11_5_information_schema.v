module vsql

// ISO/IEC 9075-11:2008(E), 5, Information Schema
//
// Every catalog has an INFORMATION_SCHEMA that describes its tables. The views
// of the Information Schema are defined on the base tables of the Definition
// Schema (6), which "need do no more than simulate the existence of the
// Definition Schema, as viewed through the Information Schema views" (4.1).
// vsql doesn't have views, so each view is a virtual table that's built from
// the table definitions when it's read. The INFORMATION_SCHEMA can't be
// changed, and isn't stored in the file.

const information_schema_name = 'INFORMATION_SCHEMA'

// The domains of the Information Schema (5.3 to 5.7) are their data types,
// because vsql doesn't have domains. An SQL_IDENTIFIER can hold any name
// (max_identifier_length) and CHARACTER_DATA any character string
// (max_character_length).
const information_schema_sql_identifier = 'CHARACTER VARYING(128)'
const information_schema_character_data = 'CHARACTER VARYING(10485760)'
const information_schema_cardinal_number = 'INTEGER'
const information_schema_yes_or_no = 'CHARACTER VARYING(3)'

// check_writable_schema returns an error if the schema of a fully qualified
// identifier is the INFORMATION_SCHEMA, which only allows SELECT (4.2).
fn check_writable_schema(ident Identifier) ! {
	if ident.schema_name == information_schema_name {
		return sqlstate_42501('${information_schema_name} is read-only')
	}
}

// register_information_schema adds the views of the INFORMATION_SCHEMA to a
// catalog.
fn register_information_schema(mut catalog CatalogConnection) ! {
	// The views are read from the catalog when they're used, not copied now.
	c := &catalog
	id := information_schema_sql_identifier
	cd := information_schema_character_data
	cn := information_schema_cardinal_number
	yn := information_schema_yes_or_no

	// ISO/IEC 9075-11:2008(E), 5.61, TABLES view
	catalog.add_information_schema_table('CREATE TABLE TABLES (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		TABLE_TYPE ${cd} NOT NULL,
		SELF_REFERENCING_COLUMN_NAME ${id},
		REFERENCE_GENERATION ${cd},
		USER_DEFINED_TYPE_CATALOG ${id},
		USER_DEFINED_TYPE_SCHEMA ${id},
		USER_DEFINED_TYPE_NAME ${id},
		IS_INSERTABLE_INTO ${yn} NOT NULL,
		IS_TYPED ${yn} NOT NULL,
		COMMIT_ACTION ${cd}
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				t.next_values(tables_view_row(c.catalog_name, table))
			}
			t.done()
		})!

	// ISO/IEC 9075-11:2008(E), 5.21, COLUMNS view
	catalog.add_information_schema_table('CREATE TABLE COLUMNS (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		COLUMN_NAME ${id} NOT NULL,
		ORDINAL_POSITION ${cn} NOT NULL,
		COLUMN_DEFAULT ${cd},
		IS_NULLABLE ${yn} NOT NULL,
		DATA_TYPE ${cd} NOT NULL,
		CHARACTER_MAXIMUM_LENGTH ${cn},
		CHARACTER_OCTET_LENGTH ${cn},
		NUMERIC_PRECISION ${cn},
		NUMERIC_PRECISION_RADIX ${cn},
		NUMERIC_SCALE ${cn},
		DATETIME_PRECISION ${cn},
		INTERVAL_TYPE ${cd},
		INTERVAL_PRECISION ${cn},
		CHARACTER_SET_CATALOG ${id},
		CHARACTER_SET_SCHEMA ${id},
		CHARACTER_SET_NAME ${id},
		COLLATION_CATALOG ${id},
		COLLATION_SCHEMA ${id},
		COLLATION_NAME ${id},
		DOMAIN_CATALOG ${id},
		DOMAIN_SCHEMA ${id},
		DOMAIN_NAME ${id},
		UDT_CATALOG ${id},
		UDT_SCHEMA ${id},
		UDT_NAME ${id},
		SCOPE_CATALOG ${id},
		SCOPE_SCHEMA ${id},
		SCOPE_NAME ${id},
		MAXIMUM_CARDINALITY ${cn},
		DTD_IDENTIFIER ${id},
		IS_SELF_REFERENCING ${yn} NOT NULL,
		IS_IDENTITY ${yn} NOT NULL,
		IDENTITY_GENERATION ${cd},
		IDENTITY_START ${cd},
		IDENTITY_INCREMENT ${cd},
		IDENTITY_MAXIMUM ${cd},
		IDENTITY_MINIMUM ${cd},
		IDENTITY_CYCLE ${yn},
		IS_GENERATED ${cd} NOT NULL,
		GENERATION_EXPRESSION ${cd},
		IS_UPDATABLE ${yn} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				for i, column in table.columns {
					t.next_values(columns_view_row(c.catalog_name, table, i, column))
				}
			}
			t.done()
		})!

	// ISO/IEC 9075-11:2008(E), 5.14, CHECK_CONSTRAINTS view
	catalog.add_information_schema_table('CREATE TABLE CHECK_CONSTRAINTS (
		CONSTRAINT_CATALOG ${id} NOT NULL,
		CONSTRAINT_SCHEMA ${id} NOT NULL,
		CONSTRAINT_NAME ${id} NOT NULL,
		CHECK_CLAUSE ${cd}
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				for row in check_constraints_view_rows(c.catalog_name, table) {
					t.next_values(row)
				}
			}
			t.done()
		})!

	// ISO/IEC 9075-11:2008(E), 5.58, TABLE_CONSTRAINTS view. ENFORCED is whether
	// the table constraint is enforced (ISO/IEC 9075-2:2016(E), 4.23.3.1).
	catalog.add_information_schema_table('CREATE TABLE TABLE_CONSTRAINTS (
		CONSTRAINT_CATALOG ${id} NOT NULL,
		CONSTRAINT_SCHEMA ${id} NOT NULL,
		CONSTRAINT_NAME ${id} NOT NULL,
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		CONSTRAINT_TYPE ${cd} NOT NULL,
		IS_DEFERRABLE ${yn} NOT NULL,
		INITIALLY_DEFERRED ${yn} NOT NULL,
		ENFORCED ${yn} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				for row in table_constraints_view_rows(c.catalog_name, table) {
					t.next_values(row)
				}
			}
			t.done()
		})!

	// ISO/IEC 9075-11:2008(E), 5.32, KEY_COLUMN_USAGE view
	catalog.add_information_schema_table('CREATE TABLE KEY_COLUMN_USAGE (
		CONSTRAINT_CATALOG ${id} NOT NULL,
		CONSTRAINT_SCHEMA ${id} NOT NULL,
		CONSTRAINT_NAME ${id} NOT NULL,
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		COLUMN_NAME ${id} NOT NULL,
		ORDINAL_POSITION ${cn} NOT NULL,
		POSITION_IN_UNIQUE_CONSTRAINT ${cn}
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				if table.is_virtual {
					continue
				}
				if table.primary_key.len > 0 {
					for row in key_column_usage_view_rows(c.catalog_name, table, table.primary_key_name,
						table.primary_key, []int{}) {
						t.next_values(row)
					}
				}
				for constraint in table.unique_constraints {
					for row in key_column_usage_view_rows(c.catalog_name, table, constraint.name,
						constraint.columns, []int{}) {
						t.next_values(row)
					}
				}
				for key in table.foreign_keys {
					referenced := c.storage.table(key.referenced_table.storage_id())
					_, unique_columns := unique_constraint_for(referenced, key.referenced_columns)
					positions := key.referenced_columns.map(unique_columns.index(it) + 1)
					for row in key_column_usage_view_rows(c.catalog_name, table, key.name,
						key.columns, positions) {
						t.next_values(row)
					}
				}
			}
			t.done()
		})!

	// ISO/IEC 9075-11:2008(E), 5.37, REFERENTIAL_CONSTRAINTS view
	catalog.add_information_schema_table('CREATE TABLE REFERENTIAL_CONSTRAINTS (
		CONSTRAINT_CATALOG ${id} NOT NULL,
		CONSTRAINT_SCHEMA ${id} NOT NULL,
		CONSTRAINT_NAME ${id} NOT NULL,
		UNIQUE_CONSTRAINT_CATALOG ${id} NOT NULL,
		UNIQUE_CONSTRAINT_SCHEMA ${id} NOT NULL,
		UNIQUE_CONSTRAINT_NAME ${id} NOT NULL,
		MATCH_OPTION ${cd} NOT NULL,
		UPDATE_RULE ${cd} NOT NULL,
		DELETE_RULE ${cd} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				for i, key in table.foreign_keys {
					t.next_values(referential_constraints_view_row(c.catalog_name, table,
						i, c.storage.table(key.referenced_table.storage_id())))
				}
			}
			t.done()
		})!
}

// add_information_schema_table adds a view of the INFORMATION_SCHEMA from its
// CREATE TABLE (without the schema name).
fn (mut catalog CatalogConnection) add_information_schema_table(create_table string, data VirtualTableProviderFn) ! {
	stmt := parse_definition(create_table.bytes())!
	if stmt is TableDefinition {
		table_name := Identifier{
			catalog_name: catalog.catalog_name
			schema_name:  information_schema_name
			entity_name:  stmt.table_name.entity_name
		}
		catalog.virtual_tables[table_name.storage_id()] = VirtualTable{
			create_table_sql:  create_table
			create_table_stmt: TableDefinition{
				...stmt
				table_name: table_name
			}
			data:              data
		}
	}
}

// information_schema_tables returns the tables that the INFORMATION_SCHEMA
// describes, ordered by schema and table name: the tables of the catalog, and
// the views of the INFORMATION_SCHEMA itself (Note 1). Virtual tables that are
// registered on a connection aren't part of the catalog.
fn (catalog &CatalogConnection) information_schema_tables() []Table {
	mut tables := []Table{}
	for _, table in catalog.storage.tables {
		tables << table
	}
	for _, virtual_table in catalog.virtual_tables {
		if virtual_table.create_table_stmt.table_name.schema_name == information_schema_name {
			tables << virtual_table.table()
		}
	}

	tables.sort_with_compare(fn (a &Table, b &Table) int {
		if a.name.schema_name != b.name.schema_name {
			return if a.name.schema_name < b.name.schema_name { -1 } else { 1 }
		}

		return if a.name.entity_name < b.name.entity_name { -1 } else { 1 }
	})

	return tables
}

// tables_view_row is a row of the TABLES view (ISO/IEC 9075-11:2008(E), 6.50,
// TABLES base table). Every table is a persistent base table, except for the
// views of the INFORMATION_SCHEMA, which can't be inserted into.
fn tables_view_row(catalog_name string, table Table) []Value {
	return [
		new_varchar_value(catalog_name), // TABLE_CATALOG
		new_varchar_value(table.name.schema_name), // TABLE_SCHEMA
		new_varchar_value(table.name.entity_name), // TABLE_NAME
		new_varchar_value(if table.is_virtual { 'VIEW' } else { 'BASE TABLE' }), // TABLE_TYPE
		new_null_value(.is_varchar), // SELF_REFERENCING_COLUMN_NAME
		new_null_value(.is_varchar), // REFERENCE_GENERATION
		new_null_value(.is_varchar), // USER_DEFINED_TYPE_CATALOG
		new_null_value(.is_varchar), // USER_DEFINED_TYPE_SCHEMA
		new_null_value(.is_varchar), // USER_DEFINED_TYPE_NAME
		yes_or_no(!table.is_virtual), // IS_INSERTABLE_INTO
		yes_or_no(false), // IS_TYPED
		new_null_value(.is_varchar), // COMMIT_ACTION
	]
}

// columns_view_row is a row of the COLUMNS view (ISO/IEC 9075-11:2008(E), 6.20,
// COLUMNS base table) for the column at index i of a table. There are no
// domains or generated columns.
fn columns_view_row(catalog_name string, table Table, i int, column Column) []Value {
	column_name := column.name.sub_entity_name
	mut row := [
		new_varchar_value(catalog_name), // TABLE_CATALOG
		new_varchar_value(table.name.schema_name), // TABLE_SCHEMA
		new_varchar_value(table.name.entity_name), // TABLE_NAME
		new_varchar_value(column_name), // COLUMN_NAME
		new_integer_value(i + 1), // ORDINAL_POSITION
		column_default(column), // COLUMN_DEFAULT
		yes_or_no(!column.not_null && column_name !in table.primary_key), // IS_NULLABLE
	]
	row << data_type_descriptor(catalog_name, column.typ)
	row << [
		new_null_value(.is_varchar), // DOMAIN_CATALOG
		new_null_value(.is_varchar), // DOMAIN_SCHEMA
		new_null_value(.is_varchar), // DOMAIN_NAME
		new_null_value(.is_varchar), // UDT_CATALOG
		new_null_value(.is_varchar), // UDT_SCHEMA
		new_null_value(.is_varchar), // UDT_NAME
		new_null_value(.is_varchar), // SCOPE_CATALOG
		new_null_value(.is_varchar), // SCOPE_SCHEMA
		new_null_value(.is_varchar), // SCOPE_NAME
		new_null_value(.is_integer), // MAXIMUM_CARDINALITY
		// The DTD_IDENTIFIER is implementation-dependent, but must identify the
		// data type of the column within the table (6.21, Description 2).
		new_varchar_value('${i + 1}'), // DTD_IDENTIFIER
		yes_or_no(false), // IS_SELF_REFERENCING
	]
	row << identity_descriptor(column)
	row << [
		new_varchar_value(if column.generated != none { 'ALWAYS' } else { 'NEVER' }), // IS_GENERATED
		generation_expression(column), // GENERATION_EXPRESSION
		yes_or_no(!table.is_virtual), // IS_UPDATABLE
	]

	return row
}

// generation_expression is the GENERATION_EXPRESSION of the COLUMNS view, which
// is NULL for a column that isn't a generated column.
fn generation_expression(column Column) Value {
	generated := column.generated or { return new_null_value(.is_varchar) }

	return new_varchar_value(generated.expr.pstr(map[string]Value{}))
}

// identity_descriptor is IS_IDENTITY to IDENTITY_CYCLE of the COLUMNS view,
// which describe the identity column and its sequence.
fn identity_descriptor(column Column) []Value {
	identity := column.identity or {
		return [yes_or_no(false), new_null_value(.is_varchar), new_null_value(.is_varchar),
			new_null_value(.is_varchar), new_null_value(.is_varchar), new_null_value(.is_varchar),
			new_null_value(.is_varchar)]
	}

	return [
		yes_or_no(true), // IS_IDENTITY
		new_varchar_value(if identity.always { 'ALWAYS' } else { 'BY DEFAULT' }), // IDENTITY_GENERATION
		new_varchar_value('${identity.sequence.start_value}'), // IDENTITY_START
		new_varchar_value('${identity.sequence.increment_by}'), // IDENTITY_INCREMENT
		new_varchar_value('${identity.sequence.max_value}'), // IDENTITY_MAXIMUM
		new_varchar_value('${identity.sequence.min_value}'), // IDENTITY_MINIMUM
		yes_or_no(identity.sequence.cycle), // IDENTITY_CYCLE
	]
}

// check_constraints_view_rows are the rows of the CHECK_CONSTRAINTS view
// (ISO/IEC 9075-11:2008(E), 6.14, CHECK_CONSTRAINTS base table) for a table. A
// NOT NULL column is the same as a CHECK (column IS NOT NULL) constraint
// (ISO/IEC 9075-2:2016(E), 11.4, Syntax Rules, 17.a), so it's included, in the
// order of the columns, before the CHECK constraints in the order they were
// defined. The views of the INFORMATION_SCHEMA don't have constraints.
fn check_constraints_view_rows(catalog_name string, table Table) [][]Value {
	if table.is_virtual {
		return [][]Value{}
	}

	mut rows := [][]Value{}
	for column in table.columns {
		if column.not_null {
			rows << check_constraints_view_row(catalog_name, table, table.not_null_names[column.name.sub_entity_name],
				'${requote_identifier(column.name.sub_entity_name)} IS NOT NULL')
		}
	}
	for constraint in table.check_constraints {
		rows << check_constraints_view_row(catalog_name, table, constraint.name.entity_name,
			constraint.search_condition.pstr(map[string]Value{}))
	}

	return rows
}

// table_constraints_view_rows are the rows of the TABLE_CONSTRAINTS view
// (ISO/IEC 9075-11:2008(E), 6.47, TABLE_CONSTRAINTS base table) for a table:
// the PRIMARY KEY, then each UNIQUE, then each FOREIGN KEY, then the same check
// constraints as the CHECK_CONSTRAINTS view, in the same order and with the
// same names. Constraints can't be NOT ENFORCED yet.
fn table_constraints_view_rows(catalog_name string, table Table) [][]Value {
	if table.is_virtual {
		return [][]Value{}
	}

	mut rows := [][]Value{}
	if table.primary_key.len > 0 {
		rows << table_constraints_view_row(catalog_name, table, table.primary_key_name,
			'PRIMARY KEY', ConstraintCharacteristics{})
	}
	for constraint in table.unique_constraints {
		rows << table_constraints_view_row(catalog_name, table, constraint.name, 'UNIQUE',
			constraint.characteristics)
	}
	for key in table.foreign_keys {
		rows << table_constraints_view_row(catalog_name, table, key.name, 'FOREIGN KEY',
			key.characteristics)
	}
	for column in table.columns {
		if column.not_null {
			rows << table_constraints_view_row(catalog_name, table, table.not_null_names[column.name.sub_entity_name],
				'CHECK', ConstraintCharacteristics{})
		}
	}
	for constraint in table.check_constraints {
		rows << table_constraints_view_row(catalog_name, table, constraint.name.entity_name,
			'CHECK', constraint.characteristics)
	}

	return rows
}

// referential_constraints_view_row is the row of the REFERENTIAL_CONSTRAINTS
// view (ISO/IEC 9075-11:2008(E), 6.33, REFERENTIAL_CONSTRAINTS base table) for
// the ith FOREIGN KEY of a table, which references the referenced table. The
// unique constraint is the PRIMARY KEY or UNIQUE of the referenced table that
// has the referenced columns, with its name in the TABLE_CONSTRAINTS view. A
// FOREIGN KEY can't have a MATCH yet (so it's NONE, Description 3).
fn referential_constraints_view_row(catalog_name string, table Table, i int, referenced Table) []Value {
	unique_constraint_name, _ := unique_constraint_for(referenced, table.foreign_keys[i].referenced_columns)

	return [
		new_varchar_value(catalog_name), // CONSTRAINT_CATALOG
		new_varchar_value(table.name.schema_name), // CONSTRAINT_SCHEMA
		new_varchar_value(table.foreign_keys[i].name), // CONSTRAINT_NAME
		new_varchar_value(catalog_name), // UNIQUE_CONSTRAINT_CATALOG
		new_varchar_value(referenced.name.schema_name), // UNIQUE_CONSTRAINT_SCHEMA
		new_varchar_value(unique_constraint_name), // UNIQUE_CONSTRAINT_NAME
		new_varchar_value('NONE'), // MATCH_OPTION
		new_varchar_value(table.foreign_keys[i].update_action()), // UPDATE_RULE
		new_varchar_value(table.foreign_keys[i].delete_action()), // DELETE_RULE
	]
}

// unique_constraint_for returns the name and columns of the PRIMARY KEY or
// UNIQUE of a table that has the referenced columns of a FOREIGN KEY (in any
// order).
fn unique_constraint_for(referenced Table, referenced_columns []string) (string, []string) {
	mut columns := referenced_columns.clone()
	columns.sort()
	for constraint in referenced.unique_constraints {
		mut sorted := constraint.columns.clone()
		sorted.sort()
		if sorted == columns {
			return constraint.name, constraint.columns
		}
	}

	return referenced.primary_key_name, referenced.primary_key
}

// key_column_usage_view_rows are the rows of the KEY_COLUMN_USAGE view (ISO/IEC
// 9075-11:2008(E), 6.28, KEY_COLUMN_USAGE base table) for the columns of a
// PRIMARY KEY, UNIQUE or FOREIGN KEY. The positions are the
// POSITION_IN_UNIQUE_CONSTRAINT of each column of a FOREIGN KEY: the position
// of the referenced column in the unique constraint that it references.
fn key_column_usage_view_rows(catalog_name string, table Table, name string, columns []string, positions []int) [][]Value {
	mut rows := [][]Value{}
	for i, column in columns {
		rows << [
			new_varchar_value(catalog_name), // CONSTRAINT_CATALOG
			new_varchar_value(table.name.schema_name), // CONSTRAINT_SCHEMA
			new_varchar_value(name), // CONSTRAINT_NAME
			new_varchar_value(catalog_name), // TABLE_CATALOG
			new_varchar_value(table.name.schema_name), // TABLE_SCHEMA
			new_varchar_value(table.name.entity_name), // TABLE_NAME
			new_varchar_value(column), // COLUMN_NAME
			new_integer_value(i + 1), // ORDINAL_POSITION
			if positions.len > 0 {
				new_integer_value(positions[i])
			} else {
				new_null_value(.is_integer)
			}, // POSITION_IN_UNIQUE_CONSTRAINT
		]
	}

	return rows
}

// table_constraints_view_row is a row of the TABLE_CONSTRAINTS view.
fn table_constraints_view_row(catalog_name string, table Table, name string, constraint_type string, characteristics ConstraintCharacteristics) []Value {
	return [
		new_varchar_value(catalog_name), // CONSTRAINT_CATALOG
		new_varchar_value(table.name.schema_name), // CONSTRAINT_SCHEMA
		new_varchar_value(name), // CONSTRAINT_NAME
		new_varchar_value(catalog_name), // TABLE_CATALOG
		new_varchar_value(table.name.schema_name), // TABLE_SCHEMA
		new_varchar_value(table.name.entity_name), // TABLE_NAME
		new_varchar_value(constraint_type), // CONSTRAINT_TYPE
		yes_or_no(characteristics.is_deferrable()), // IS_DEFERRABLE
		yes_or_no(characteristics.is_initially_deferred()), // INITIALLY_DEFERRED
		new_varchar_value('YES'), // ENFORCED
	]
}

// check_constraints_view_row is a row of the CHECK_CONSTRAINTS view. A
// CHECK_CLAUSE that's longer than CHARACTER_DATA can hold is NULL (6.14,
// Description 2b).
fn check_constraints_view_row(catalog_name string, table Table, name string, check_clause string) []Value {
	return [
		new_varchar_value(catalog_name), // CONSTRAINT_CATALOG
		new_varchar_value(table.name.schema_name), // CONSTRAINT_SCHEMA
		new_varchar_value(name), // CONSTRAINT_NAME
		if check_clause.runes().len > max_character_length {
			new_null_value(.is_varchar)
		} else {
			new_varchar_value(check_clause)
		}, // CHECK_CLAUSE
	]
}

// column_default is the text of the DEFAULT of a column, or NULL if it doesn't
// have one. A default that's longer than CHARACTER_DATA can hold is
// "TRUNCATED" (6.20, Description 7).
fn column_default(column Column) Value {
	default_value := column.default_value or { return new_null_value(.is_varchar) }
	s := default_value.str()
	if s.runes().len > max_character_length {
		return new_varchar_value('TRUNCATED')
	}

	return new_varchar_value(s)
}

// data_type_descriptor is the values of the COLUMNS view, from DATA_TYPE to
// COLLATION_NAME, that describe a data type (ISO/IEC 9075-11:2008(E), 6.21,
// DATA_TYPE_DESCRIPTOR base table). Character strings are UTF-8, which can use
// up to 4 bytes for each character, and have no collation.
fn data_type_descriptor(catalog_name string, t Type) []Value {
	mut data_type := t.typ.str()
	mut character_maximum_length := ?int(none)
	mut character_octet_length := ?int(none)
	mut numeric_precision := ?int(none)
	mut numeric_precision_radix := ?int(none)
	mut numeric_scale := ?int(none)
	mut datetime_precision := ?int(none)
	mut character_set := false

	match t.typ {
		.is_character, .is_varchar {
			character_maximum_length = t.size
			character_octet_length = t.size * 4
			character_set = true
		}
		.is_smallint, .is_integer, .is_bigint {
			// The precision of SMALLINT, INTEGER and BIGINT is in bits.
			numeric_precision = match t.typ {
				.is_smallint { 16 }
				.is_integer { 32 }
				else { 64 }
			}
			numeric_precision_radix = 2
			numeric_scale = 0
		}
		.is_numeric, .is_decimal {
			numeric_precision = t.numeric_precision()
			numeric_precision_radix = 10
			numeric_scale = t.scale
		}
		.is_real {
			numeric_precision = 24
			numeric_precision_radix = 2
		}
		.is_double_precision {
			// A FLOAT(p) is a DOUBLE PRECISION.
			numeric_precision = max_float_precision
			numeric_precision_radix = 2
		}
		.is_date {
			datetime_precision = 0
		}
		.is_time_without_time_zone, .is_timestamp_without_time_zone {
			data_type = data_type.replace(' WITHOUT TIME ZONE', '')
			datetime_precision = t.size
		}
		.is_time_with_time_zone, .is_timestamp_with_time_zone {
			datetime_precision = t.size
		}
		.is_boolean {}
	}

	return [
		new_varchar_value(data_type), // DATA_TYPE
		optional_integer_value(character_maximum_length), // CHARACTER_MAXIMUM_LENGTH
		optional_integer_value(character_octet_length), // CHARACTER_OCTET_LENGTH
		optional_integer_value(numeric_precision), // NUMERIC_PRECISION
		optional_integer_value(numeric_precision_radix), // NUMERIC_PRECISION_RADIX
		optional_integer_value(numeric_scale), // NUMERIC_SCALE
		optional_integer_value(datetime_precision), // DATETIME_PRECISION
		new_null_value(.is_varchar), // INTERVAL_TYPE
		new_null_value(.is_integer), // INTERVAL_PRECISION
		optional_varchar_value(character_set, catalog_name), // CHARACTER_SET_CATALOG
		optional_varchar_value(character_set, information_schema_name), // CHARACTER_SET_SCHEMA
		optional_varchar_value(character_set, 'UTF8'), // CHARACTER_SET_NAME
		new_null_value(.is_varchar), // COLLATION_CATALOG
		new_null_value(.is_varchar), // COLLATION_SCHEMA
		new_null_value(.is_varchar), // COLLATION_NAME
	]
}

fn yes_or_no(b bool) Value {
	return new_varchar_value(if b { 'YES' } else { 'NO' })
}

fn optional_integer_value(x ?int) Value {
	return new_integer_value(x or { return new_null_value(.is_integer) })
}

fn optional_varchar_value(present bool, s string) Value {
	return if present { new_varchar_value(s) } else { new_null_value(.is_varchar) }
}
