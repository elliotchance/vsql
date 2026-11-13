// dump_compat.v writes a dump that can be loaded by another database. See
// DumpOptions.compat and "vsql out -compat".

module vsql

import io

// DumpCompat is the database that a dump is written for.
pub enum DumpCompat {
	vsql
	sqlite3
	mysql
	postgresql
}

// dump_compat_keywords are the words of an expression
// (other than the names of columns) that mean the same in every database.
const dump_compat_keywords = ['AND', 'BETWEEN', 'FALSE', 'IN', 'IS', 'LIKE', 'NOT', 'NULL', 'OR',
	'TRUE', 'ABS', 'COALESCE', 'LOWER', 'NULLIF', 'UPPER']

// compat_name is the name of a schema, table, column or constraint. A name that
// wasn't delimited is stored in upper case, but it's lower case in the other
// databases (or at least that's how it's usually written), so that "SELECT *
// FROM foo" still works. It's always delimited because it might be a reserved
// word there. MySQL understands this because of ANSI_QUOTES, see dump_compat.
fn compat_name(name string) string {
	return delimit_identifier(if name == name.to_upper() && is_regular_identifier(name) {
		name.to_lower()
	} else {
		name
	})
}

// compat_comment is a line of the output about something that couldn't be kept.
fn compat_comment(comment string) string {
	return '-- ${comment.replace_each(['\r', ' ', '\n', ' '])}'
}

// table_sql is the name of a table or sequence. PUBLIC is the default schema of
// the connection that's loading the file. SQLite doesn't have schemas (ATTACH
// isn't kept with the file), so the schema becomes part of the name.
fn (c DumpCompat) table_sql(name Identifier) string {
	if name.schema_name in ['', 'PUBLIC'] {
		return compat_name(name.entity_name)
	}
	if c == .sqlite3 {
		return compat_name('${name.schema_name}_${name.entity_name}')
	}

	return '${compat_name(name.schema_name)}.${compat_name(name.entity_name)}'
}

// type_sql is the closest type of the database. Types are shown in the table of
// "vsql out" in docs/cli.rst.
fn (c DumpCompat) type_sql(t Type) string {
	return match c {
		.sqlite3 {
			match t.typ {
				.is_date { 'DATE' }
				.is_time_with_time_zone, .is_time_without_time_zone { 'TIME' }
				.is_timestamp_with_time_zone, .is_timestamp_without_time_zone { 'TIMESTAMP' }
				.is_binary, .is_varbinary { 'BLOB' }
				else { t.str() }
			}
		}
		.postgresql {
			if t.typ.is_binary_string() { 'BYTEA' } else { t.str() }
		}
		.mysql {
			match t.typ {
				.is_character, .is_varchar {
					// A long VARCHAR is limited by the size of the row, and CHAR is limited
					// to 255.
					if (t.size == 0 && t.typ == .is_varchar) || t.size > 768 {
						'LONGTEXT'
					} else if t.typ == .is_character && t.size <= 255 {
						t.str()
					} else {
						'VARCHAR(${t.size})'
					}
				}
				.is_varbinary {
					'VARBINARY(${t.size})'
				}
				// REAL is a DOUBLE in MySQL.
				.is_real {
					'FLOAT'
				}
				// A DECIMAL without a precision is DECIMAL(10, 0) in MySQL.
				.is_decimal, .is_numeric {
					if t.size == 0 { 'DECIMAL(65, 30)' } else { t.str() }
				}
				.is_time_without_time_zone {
					'TIME(${t.size})'
				}
				// There's no type for this, so that the offset isn't lost.
				.is_time_with_time_zone {
					'VARCHAR(30)'
				}
				// TIMESTAMP in MySQL is only from 1970 to 2038.
				.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
					'DATETIME(${t.size})'
				}
				else {
					t.str()
				}
			}
		}
		else {
			t.str()
		}
	}
}

// string_sql is a literal that might be a string. A backslash in MySQL is an
// escape. NO_BACKSLASH_ESCAPES can't be used because MySQL reads a DEFAULT with
// a quote in it back as if it wasn't set.
fn (c DumpCompat) string_sql(literal string) string {
	return if c == .mysql { literal.replace('\\', '\\\\') } else { literal }
}

