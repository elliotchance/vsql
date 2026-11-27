module vsql

import time

// ISO/IEC 9075-2:2023, 11.3, <table definition>
//
// Define a persistent base table, a created local temporary table, or a global
// temporary table.
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2023, 4.8.5, Base tables and their components
// ISO/IEC 9075-1:2023, 4.8.5.1, Base tables
// ISO/IEC 9075-2:2023, 4.17, Tables

type TableElement = CheckConstraintDefinition
	| Column
	| LikeClause
	| NotNullConstraint
	| ReferentialConstraintDefinition
	| UniqueConstraintDefinition

// max_columns is the maximum number of columns in a table.
const max_columns = 1600

// A TableDefinition has either table_elements (a <table element list>) or
// as_subquery (an <as subquery clause>).
struct TableDefinition {
	table_name     Identifier
	table_elements []TableElement
	as_subquery    ?AsSubqueryClause
	if_not_exists  bool // V103-01, a table that already exists isn't an error
}

// AsSubqueryClause is an <as subquery clause>, which defines the columns of the
// table from the columns of a query (and optionally names them with columns),
// and also inserts the rows of the query when with_data is true.
struct AsSubqueryClause {
	columns   []Identifier
	query     QueryExpression
	with_data bool
}

// LikeClause is a <like clause> in a <table element list>, which is replaced by
// the columns of another table when the table is created (see
// TableDefinition.with_like_columns).
struct LikeClause {
	table_name Identifier
	options    []LikeOption
}

// LikeOption is an INCLUDING (included is true) or EXCLUDING of IDENTITY,
// DEFAULTS or GENERATED in the <like options> of a <like clause>.
struct LikeOption {
	name     string
	included bool
}

// included returns whether the <like options> include IDENTITY, DEFAULTS or
// GENERATED, which they don't unless they say so. Each one can only be given
// once.
//
// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b.iv.1, 9.b.iv.2, 9.b.iv.3 and 9.b.iv.4
fn (l LikeClause) included(name string) !bool {
	mut included := false
	mut found := false
	for option in l.options {
		if option.name == name {
			if found {
				return sqlstate_42601('LIKE ${l.table_name} has more than one ${name} option')
			}
			found = true
			included = option.included
		}
	}

	return included
}

fn (s TableDefinition) columns() Columns {
	mut columns := []Column{}
	for c in s.table_elements {
		if c is Column {
			columns << c
		}
	}

	return columns
}

// check_limits returns an error if the table has more columns, or a column has
// a larger type, than allowed. Like check_data_type, it's not used when a table
// definition is read from the file.
fn (s TableDefinition) check_limits(table_name Identifier) ! {
	columns := s.columns()
	if columns.len > max_columns {
		return sqlstate_54000('table ${table_name} has ${columns.len} columns, but the maximum is ${max_columns}')
	}

	for column in columns {
		check_data_type(column.typ)!
	}
}

fn (stmt TableDefinition) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	msg := if stmt.create(mut conn)! { 'CREATE TABLE 1' } else { 'CREATE TABLE 0' }

	return new_result_msg(msg, elapsed_parse, t.elapsed())
}

// create creates the table and returns true, or false if it already exists with
// IF NOT EXISTS. The caller must have the write connection open.
fn (stmt TableDefinition) create(mut conn Connection) !bool {
	created, _ := stmt.create_table(mut conn, false, [])!

	return created
}

