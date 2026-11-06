// dump.v contains the functions for backing up a database as SQL and loading
// it again. See "vsql out" and "vsql in".

module vsql

import io
import strings

@[params]
pub struct DumpOptions {
pub:
	// create_public_schema includes CREATE SCHEMA "PUBLIC". It's not included
	// by default because every catalog already has it.
	create_public_schema bool
	// include only includes the objects (sequences, tables and foreign keys)
	// that match one of these "schema.name" patterns. Each part can have the
	// wildcards of string.match_glob, and case is ignored. Without any it's the
	// same as "*.*".
	include []string
	// exclude leaves out the objects that match one of these "schema.name"
	// patterns, even if they were in include. A foreign key isn't left out because
	// the table it references is, so the output might not load.
	exclude []string
	// transaction puts START TRANSACTION and COMMIT around the output, so that
	// loading it either works or doesn't change anything.
	transaction bool
	// compat changes the output so that it can be loaded by another database
	// instead of vsql. See DumpCompat.
	compat DumpCompat
	// data_only leaves out the definitions, so the output is only the rows and
	// the positions of the sequences. It can't be used with schema_only.
	data_only bool
	// schema_only leaves out the rows and the positions of the sequences, so the
	// output is only the definitions. It can't be used with data_only.
	schema_only bool
	// no_schema leaves the schema out of every name, and doesn't write CREATE SCHEMA,
	// so the output goes into the current schema of whatever loads it. Tables with
	// the same name in different schemas will have the same name in the output.
	// It can't be used with create_public_schema.
	no_schema bool
}

// output_name is the name of an object as it's written.
fn (o DumpOptions) output_name(name Identifier) Identifier {
	return if o.no_schema {
		Identifier{
			...name
			schema_name: ''
		}
	} else {
		name
	}
}

// output_foreign_key is a FOREIGN KEY as it's written.
fn (o DumpOptions) output_foreign_key(key ForeignKey) ForeignKey {
	return ForeignKey{
		...key
		referenced_table: o.output_name(key.referenced_table)
	}
}

// output_definition is the definition of a table as it's written. A column in a CHECK
// or generated column can be qualified with the schema. A string isn't changed.
fn (o DumpOptions) output_definition(definition string, name Identifier) string {
	if !o.no_schema {
		return definition
	}

	mut prefixes := map[string]string{}
	for schema in [name.schema_name, delimit_identifier(name.schema_name)] {
		for table in [name.entity_name, delimit_identifier(name.entity_name)] {
			prefixes['${schema}.${table}.'] = '${table}.'
		}
	}

	mut sb := strings.new_builder(definition.len)
	mut in_string := false
	mut i := 0
	outer: for i < definition.len {
		c := definition[i]
		if c == `'` {
			in_string = !in_string
		}
		is_start := i == 0 || !(definition[i - 1].is_letter() || definition[i - 1].is_digit()
			|| definition[i - 1] in [`_`, `.`, `"`])
		if !in_string && is_start {
			for prefix, replacement in prefixes {
				if definition[i..].starts_with(prefix) {
					sb.write_string(replacement)
					i += prefix.len
					continue outer
				}
			}
		}
		sb.write_u8(c)
		i++
	}

	return sb.str()
}

// DumpPattern is a "schema.name" pattern for an object, or an empty schema if
// the name is "*". Each part can have the wildcards of string.match_glob, and
// case is ignored.
struct DumpPattern {
	schema string
	name   string
}

fn new_dump_pattern(pattern string) !DumpPattern {
	parts := pattern.to_upper().split('.')
	if parts.len != 2 || parts[0] == '' || parts[1] == '' {
		return error('${pattern}: must be in the form schema.name')
	}

	return DumpPattern{parts[0], parts[1]}
}

fn new_dump_patterns(patterns []string) ![]DumpPattern {
	mut result := []DumpPattern{}
	for pattern in patterns {
		result << new_dump_pattern(pattern)!
	}

	return result
}

fn (p DumpPattern) schema_matches(schema string) bool {
	return schema.to_upper().match_glob(p.schema)
}

fn (p DumpPattern) matches(schema string, name string) bool {
	return p.schema_matches(schema) && name.to_upper().match_glob(p.name)
}

// DumpFilter is the patterns of DumpOptions.
struct DumpFilter {
	include []DumpPattern
	exclude []DumpPattern
}