// literal_sql is a value in a statement. PostgreSQL ignores the offset of a
// TIMESTAMP '...' literal, so it needs to know it has one. MySQL and SQLite take
// a string.
fn (c DumpCompat) literal_sql(v Value) string {
	literal := v.literal()

	// X'...' is a bit string in PostgreSQL.
	if c == .postgresql && v.typ.uses_bytes() && !v.is_null {
		return "'\\x${v.str()}'::BYTEA"
	}

	if v.is_null || !v.typ.typ.is_datetime() {
		return c.string_sql(literal)
	}

	quoted := literal[literal.index_u8(`'`)..]
	if c != .postgresql {
		return quoted
	}

	return match v.typ.typ {
		.is_timestamp_with_time_zone { 'TIMESTAMP WITH TIME ZONE ${quoted}' }
		.is_time_with_time_zone { 'TIME WITH TIME ZONE ${quoted}' }
		else { literal }
	}
}

// default_sql is the expression of a DEFAULT, or none if the database doesn't
// have one that's the same.
fn (c DumpCompat) default_sql(option DefaultOption) ?string {
	sql_text := match option {
		Value {
			c.literal_sql(option)
		}
		NullSpecification {
			'NULL'
		}
		DatetimeValueFunction {
			sql_function := option.pstr(map[string]Value{})
			if c == .sqlite3 {
				if sql_function.contains('DATE') {
					'CURRENT_DATE'
				} else if sql_function.contains('TIMESTAMP') {
					'CURRENT_TIMESTAMP'
				} else {
					'CURRENT_TIME'
				}
			} else {
				sql_function
			}
		}
		CurrentCatalog {
			if c != .postgresql {
				return none
			}
			'CURRENT_CATALOG'
		}
		CurrentSchema {
			if c != .postgresql {
				return none
			}
			'CURRENT_SCHEMA'
		}
	}

	// A LONGTEXT or a function can only be a DEFAULT in parentheses.
	return if c == .mysql { '(${sql_text})' } else { sql_text }
}

// expression_sql is the expression of a CHECK or generated column for the
// other databases, or none if there's anything in it that might not work, or
// not be the same, such as most functions or the division of integers.
fn (c DumpCompat) expression_sql(expr string, columns []string) ?string {
	mut result := []u8{}
	mut i := 0
	for i < expr.len {
		first := expr[i]
		start := i
		if first == `'` || first == `"` {
			i++
			for i < expr.len && expr[i] != first {
				i++
			}
			i++
			if first == `'` {
				result << c.string_sql(expr[start..i]).bytes()
				continue
			}
			name := expr[start + 1..i - 1].replace('""', '"')
			if name !in columns {
				return none
			}
			result << compat_name(name).bytes()
		} else if first.is_letter() || first == `_` {
			for i < expr.len && (expr[i].is_letter() || expr[i].is_digit() || expr[i] == `_`) {
				i++
			}
			word := expr[start..i]
			if word in columns {
				result << compat_name(word).bytes()
			} else if word in dump_compat_keywords {
				result << word.bytes()
			} else {
				return none
			}
		} else if first.is_digit() {
			for i < expr.len && (expr[i].is_digit() || expr[i] == `.` || expr[i] in [
				`e`,
				`E`,
			]
				|| (expr[i] in [`+`, `-`] && expr[i - 1] in [`e`, `E`])) {
				i++
			}
			result << expr[start..i].bytes()
		} else if first in [` `, `(`, `)`, `,`, `+`, `-`, `*`, `=`, `<`, `>`, `|`] {
			result << first
			i++
		} else {
			return none
		}
	}

	return result.bytestr()
}

// characteristics_sql is what's kept of the characteristics of a UNIQUE or
// FOREIGN KEY. Only PostgreSQL has them all.
fn (c DumpCompat) characteristics_sql(characteristics ConstraintCharacteristics) string {
	return if c == .postgresql { characteristics.str() } else { '' }
}

// is_kept_identity is whether the identity column can be AUTO_INCREMENT (for
// MySQL) or AUTOINCREMENT (for SQLite), which only count up by 1 and have to be
// an integer. In SQLite it also has to be the only column of the PRIMARY KEY.
fn (c DumpCompat) is_kept_identity(table Table, col Column) bool {
	identity := col.identity or { return false }
	if c == .postgresql {
		return true
	}

	return col.typ.typ in [.is_smallint, .is_integer, .is_bigint]
		&& identity.sequence.increment_by == 1
		&& (c == .mysql || table.primary_key == [col.name.sub_entity_name])
}