// create_table creates the table (see create) and also returns the table. When
// defer_foreign_keys is true, the table is stored without its foreign keys. They
// are still named (and the names can't be any of reserved_names), and they're
// in the returned table, so that they can be added once the tables that they
// reference exist (see SchemaDefinition.create_elements).
fn (stmt TableDefinition) create_table(mut conn Connection, defer_foreign_keys bool, reserved_names []string) !(bool, Table) {
	mut table_name := conn.resolve_schema_identifier(stmt.table_name)!
	check_writable_schema(table_name)!
	mut catalog := conn.catalog_for(table_name)
	if table_name.storage_id() in catalog.storage.tables
		|| table_name.storage_id() in catalog.storage.views
		|| table_name.storage_id() in catalog.virtual_tables {
		// The existing table isn't changed or compared with this definition,
		// which isn't checked either.
		if stmt.if_not_exists {
			return false, Table{}
		}

		// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 7
		return sqlstate_42p07_table(table_name) // duplicate table
	}

	definition := stmt.as_table_elements(mut conn)!.with_like_columns(mut conn, table_name)!
	definition.check_limits(table_name)!
	mut table := definition.table(table_name, 0)!
	mut other_names := catalog.storage.schema_constraint_names(table_name)
	other_names << reserved_names
	table.name_constraints(other_names, catalog.storage.schema_index_names(table_name))!
	resolve_generated_columns(mut conn, mut table, 0)!
	if !defer_foreign_keys {
		resolve_foreign_keys(mut conn, mut table)!
	}
	for column in table.columns {
		check_default_clause(mut conn, column)!
	}
	check_new_check_constraints(mut conn, table, 0)!

	catalog.storage.create_table(Table{
		...table
		foreign_keys: if defer_foreign_keys { []ForeignKey{} } else { table.foreign_keys }
	})!

	// WITH DATA inserts the rows of the query into the new table.
	//
	// ISO/IEC 9075-2:2023, 11.3, <table definition>, General Rules, 10
	if as_subquery := stmt.as_subquery {
		if as_subquery.with_data {
			InsertStatement{
				table_name: table_name
				query:      as_subquery.query
			}.insert(mut conn, map[string]Value{})!
		}
	}

	return true, table
}

// as_table_elements returns the definition with the columns of its <as subquery
// clause> as a <table element list>. Each column has the name (unless the
// <column name list> gives one), type and nullability of a column of the
// query, but nothing else, such as a default. A definition that already has a
// <table element list> is returned as it is.
//
// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 10
fn (stmt TableDefinition) as_table_elements(mut conn Connection) !TableDefinition {
	as_subquery := stmt.as_subquery or { return stmt }

	// The table isn't a range variable in the query, so the query can't refer
	// to the table, which doesn't exist yet anyway. The query is planned
	// without any parameters, because it can't use them.
	//
	// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 4 and 16
	plan := create_plan(as_subquery.query, map[string]Value{}, mut conn) or {
		if err is SQLState42P02 {
			return sqlstate_42601('parameter ${err.parameter_name} cannot be used in CREATE TABLE')
		}
		return err
	}
	query_columns := plan.columns()

	// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 10.e
	if as_subquery.columns.len > 0 && as_subquery.columns.len != query_columns.len {
		return sqlstate_42601('CREATE TABLE has ${as_subquery.columns.len} column names, but the query has ${query_columns.len} columns')
	}

	// Two columns with the same name are an error of table, the same as for a
	// <table element list>.
	//
	// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 10.b, 10.d and 10.f.i
	mut elements := []TableElement{}
	for i, column in query_columns {
		name := if as_subquery.columns.len > 0 {
			as_subquery.columns[i].sub_entity_name
		} else if column.unnamed {
			return sqlstate_42601('column ${i + 1} of the query needs a name, or a column name list is needed')
		} else {
			column.name.sub_entity_name
		}
		// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 10.f.ii, 10.f.iii, 10.f.iv and 10.g
		elements << Column{
			name:     Identifier{
				sub_entity_name: name
			}
			typ:      column.typ
			not_null: column.not_null
		}
	}

	return TableDefinition{
		...stmt
		table_elements: elements
		as_subquery:    none
	}
}

// with_like_columns returns the definition with each <like clause> replaced by
// the columns of its table, in the same place. Each column only has the name,
// type and nullability of the column it's copied from, and the constraints of
// the table aren't copied, other than NOT NULL.
//
// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b
fn (stmt TableDefinition) with_like_columns(mut conn Connection, table_name Identifier) !TableDefinition {
	if !stmt.table_elements.any(it is LikeClause) {
		return stmt
	}

	mut elements := []TableElement{}
	for element in stmt.table_elements {
		if element is LikeClause {
			// The table can be any table, including one of the
			// INFORMATION_SCHEMA.
			like_table := conn.like_table(element.table_name)!
			include_identity := element.included('IDENTITY')!
			include_defaults := element.included('DEFAULTS')!
			include_generated := element.included('GENERATED')!

			// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b.ii
			if like_table.is_virtual && element.options.len > 0 {
				return sqlstate_42601('LIKE ${element.table_name} cannot have options, because it is a view')
			}

			for column in like_table.columns {
				// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b.iii and 9.b.v
				mut new_column := Column{
					name:     Identifier{
						sub_entity_name: column.name.sub_entity_name
					}
					typ:      column.typ
					not_null: column.not_null
				}

				// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b.iv.5
				if identity := column.identity {
					if include_identity {
						new_column = Column{
							...new_column
							identity: &IdentityColumn{
								always:  identity.always
								options: [
									SequenceGeneratorOption(SequenceGeneratorStartWithOption{new_bigint_value(identity.sequence.start_value)}),
									SequenceGeneratorIncrementByOption{new_bigint_value(identity.sequence.increment_by)},
									SequenceGeneratorMinvalueOption{new_bigint_value(identity.sequence.min_value)},
									SequenceGeneratorMaxvalueOption{new_bigint_value(identity.sequence.max_value)},
									SequenceGeneratorCycleOption{identity.sequence.cycle},
								]
							}
						}
					}
				}

				// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b.iv.6
				if generated := column.generated {
					if include_generated {
						new_column = Column{
							...new_column
							generated: like_generated_column(table_name, generated.text)!.generated
						}
					}
				}

				// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b.iv.7
				if default_value := column.default_value {
					if include_defaults {
						new_column = Column{
							...new_column
							default_value: default_value
							default_text:  column.default_text
						}
					}
				}

				elements << new_column
			}
		} else {
			elements << element
		}
	}

	return TableDefinition{
		...stmt
		table_elements: elements
	}
}

