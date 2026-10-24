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
	mut catalog := conn.catalog()
	mut schemas := catalog.schemas()!

	// To make the output more deterministic, entities will be ordered by name.
	// This is not true for the records however, which can potentially come out in
	// any order.
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
			return a.name.str().compare(b.name.str())
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
			return a.name.str().compare(b.name.str())
		})

		for _, table in tables {
			write_line(mut w, '${table}\n')!

			name := table.name.storage_sql()
			columns := table.column_names().map(delimit_identifier(it)).join(', ')
			for row in conn.query('SELECT * FROM ${name}')! {
				mut data := []string{}
				for col in table.column_names() {
					data << (row.get(col)!).literal()
				}

				write_line(mut w, 'INSERT INTO ${name} (${columns}) VALUES (${data.join(', ')});')!
			}

			write_line(mut w, '')!
		}
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