// is_kept_generated is whether the generated column is still generated. If it's
// not, it's a normal column, and the rows have its values.
fn (c DumpCompat) is_kept_generated(table Table, col Column) bool {
	generated := col.generated or { return false }

	return c.expression_sql(generated.expr.pstr(map[string]Value{}), table.column_names()) != none
}

// compat_constraint_name is the CONSTRAINT clause (followed by a space) of a constraint
// that has a name of its own.
fn compat_constraint_name(name string, default_name string) string {
	return if name == default_name { '' } else { 'CONSTRAINT ${compat_name(name)} ' }
}

// foreign_key_sql is the FOREIGN KEY, with its name. InnoDB doesn't have SET
// DEFAULT, so it's the same as if it wasn't given.
fn (c DumpCompat) foreign_key_sql(key ForeignKey) string {
	mut s := 'CONSTRAINT ${compat_name(key.name)} FOREIGN KEY (${key.columns.map(compat_name(it)).join(', ')}) REFERENCES ${c.table_sql(key.referenced_table)} (${key.referenced_columns.map(compat_name(it)).join(', ')})'
	if key.update_rule != '' && !(c == .mysql && key.update_rule == 'SET DEFAULT') {
		s += ' ON UPDATE ${key.update_rule}'
	}
	if key.delete_rule != '' && !(c == .mysql && key.delete_rule == 'SET DEFAULT') {
		s += ' ON DELETE ${key.delete_rule}'
	}

	return s + c.characteristics_sql(key.characteristics)
}

// create_table_sql is the lines of the CREATE TABLE, after a comment for each
// thing that couldn't be kept. SQLite can't add a FOREIGN KEY later, so
// foreign_keys are part of the definition.
fn (c DumpCompat) create_table_sql(table Table, foreign_keys []ForeignKey) []string {
	columns := table.column_names()
	mut comments := []string{}
	mut elements := []string{}
	for col in table.columns {
		name := col.name.sub_entity_name
		mut column_type := c.type_sql(col.typ)
		mut clauses := ''
		if default_value := col.default_value {
			if sql_text := c.default_sql(default_value) {
				clauses += ' DEFAULT ${sql_text}'
			} else {
				comments << 'The DEFAULT of ${compat_name(name)} is left out: ${*default_value}'
			}
		}
		if generated := col.generated {
			expr := generated.expr.pstr(map[string]Value{})
			if sql_text := c.expression_sql(expr, columns) {
				clauses += ' GENERATED ALWAYS AS (${sql_text}) STORED'
			} else {
				comments << 'The generated column ${compat_name(name)} is a normal column: ${expr}'
			}
		}
		if identity := col.identity {
			if !c.is_kept_identity(table, col) {
				comments << 'The identity column ${compat_name(name)} is a normal column.'
			} else if c == .postgresql {
				// An identity column can't be a DECIMAL or NUMERIC.
				if col.typ.typ in [.is_decimal, .is_numeric] {
					column_type = 'BIGINT'
				}
				clauses += ' ${*identity}'
			} else if c == .mysql {
				clauses += ' AUTO_INCREMENT'
			} else {
				// It's only AUTOINCREMENT if the type is exactly INTEGER.
				column_type = 'INTEGER'
				clauses += ' PRIMARY KEY AUTOINCREMENT'
			}
		}
		if col.not_null {
			clauses += ' NOT NULL'
		}
		elements << '${compat_name(name)} ${column_type}${clauses}'
	}

	// In SQLite the PRIMARY KEY is on the identity column.
	identity_column := table.identity_column() or { Column{} }
	if table.primary_key.len > 0 && !(c == .sqlite3 && c.is_kept_identity(table, identity_column)) {
		elements << '${compat_constraint_name(table.primary_key_name, constraint_name(table, 'PRIMARY_KEY', 0))}PRIMARY KEY (${table.primary_key.map(compat_name(it)).join(', ')})'
	}

	for i, constraint in table.unique_constraints {
		elements << '${compat_constraint_name(constraint.name, constraint_name(table, 'UNIQUE', i))}UNIQUE (${constraint.columns.map(compat_name(it)).join(', ')})${c.characteristics_sql(constraint.characteristics)}'
	}

	// AUTO_INCREMENT has to be the first column of a key.
	if c == .mysql && c.is_kept_identity(table, identity_column) {
		name := identity_column.name.sub_entity_name
		if !(table.primary_key.len > 0 && table.primary_key[0] == name)
			&& !table.unique_constraints.any(it.columns[0] == name) {
			elements << 'KEY (${compat_name(name)})'
		}
	}

	for key in foreign_keys {
		elements << c.foreign_key_sql(key)
	}

	for i, constraint in table.check_constraints {
		expr := constraint.search_condition.pstr(map[string]Value{})
		if sql_text := c.expression_sql(expr, columns) {
			elements << '${compat_constraint_name(constraint.name.entity_name, constraint_name(table, 'CHECK', i))}CHECK (${sql_text})'
		} else {
			comments << 'A CHECK is left out: ${expr}'
		}
	}

	mut lines := comments.map(compat_comment(it))
	lines << 'CREATE TABLE ${c.table_sql(table.name)} (\n  ${elements.join(',\n  ')}\n);'

	return lines
}