// like_generated_column returns a column with the generation clause of a
// column that's copied by a <like clause> with INCLUDING GENERATED. A column reference in it
// can only be to a column of the table that it's copied from, so each column
// reference loses its qualifier, which makes it a column of the new table. The
// expression is parsed again as part of a definition of the new table
// (table_name), the same as when it's read from the file.
//
// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.b.iv.6.A and 9.b.iv.6.B
fn like_generated_column(table_name Identifier, text string) !Column {
	runes := text.runes()
	tokens := tokenize(text)!
	mut new_text := ''
	mut from := 0
	for i, token in tokens {
		// A name followed by a period is the qualifier of the name after it. A
		// name may also be a keyword, such as T or PUBLIC. A number can also be
		// followed by a period (such as "1.e5"), but that's part of the number.
		if token.token != token_literal_number && i + 2 < tokens.len
			&& tokens[i + 1].token == token_operator_period {
			new_text += runes[from..token.start].string()
			from = tokens[i + 2].start
		}
	}
	new_text += runes[from..].string()

	stmt := parse_definition('CREATE TABLE ${table_name.storage_sql()} (c INTEGER GENERATED ALWAYS AS ${new_text})'.bytes())!

	return (stmt as TableDefinition).table_elements[0] as Column
}

// like_table returns the table of a <like clause>, which can also be a virtual
// table.
fn (mut conn Connection) like_table(name Identifier) !Table {
	table_name := conn.resolve_table_identifier(name, true)!
	catalog := conn.catalog_for(table_name)
	id := table_name.storage_id()
	if table := catalog.storage.tables[id] {
		return table
	}

	// resolve_table_identifier found it, so it's a virtual table.
	virtual_table := unsafe { catalog.virtual_tables[id] }

	return virtual_table.table()
}