// selected is whether an object is in the output.
fn (f DumpFilter) selected(schema string, name string) bool {
	return f.include.any(it.matches(schema, name)) && !f.exclude.any(it.matches(schema, name))
}

// empty_schema_selected is whether a schema without any objects is in the
// output. It has no name to match, so only its schema counts, and an exclude
// has to be for all of the schema.
fn (f DumpFilter) empty_schema_selected(schema string) bool {
	return f.include.any(it.schema_matches(schema))
		&& !f.exclude.any(it.name == '*' && it.schema_matches(schema))
}

// DumpSchema is the objects of a schema, ordered by name.
struct DumpSchema {
	schema    Schema
	sequences []Sequence
	tables    []Table
	// indexes are the indexes of the tables, by table name then index name,
	// other than the index of a UNIQUE constraint (which is made by its CREATE
	// TABLE). An index is in the output with its table.
	indexes []Index
}

// table_indexes are the indexes of a table, by name.
fn (s DumpSchema) table_indexes(table Table) []Index {
	return s.indexes.filter(it.table_name.entity_name == table.name.entity_name)
}

// matches is whether a pattern selects anything in the schema.
fn (s DumpSchema) matches(pattern DumpPattern) bool {
	names := s.names()

	return names.any(pattern.matches(s.schema.name, it))
		|| (names.len == 0 && pattern.schema_matches(s.schema.name))
}

// names is the name of each object.
fn (s DumpSchema) names() []string {
	mut names := s.sequences.map(it.name.entity_name)
	for table in s.tables {
		names << table.name.entity_name
		names << table.foreign_keys.map(it.name)
	}

	return names
}