// create_index_sql is the CREATE INDEX of an index of table, or a comment if it
// can't be kept. An index is always in the schema of its table, so the name
// isn't qualified, except that SQLite has no schemas (see table_sql).
fn (c DumpCompat) create_index_sql(table Table, index Index) string {
	if c == .mysql {
		// InnoDB can't index a LONGTEXT, and the key can be up to 3072 bytes (a
		// character can be up to 4 bytes).
		mut size := 0
		for column in index.columns {
			typ := (table.column(column.name) or { Column{} }).typ
			if c.type_sql(typ) == 'LONGTEXT' {
				return compat_comment('The index ${compat_name(index.name.entity_name)} is left out, a LONGTEXT column (${compat_name(column.name)}) cannot be indexed.')
			}
			if typ.typ in [.is_character, .is_varchar] {
				size += 4 * typ.size
			}
		}
		if size > 3072 {
			return compat_comment('The index ${compat_name(index.name.entity_name)} is left out, its key can be over 3072 bytes.')
		}
	}

	name := if c == .sqlite3 {
		c.table_sql(Identifier{
			...index.name
			schema_name: table.name.schema_name
		})
	} else {
		compat_name(index.name.entity_name)
	}
	unique := if index.unique { 'UNIQUE ' } else { '' }
	columns := index.columns.map(if it.desc {
		'${compat_name(it.name)} DESC'
	} else {
		compat_name(it.name)
	})

	return 'CREATE ${unique}INDEX ${name} ON ${c.table_sql(table.name)} (${columns.join(', ')});'
}

// identity_restart_sql is the statements that make the identity column continue
// from next_value, because inserting the rows doesn't move it.
fn (c DumpCompat) identity_restart_sql(table Table, column Column, next_value i64) []string {
	name := c.table_sql(table.name)
	return match c {
		.mysql {
			['ALTER TABLE ${name} AUTO_INCREMENT = ${next_value};']
		}
		.sqlite3 {
			text := name.trim('"').replace('""', '"').replace("'", "''")
			["DELETE FROM sqlite_sequence WHERE name = '${text}';",
				"INSERT INTO sqlite_sequence (name, seq) VALUES ('${text}', ${next_value - 1});"]
		}
		else {
			['ALTER TABLE ${name} ALTER COLUMN ${compat_name(column.name.sub_entity_name)} RESTART WITH ${next_value};']
		}
	}
}