// table checks the definition and returns the table that it describes. It's
// also used when reading a table definition from the file. A constraint that
// doesn't have a <constraint name definition> has an empty name, see
// Table.name_constraints.
fn (stmt TableDefinition) table(table_name Identifier, tid u64) !Table {
	// The table elements need at least one column, table constraints aren't
	// enough.
	//
	// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 9.a
	if !stmt.table_elements.any(it is Column) {
		return sqlstate_42601_table('a table must have at least one column', table_name)
	}

	mut columns := []Column{}
	mut primary_key := []string{}
	mut primary_key_name := ''
	mut primary_key_characteristics := ConstraintCharacteristics{}
	mut deferrable_not_nulls := map[string]ConstraintCharacteristics{}
	mut not_null_names := map[string]string{}
	mut check_constraints := []CheckConstraintDefinition{}
	mut unique_constraints := []UniqueConstraint{}
	mut foreign_keys := []ForeignKey{}
	mut column_names := map[string]bool{}
	for table_element in stmt.table_elements {
		match table_element {
			Column {
				if table_element.name.sub_entity_name in column_names {
					return sqlstate_42601_table('column ${table_element.name.sub_entity_name} is defined more than once', table_name)
				}
				column_names[table_element.name.sub_entity_name] = true

				mut column := Column{
					...table_element
					name: Identifier{
						catalog_name:    table_name.catalog_name
						schema_name:     table_name.schema_name
						entity_name:     table_name.entity_name
						sub_entity_name: table_element.name.sub_entity_name
					}
				}

				// A table can have at most one identity column (also for ADD
				// COLUMN), which is implicitly NOT NULL.
				//
				// ISO/IEC 9075-2:2023, 11.3, <table definition>, Syntax Rules, 15
				// ISO/IEC 9075-2:2023, 11.11, <add column definition>, Syntax Rules, 3
				// ISO/IEC 9075-2:2023, 11.4, <column definition>, Syntax Rules, 16
				if identity := column.identity {
					if _ := Table{
						columns: columns
					}.identity_column()
					{
						return sqlstate_42601_table('table ${table_name} has more than one identity column', table_name)
					}
					column = Column{
						...column
						not_null: true
						identity: &IdentityColumn{
							...identity
							sequence: new_identity_sequence(column, identity.options)!
						}
					}
				}
				columns << column
			}
			CheckConstraintDefinition {
				check_constraints << CheckConstraintDefinition{
					...table_element
					name: Identifier{
						entity_name: table_constraint_name(table_element.name, table_name)!
					}
				}
			}
			NotNullConstraint {
				if table_element.characteristics.is_deferrable() {
					deferrable_not_nulls[table_element.column] = table_element.characteristics
				}
				if table_element.name.entity_name == '' {
					continue
				}
				if not_null_names[table_element.column] != '' {
					return sqlstate_42601_table('column ${table_element.column} has more than one named NOT NULL', table_name)
				}
				not_null_names[table_element.column] = table_constraint_name(table_element.name,
					table_name)!
			}
			UniqueConstraintDefinition {
				// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 9
				if table_element.is_primary_key && primary_key.len > 0 {
					return sqlstate_42601_table('only one PRIMARY KEY can be defined', table_name)
				}

				constraint := if table_element.is_primary_key { 'PRIMARY KEY' } else { 'UNIQUE' }
				mut unique_columns := []string{}
				for column in table_element.columns {
					if column.sub_entity_name in unique_columns {
						return sqlstate_42601_table('column ${column.sub_entity_name} appears more than once in ${constraint}', table_name)
					}

					// Each column must be a column of the table, and only once. A
					// column of any type can be in a PRIMARY KEY or UNIQUE,
					// because they can all be grouped.
					//
					// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 1 and 6.a
					if !stmt.has_column(column.sub_entity_name) {
						return sqlstate_42703(table_name, column.sub_entity_name)
					}
					check_groupable_column(column.sub_entity_name, stmt.column_type(column.sub_entity_name),
						constraint)!
					unique_columns << column.sub_entity_name
				}

				name := table_constraint_name(table_element.name, table_name)!
				if table_element.is_primary_key {
					primary_key = unique_columns.clone()
					primary_key_name = name
					if table_element.characteristics.is_deferrable() {
						primary_key_characteristics = table_element.characteristics
					}
				} else {
					unique_constraints << UniqueConstraint{
						name:               name
						columns:            unique_columns
						characteristics:    table_element.characteristics
						nulls_not_distinct: table_element.nulls_not_distinct
					}
				}
			}
			LikeClause {
				// Replaced by with_like_columns.
			}
			ReferentialConstraintDefinition {
				// Each referencing column must be a column of the table, and only
				// once.
				//
				// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 8
				mut referencing_columns := []string{}
				for column in table_element.columns {
					if column.sub_entity_name in referencing_columns {
						return sqlstate_42601_table('column ${column.sub_entity_name} appears more than once in FOREIGN KEY', table_name)
					}
					if !stmt.has_column(column.sub_entity_name) {
						return sqlstate_42703(table_name, column.sub_entity_name)
					}
					check_groupable_column(column.sub_entity_name, stmt.column_type(column.sub_entity_name),
						'FOREIGN KEY')!
					referencing_columns << column.sub_entity_name
				}

				// A referenced column can't be given more than once. The rest of
				// the referenced table and columns are checked by
				// resolve_foreign_keys.
				//
				// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 4.a
				mut referenced_columns := []string{}
				for column in table_element.referenced_columns {
					if column.sub_entity_name in referenced_columns {
						return sqlstate_42601_table('column ${column.sub_entity_name} appears more than once in REFERENCES', table_name)
					}
					referenced_columns << column.sub_entity_name
				}

				foreign_keys << ForeignKey{
					name:               table_constraint_name(table_element.name, table_name)!
					columns:            referencing_columns
					referenced_table:   Identifier{
						...table_element.referenced_table
						catalog_name: if table_element.referenced_table.catalog_name == '' {
							table_name.catalog_name
						} else {
							table_element.referenced_table.catalog_name
						}
					}
					referenced_columns: referenced_columns
					// SIMPLE is the same as no MATCH.
					//
					// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 1
					match_type:         if table_element.match_type == 'SIMPLE' {
						''
					} else {
						table_element.match_type
					}
					// NO ACTION is the same as no ON UPDATE or ON DELETE.
					//
					// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 12 and 13
					update_rule:        if table_element.update_rule == 'NO ACTION' {
						''
					} else {
						table_element.update_rule
					}
					delete_rule:        if table_element.delete_rule == 'NO ACTION' {
						''
					} else {
						table_element.delete_rule
					}
					characteristics:    table_element.characteristics
				}
			}
		}
	}

	// Each unique constraint must have a different set of columns, in any order.
	//
	// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 6.c
	mut column_sets := map[string]bool{}
	mut all_unique_columns := [primary_key]
	all_unique_columns << unique_constraints.map(it.columns)
	for unique_columns in all_unique_columns {
		if unique_columns.len == 0 {
			continue
		}
		mut sorted := unique_columns.clone()
		sorted.sort()
		set := sorted.map(delimit_identifier(it)).join(', ')
		if set in column_sets {
			return sqlstate_42601_table('UNIQUE (${unique_columns.map(requote_identifier(it)).join(', ')}) has the same columns as another unique constraint', table_name)
		}
		column_sets[set] = true
	}

	// Columns in the PRIMARY KEY are implicitly NOT NULL, even when the
	// PRIMARY KEY is DEFERRABLE, because the column is known not nullable. Any
	// other column with a DEFERRABLE NOT NULL is nullable (see
	// Table.deferrable_not_nulls).
	//
	// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 8
	for i, column in columns {
		columns[i] = Column{
			...column
			not_null: column.name.sub_entity_name in primary_key
				|| (column.not_null && column.name.sub_entity_name !in deferrable_not_nulls)
		}
	}

	return Table{
		tid:                         tid
		name:                        table_name
		columns:                     columns
		primary_key:                 primary_key
		primary_key_name:            primary_key_name
		primary_key_characteristics: primary_key_characteristics
		not_null_names:              not_null_names
		deferrable_not_nulls:        deferrable_not_nulls
		check_constraints:           check_constraints
		unique_constraints:          unique_constraints
		foreign_keys:                foreign_keys
	}
}