// dump writes the schemas, sequences, tables and rows of the current catalog
// as SQL. The output can be loaded into a new database by running each
// statement from split_statements. A pattern of include that doesn't match
// anything is an error, and INFORMATION_SCHEMA can't be included.
pub fn (mut conn Connection) dump(mut w io.Writer, options DumpOptions) ! {
	// The FOREIGN KEYs are added once all of the tables and rows have been
	// loaded, because a table can reference a table that comes after it, or a
	// row that comes after it in the same table.
	mut foreign_keys := []string{}
	if options.data_only && options.schema_only {
		return error('data_only and schema_only cannot be used together')
	}
	if options.no_schema && options.create_public_schema {
		return error('no_schema and create_public_schema cannot be used together')
	}
	mut catalog := conn.catalog()
	// Virtual schemas and tables aren't in the file.
	mut schemas := catalog.schemas()!.filter(!it.is_virtual)

	for pattern in options.include {
		if pattern.to_upper().all_before('.') == 'INFORMATION_SCHEMA' {
			return error('${pattern}: INFORMATION_SCHEMA cannot be included')
		}
	}
	selection := DumpFilter{
		include: new_dump_patterns(if options.include.len == 0 {
			['*.*']
		} else {
			options.include
		})!
		exclude: new_dump_patterns(options.exclude)!
	}

	// To make the output more deterministic, entities will be ordered by name
	// (not how the name is printed, which may be quoted). This is not true for
	// the records however, which can potentially come out in any order.
	schemas.sort_with_compare(fn (a &Schema, b &Schema) int {
		return a.name.compare(b.name)
	})

	// The objects are read first so that a bad pattern doesn't leave half of the
	// output behind.
	mut objects := []DumpSchema{}
	for schema in schemas {
		mut sequences := catalog.sequences(schema.name)!
		sequences.sort_with_compare(fn (a &Sequence, b &Sequence) int {
			return a.name.entity_name.compare(b.name.entity_name)
		})

		mut tables := catalog.schema_tables(schema.name)!.filter(!it.is_virtual)
		tables.sort_with_compare(fn (a &Table, b &Table) int {
			return a.name.entity_name.compare(b.name.entity_name)
		})
		schema_indexes := catalog.indexes(schema.name)!
		mut indexes := []Index{}
		for table in tables {
			for index in schema_indexes {
				// The index that a FOREIGN KEY made for itself also needs the
				// FOREIGN KEY to be selected, otherwise nothing would use it.
				if index.table_name.entity_name == table.name.entity_name
					&& !table.is_constraint_index(index) && (!table.is_foreign_key_index(index)
					|| selection.selected(schema.name, index.name.entity_name)) {
					indexes << index
				}
			}
		}
		objects << DumpSchema{schema, sequences, tables, indexes}
	}

	for pattern in options.include {
		parsed := new_dump_pattern(pattern)!
		if !objects.any(it.matches(parsed)) {
			return error('${pattern}: does not match anything')
		}
	}

	if options.compat != .vsql {
		return conn.dump_compat(mut w, objects, selection, options)
	}

	if options.transaction {
		write_line(mut w, 'START TRANSACTION;\n')!
	}

	for object in objects {
		schema := object.schema
		names := object.names()
		// We avoid "CREATE SCHEMA PUBLIC;" because it would break the import.
		// Although, create_public_schema can be used to enable it when dealing
		// with other databases.
		if !options.data_only && !options.no_schema
			&& (schema.name != 'PUBLIC' || options.create_public_schema)
			&& (names.any(selection.selected(schema.name, it))
				|| (names.len == 0 && selection.empty_schema_selected(schema.name))) {
			write_line(mut w, '${schema}\n')!
		}

		for sequence in object.sequences.filter(selection.selected(schema.name, it.name.entity_name)) {
			if !options.data_only {
				write_line(mut w, '${Sequence{ ...sequence, name: options.output_name(sequence.name) }}\n')!
			}
			if options.schema_only {
				continue
			}

			// START WITH is kept for RESTART, so the current position (if it has
			// moved) needs to be restored separately. A sequence that has been used
			// returns its last value again, so that it's still used (which matters
			// for ALTER SEQUENCE, see Sequence.unused).
			name := options.output_name(sequence.name).storage_sql()
			if sequence.unused {
				next_value := sequence.next_value() or { sequence.start_value }
				if next_value != sequence.start_value {
					write_line(mut w, 'ALTER SEQUENCE ${name} RESTART WITH ${next_value};\n')!
				}
			} else {
				write_line(mut w, 'ALTER SEQUENCE ${name} RESTART WITH ${sequence.current_value};')!
				write_line(mut w, 'SELECT NEXT VALUE FOR ${name} FROM (VALUES 1) AS t;\n')!
			}
		}

		// A foreign key is selected separately from its table.
		for table in object.tables {
			name := options.output_name(table.name).storage_sql()
			for key in table.foreign_keys {
				if !options.data_only && selection.selected(schema.name, key.name) {
					foreign_keys << 'ALTER TABLE ${name} ADD CONSTRAINT ${delimit_identifier(key.name)} ${options.output_foreign_key(key)};'
				}
			}
		}

		for table in object.tables.filter(selection.selected(schema.name, it.name.entity_name)) {
			if !options.data_only {
				// A column in a CHECK or generation expression can be qualified with
				// just the table name, which is only found in the table's schema if
				// that's the current schema when the table is created.
				is_schema_needed := !options.no_schema
					&& table.name.schema_name != default_schema_name
					&& (table.check_constraints.len > 0 || table.columns.any(it.generated != none))
				if is_schema_needed {
					write_line(mut w, 'SET SCHEMA ${new_varchar_value(table.name.schema_name).literal()};')!
				}
				write_line(mut w, options.output_definition(Table{
					...table
					name:         options.output_name(table.name)
					foreign_keys: []ForeignKey{}
				}.str(), table.name) + '\n')!
				if is_schema_needed {
					write_line(mut w, "SET SCHEMA '${default_schema_name}';\n")!
				}
			}
			if options.schema_only {
				if write_indexes(mut w, object.table_indexes(table), options)! {
					write_line(mut w, '')!
				}
				continue
			}

			name := options.output_name(table.name).storage_sql()
			// A generated column can't be inserted, it's set again from the
			// other columns.
			mut column_names := []string{}
			for col in table.columns {
				if col.generated == none {
					column_names << col.name.sub_entity_name
				}
			}
			columns := column_names.map(delimit_identifier(it)).join(', ')

			// The values of a GENERATED ALWAYS identity column can only be
			// inserted with OVERRIDING SYSTEM VALUE.
			identity_column := table.identity_column()
			mut overriding := ''
			if column := identity_column {
				if (column.identity or { IdentityColumn{} }).always {
					overriding = ' OVERRIDING SYSTEM VALUE'
				}
			}

			for row in conn.query('SELECT * FROM ${table.name.storage_sql()}')! {
				mut data := []string{}
				for col in column_names {
					data << (row.get(col)!).literal()
				}

				write_line(mut w, 'INSERT INTO ${name} (${columns})${overriding} VALUES (${data.join(', ')});')!
			}

			// The indexes are created after the rows, so that each one is built
			// once.
			if !options.data_only {
				write_indexes(mut w, object.table_indexes(table), options)!
			}

			// Inserting the rows doesn't move the sequence of the identity
			// column, so it's restarted at the value that the next row would
			// get. A sequence that has reached its limit (without CYCLE) can't
			// be restored, so it's restarted at its last value instead, which
			// is the closest it can be.
			if column := identity_column {
				sequence := catalog.identity_sequence(table)!
				next_value := (sequence.next() or { sequence }).current_value
				if !sequence.unused || next_value != sequence.start_value {
					write_line(mut w, 'ALTER TABLE ${name} ALTER COLUMN ${delimit_identifier(column.name.sub_entity_name)} RESTART WITH ${next_value};')!
				}
			}

			write_line(mut w, '')!
		}
	}

	for foreign_key in foreign_keys {
		write_line(mut w, foreign_key)!
	}

	if options.transaction {
		if foreign_keys.len > 0 {
			write_line(mut w, '')!
		}
		write_line(mut w, 'COMMIT;')!
	}
}