// dump_compat is Connection.dump for another database. It's the same order, but
// what the database doesn't have is left out with a comment. See the section
// on -compat in docs/cli.rst.
fn (mut conn Connection) dump_compat(mut w io.Writer, objects []DumpSchema, selection DumpFilter, options DumpOptions) ! {
	c := options.compat
	mut catalog := conn.catalog()
	mut foreign_keys := []string{}

	if c == .sqlite3 {
		// The rows of a table can come before the table they reference. This
		// doesn't do anything inside of a transaction.
		write_line(mut w, 'PRAGMA foreign_keys = OFF;')!
	}
	if c == .mysql {
		// These only last for the connection. A datetime that has an offset is
		// stored as UTC.
		write_line(mut w, "SET SESSION sql_mode = 'ANSI_QUOTES,NO_AUTO_VALUE_ON_ZERO,PIPES_AS_CONCAT,STRICT_ALL_TABLES';")!
		write_line(mut w, "SET SESSION time_zone = '+00:00';")!
	}
	if options.transaction {
		write_line(mut w, if c == .sqlite3 { 'BEGIN TRANSACTION;' } else { 'START TRANSACTION;' })!
	}
	if c != .postgresql || options.transaction {
		write_line(mut w, '')!
	}

	for object in objects {
		schema := object.schema
		names := object.names()
		if c != .sqlite3 && !options.data_only && !options.no_schema && schema.name != 'PUBLIC'
			&& (names.any(selection.selected(schema.name, it))
				|| (names.len == 0 && selection.empty_schema_selected(schema.name))) {
			write_line(mut w, 'CREATE SCHEMA ${compat_name(schema.name)};\n')!
		}

		for sequence in object.sequences.filter(selection.selected(schema.name, it.name.entity_name)) {
			name := c.table_sql(options.output_name(sequence.name))
			if c != .postgresql {
				write_line(mut w, compat_comment('The sequence ${name} is left out, its next value is ${sequence.next_value() or { sequence.current_value }}.') +
					'\n')!
				continue
			}
			if !options.data_only {
				definition := sequence.str().all_after(sequence.name.storage_sql())
				write_line(mut w, 'CREATE SEQUENCE ${name}${definition}\n')!
			}
			if options.schema_only {
				continue
			}
			if !sequence.unused {
				write_line(mut w, "SELECT setval('${name.replace("'", "''")}', ${sequence.current_value});\n")!
				continue
			}
			next_value := sequence.next_value() or { sequence.start_value }
			if next_value != sequence.start_value {
				write_line(mut w, 'ALTER SEQUENCE ${name} RESTART WITH ${next_value};\n')!
			}
		}

		// A foreign key is selected separately from its table.
		if !options.data_only && c != .sqlite3 {
			for table in object.tables {
				for key in table.foreign_keys {
					if selection.selected(schema.name, key.name) {
						foreign_keys << 'ALTER TABLE ${c.table_sql(options.output_name(table.name))} ADD ${c.foreign_key_sql(options.output_foreign_key(key))};'
					}
				}
			}
		}

		for table in object.tables.filter(selection.selected(schema.name, it.name.entity_name)) {
			if !options.data_only {
				keys := if c == .sqlite3 {
					table.foreign_keys.filter(selection.selected(schema.name, it.name))
				} else {
					[]ForeignKey{}
				}
				definition := c.create_table_sql(Table{
					...table
					name: options.output_name(table.name)
				}, keys.map(options.output_foreign_key(it))).join('\n')
				write_line(mut w, options.output_definition(definition, table.name))!
			}
			if !options.schema_only {
				name := c.table_sql(options.output_name(table.name))
				mut column_names := []string{}
				for col in table.columns {
					if col.generated == none || !c.is_kept_generated(table, col) {
						column_names << col.name.sub_entity_name
					}
				}
				columns := column_names.map(compat_name(it)).join(', ')

				identity_column := table.identity_column()
				mut overriding := ''
				if column := identity_column {
					if c == .postgresql && (column.identity or { &IdentityColumn{} }).always {
						overriding = ' OVERRIDING SYSTEM VALUE'
					}
				}

				for row in conn.query('SELECT * FROM ${table.name.storage_sql()}')! {
					mut data := []string{}
					for col in column_names {
						data << c.literal_sql(row.get(col)!)
					}
					write_line(mut w, 'INSERT INTO ${name} (${columns})${overriding} VALUES (${data.join(', ')});')!
				}

				if column := identity_column {
					sequence := catalog.identity_sequence(table)!
					next_value := (sequence.next() or { sequence }).current_value
					if c.is_kept_identity(table, column)
						&& (!sequence.unused || next_value != sequence.start_value) {
						write_line(mut w, c.identity_restart_sql(Table{
							...table
							name: options.output_name(table.name)
						}, column, next_value).join('\n'))!
					}
				}
			}
			// The indexes are created after the rows, like Connection.dump.
			if !options.data_only {
				for index in object.table_indexes(table) {
					write_line(mut w, c.create_index_sql(Table{
						...table
						name: options.output_name(table.name)
					}, index))!
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