// table_constraint_name is the name of a constraint of a table, or empty if it
// wasn't given one. The name can only be qualified by the schema of the table,
// which is also the schema of an unqualified name.
//
// ISO/IEC 9075-2:2023, 11.6, <table constraint definition>, Syntax Rules, 2
fn table_constraint_name(name Identifier, table_name Identifier) !string {
	if (name.catalog_name != '' && name.catalog_name != table_name.catalog_name)
		|| (name.schema_name != '' && name.schema_name != table_name.schema_name) {
		return sqlstate_42601_table('constraint ${name} must be in the same schema as table ${table_name}', table_name)
	}

	return name.entity_name
}

// column_type is the type of a column of the table elements, which must exist
// (see has_column).
fn (stmt TableDefinition) column_type(name string) Type {
	mut typ := Type{}
	for e in stmt.table_elements {
		if e is Column && e.name.sub_entity_name == name {
			typ = e.typ
		}
	}

	return typ
}

// check_groupable_column returns an error if a column of a PRIMARY KEY, UNIQUE
// or FOREIGN KEY can't be compared as a key, because its type is a CHARACTER
// LARGE OBJECT or BINARY LARGE OBJECT. Their values are stored outside of the
// row, so that they're only read when they're needed.
//
// ISO/IEC 9075-2:2023, 9.12, Grouping operations, Syntax Rules, 3
fn check_groupable_column(column string, typ Type, context string) ! {
	if typ.typ in [.is_clob, .is_blob] {
		return sqlstate_42601('column ${requote_identifier(column)} in ${context} cannot be a ${typ.typ}')
	}
}

// has_column is true if one of the table elements is the column.
fn (stmt TableDefinition) has_column(name string) bool {
	for e in stmt.table_elements {
		if e is Column && e.name.sub_entity_name == name {
			return true
		}
	}

	return false
}

fn (stmt TableDefinition) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE TABLE')
}