// write_indexes writes the CREATE INDEX of each index, and returns true if
// there were any.
fn write_indexes(mut w io.Writer, indexes []Index, options DumpOptions) !bool {
	for index in indexes {
		write_line(mut w, Index{
			...index
			table_name: options.output_name(index.table_name)
		}.str())!
	}

	return indexes.len > 0
}

fn write_line(mut w io.Writer, line string) ! {
	w.write('${line}\n'.bytes())!
}

// split_statements splits a SQL script into its statements, which are separated
// by semicolons. A semicolon inside a string, a delimited identifier or a
// comment doesn't end the statement. The statements are returned without the
// semicolon, and empty statements (including ones that are only comments) are
// left out.
pub fn split_statements(script string) []string {
	mut statements, rest := split_terminated_statements(script)
	if rest != '' {
		statements << rest.trim_space()
	}

	return statements
}

// split_terminated_statements is split_statements for statements that must end
// with a semicolon, such as a <direct SQL statement>. The text after the last
// semicolon is returned separately (as it is, so that more text can be appended
// to it), or an empty string if it's only white space and comments.
pub fn split_terminated_statements(script string) ([]string, string) {
	ranges, rest := statement_ranges(script)

	return ranges.map(script[it.start..it.end].trim_space()), if rest.first < 0 {
		''
	} else {
		script[rest.start..]
	}
}

// StatementRange is where a statement is in a script.
pub struct StatementRange {
pub:
	// start is the position after the semicolon before it, and end is the position
	// of its semicolon.
	start int
	end   int
	// first is the position of the first thing that isn't white space or a comment.
	first int
}

// statement_ranges finds the statements of a script that end with a semicolon,
// leaving out empty ones (including ones that are only comments). The range of the
// text after the last semicolon is returned separately. Its first is less than
// zero if there's nothing but white space and comments, which might be because more
// of the script is still to come.
pub fn statement_ranges(script string) ([]StatementRange, StatementRange) {
	mut ranges := []StatementRange{}
	mut start := 0
	mut first := -1
	mut quote := u8(0)
	mut comment_depth := 0
	mut i := 0
	for i < script.len {
		c := script[i]
		next := if i + 1 < script.len { script[i + 1] } else { u8(0) }
		if quote != 0 {
			// A doubled quote ('' or "") is read as two strings next to each
			// other, which is the same for finding the end of the statement.
			if c == quote {
				quote = 0
			}
		} else if comment_depth > 0 {
			// Bracketed comments can be nested, like in skip_comment.
			if c == `/` && next == `*` {
				comment_depth++
				i++
			} else if c == `*` && next == `/` {
				comment_depth--
				i++
			}
		} else if c == `-` && next == `-` {
			for i < script.len && script[i] != `\n` {
				i++
			}
			continue
		} else if c == `/` && next == `*` {
			comment_depth = 1
			i++
		} else if c == `;` {
			if first >= 0 {
				ranges << StatementRange{start, i, first}
			}
			start = i + 1
			first = -1
		} else if !c.is_space() {
			if c == `'` || c == `"` {
				quote = c
			}
			if first < 0 {
				first = i
			}
		}
		i++
	}

	// An unterminated string or comment isn't finished, even if it's empty.
	if first < 0 && comment_depth > 0 {
		first = start
	}

	return ranges, StatementRange{start, script.len, first}
}
