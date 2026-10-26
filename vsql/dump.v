// dump.v contains the functions for backing up a database as SQL and loading
// it again. See "vsql out" and "vsql in".

module vsql

import io

@[params]
pub struct DumpOptions {
pub:
	// create_public_schema includes CREATE SCHEMA "PUBLIC". It's not included
	// by default because every catalog already has it.
	create_public_schema bool
}

// dump writes the schemas, sequences, tables and rows of the current catalog
// as SQL. The output can be loaded into a new database by running each
// statement from split_statements.
pub fn (mut conn Connection) dump(mut w io.Writer, options DumpOptions) ! {
	// The FOREIGN KEYs are added once all of the tables and rows have been
	// loaded, because a table can reference a table that comes after it, or a
	// row that comes after it in the same table.
	mut foreign_keys := []string{}
	mut catalog := conn.catalog()
	mut schemas := catalog.schemas()!

	// To make the output more deterministic, entities will be ordered by name
	// (not how the name is printed, which may be quoted). This is not true for
	// the records however, which can potentially come out in any order.
	schemas.sort_with_compare(fn (a &Schema, b &Schema) int {
		return a.name.compare(b.name)
	})

	for _, schema in schemas {
		// We avoid "CREATE SCHEMA PUBLIC;" because it would break the import.
		// Although, create_public_schema can be used to enable it when dealing
		// with other databases.
		if schema.name != 'PUBLIC' || options.create_public_schema {
			write_line(mut w, '${schema}\n')!
		}

		mut sequences := catalog.sequences(schema.name)!
		sequences.sort_with_compare(fn (a &Sequence, b &Sequence) int {
			return a.name.entity_name.compare(b.name.entity_name)
		})

		for _, sequence in sequences {
			write_line(mut w, '${sequence}\n')!

			// START WITH is kept for RESTART, so the current position (if it has
			// moved) needs to be restored separately. A sequence that has been used
			// returns its last value again, so that it's still used (which matters
			// for ALTER SEQUENCE, see Sequence.unused).
			name := sequence.name.storage_sql()
			if sequence.unused {
				next_value := sequence.next_value() or { sequence.start_value }
				if next_value != sequence.start_value {
					write_line(mut w, 'ALTER SEQUENCE ${name} RESTART WITH ${next_value};\n')!
				}
			} else {
				write_line(mut w, 'ALTER SEQUENCE ${name} RESTART WITH ${sequence.current_value};')!
				write_line(mut w, 'VALUES NEXT VALUE FOR ${name};\n')!
			}
		}

		mut tables := catalog.schema_tables(schema.name)!
		tables.sort_with_compare(fn (a &Table, b &Table) int {
			return a.name.entity_name.compare(b.name.entity_name)
		})

		for _, table in tables {
			write_line(mut w, '${Table{ ...table, foreign_keys: []ForeignKey{} }}\n')!

			name := table.name.storage_sql()
			for key in table.foreign_keys {
				foreign_keys << 'ALTER TABLE ${name} ADD CONSTRAINT ${delimit_identifier(key.name)} ${key};'
			}
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

			for row in conn.query('SELECT * FROM ${name}')! {
				mut data := []string{}
				for col in column_names {
					data << (row.get(col)!).literal()
				}

				write_line(mut w, 'INSERT INTO ${name} (${columns})${overriding} VALUES (${data.join(', ')});')!
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
	mut statements := []string{}
	mut start := 0
	mut quote := u8(0)
	mut is_empty := true
	mut i := 0
	for i < script.len {
		c := script[i]
		if quote != 0 {
			// A doubled quote ('' or "") is read as two strings next to each
			// other, which is the same for finding the end of the statement.
			if c == quote {
				quote = 0
			}
		} else if c == `-` && i + 1 < script.len && script[i + 1] == `-` {
			for i < script.len && script[i] != `\n` {
				i++
			}
			continue
		} else if c == `;` {
			if !is_empty {
				statements << script[start..i].trim_space()
			}
			start = i + 1
			is_empty = true
		} else if c == `'` || c == `"` {
			quote = c
			is_empty = false
		} else if !c.is_space() {
			is_empty = false
		}
		i++
	}
	if !is_empty {
		statements << script[start..].trim_space()
	}

	return statements
}
