// Loading SQL that's written for another database, see "vsql in -compat" in
// docs/cli.rst. It's not a parser for the other database. It only handles the
// quoting of names and the start of each statement, and vsql parses the result.
module main

import strings

// SqliteTable is a table created by the file, for its INSERTs.
struct SqliteTable {
	columns    []string
	timestamps map[string]bool
}

// SqliteCompat translates the statements of a file, in order.
struct SqliteCompat {
mut:
	tables map[string]SqliteTable
	// foreign_keys are run at the end, since they can refer to a table that's
	// created later and the rows can be in any order.
	foreign_keys []ImportStatement
	// indexes are run at the end, before foreign_keys, see ImportSql.translated.
	indexes []ImportStatement
	// line is the line of the statement being translated.
	line int
}

const sqlite_types = {
	'NVARCHAR': 'VARCHAR'
	'NCHAR':    'CHARACTER'
	'DATETIME': 'TIMESTAMP(0) WITHOUT TIME ZONE'
}

// sqlite_end_of_quote is the position after a quoted name or string that starts at
// i. A doubled quote is part of it, and a [name] has no way to have a ].
fn sqlite_end_of_quote(s string, i int) int {
	close := if s[i] == `[` { `]` } else { s[i] }
	mut j := i + 1
	for j < s.len {
		if s[j] == close {
			if close != `]` && j + 1 < s.len && s[j + 1] == close {
				j += 2
				continue
			}
			return j + 1
		}
		j++
	}

	return s.len
}

// sqlite_normalize removes the comments, and makes every quoted name upper case
// with double quotes. A name isn't case sensitive in SQLite, so it can be written
// differently in each place. A name that isn't quoted is already upper case to
// vsql, so they all end up as the same name.
fn sqlite_normalize(stmt string) string {
	mut sb := strings.new_builder(stmt.len)
	mut i := 0
	for i < stmt.len {
		c := stmt[i]
		if c == `'` {
			end := sqlite_end_of_quote(stmt, i)
			sb.write_string(stmt[i..end])
			i = end
		} else if c in [`"`, `[`, `\``] {
			end := sqlite_end_of_quote(stmt, i)
			close_len := if end - i >= 2 && stmt[end - 1] == (if c == `[` { `]` } else { c }) {
				1
			} else {
				0
			}
			name := stmt[i + 1..end - close_len].replace(c.ascii_str() + c.ascii_str(), c.ascii_str())
			sb.write_string('"${name.to_upper().replace('"', '""')}"')
			i = end
		} else if stmt[i..].starts_with('--') {
			i = stmt.index_after('\n', i) or { stmt.len }
		} else if stmt[i..].starts_with('/*') {
			i = (stmt.index_after('*/', i + 2) or { stmt.len - 2 }) + 2
			sb.write_u8(` `)
		} else {
			sb.write_u8(c)
			i++
		}
	}

	return sb.str().trim_space()
}

// sqlite_key is a name, to compare it.
fn sqlite_key(word string) string {
	return word.trim('"').replace('""', '"').to_upper()
}

// sqlite_split splits text on the commas that aren't in parentheses or quotes.
fn sqlite_split(text string) []string {
	mut items := []string{}
	mut depth := 0
	mut start := 0
	mut i := 0
	for i < text.len {
		c := text[i]
		if c in [`'`, `"`] {
			i = sqlite_end_of_quote(text, i)
			continue
		}
		if c == `(` {
			depth++
		} else if c == `)` {
			depth--
		} else if c == `,` && depth == 0 {
			items << text[start..i].trim_space()
			start = i + 1
		}
		i++
	}
	items << text[start..].trim_space()

	return items
}

// sqlite_parens is the position of a "(" that isn't in quotes, and of its ")".
fn sqlite_parens(text string, from int) ?(int, int) {
	mut open := -1
	mut depth := 0
	mut i := from
	for i < text.len {
		c := text[i]
		if c in [`'`, `"`] {
			i = sqlite_end_of_quote(text, i)
			continue
		}
		if c == `(` {
			if depth == 0 {
				open = i
			}
			depth++
		} else if c == `)` {
			depth--
			if depth == 0 {
				return open, i
			}
		}
		i++
	}

	return none
}

// after_word is the position after the first time a word is in sql, in any case.
fn after_word(query string, word string) int {
	index := query.to_upper().index(word) or { return 0 }

	return index + word.len
}

// translate is what to run for a statement of the file.
fn (mut c SqliteCompat) translate(stmt string) []ImportStatement {
	query := sqlite_normalize(stmt)
	words := top_level_words(query)
	if words.len == 0 || words[0] == 'PRAGMA' {
		return []
	}
	if words[0] == 'BEGIN' {
		return [ImportStatement{
			sql: 'START TRANSACTION'
		}]
	}
	if words[0] == 'END' {
		return [ImportStatement{
			sql: 'COMMIT'
		}]
	}
	if words.len > 4 && words[..4] == ['DROP', 'TABLE', 'IF', 'EXISTS'] {
		return [
			ImportStatement{
				sql:            'DROP TABLE ${query[after_word(query, 'EXISTS')..].trim_space()}'
				ignore_missing: true
			},
		]
	}
	if words.len > 2 && words[..2] == ['CREATE', 'TABLE'] {
		return [ImportStatement{
			sql: c.create_table(query, words[2])
		}]
	}
	if words.len > 2 && words[..2] == ['INSERT', 'INTO'] {
		return [ImportStatement{
			sql: c.insert(query, words[2])
		}]
	}

	return [ImportStatement{
		sql: query
	}]
}

// create_table changes the types and moves the FOREIGN KEYs to the end of the file.
fn (mut c SqliteCompat) create_table(query string, name string) string {
	open, close := sqlite_parens(query, 0) or { return query }
	mut items := []string{}
	mut columns := []string{}
	mut timestamps := map[string]bool{}
	for item in sqlite_split(query[open + 1..close]) {
		words := top_level_words(item)
		if words.len == 0 {
			continue
		}
		if words[0] == 'FOREIGN' || (words[0] == 'CONSTRAINT' && 'FOREIGN' in words) {
			c.foreign_keys << ImportStatement{
				sql:  'ALTER TABLE ${name} ADD ${item}'
				line: c.line
			}
			continue
		}
		if words[0] in ['CONSTRAINT', 'PRIMARY', 'UNIQUE', 'CHECK'] {
			items << item
			continue
		}
		column := sqlite_key(words[0])
		columns << column
		kind := words[1] or { '' }
		if kind == 'DATETIME' {
			timestamps[column] = true
		}
		if replacement := sqlite_types[kind] {
			position := after_word(item[words[0].len..], kind) + words[0].len
			items << '${item[..position - kind.len]}${replacement}${item[position..]}'
		} else {
			items << item
		}
	}
	c.tables[sqlite_key(name)] = SqliteTable{columns, timestamps}

	return '${query[..open + 1]}${items.join(', ')}${query[close..]}'
}

// insert changes the strings for a DATETIME column, which aren't converted by
// themselves, into TIMESTAMP literals. Without columns, the values are in the order
// of the columns of the table.
fn (c &SqliteCompat) insert(query string, name string) string {
	table := c.tables[sqlite_key(name)] or { return query }
	if table.timestamps.len == 0 {
		return query
	}
	values := query.to_upper().index('VALUES') or { return query }
	mut columns := table.columns.clone()
	if open, close := sqlite_parens(query[..values], 0) {
		columns = sqlite_split(query[open + 1..close]).map(sqlite_key(it))
	}

	mut sb := strings.new_builder(query.len)
	sb.write_string(query[..values])
	mut depth := 0
	mut column := 0
	mut at_start := false
	mut i := values
	for i < query.len {
		c0 := query[i]
		if c0 == `'` {
			end := sqlite_end_of_quote(query, i)
			literal := query[i..end]
			if depth == 1 && at_start && (columns[column] or { '' }) in table.timestamps {
				sb.write_string('TIMESTAMP ${sqlite_timestamp(literal)}')
			} else {
				sb.write_string(literal)
			}
			at_start = false
			i = end
			continue
		}
		if c0 == `(` {
			depth++
			if depth == 1 {
				column = 0
				at_start = true
			}
		} else if c0 == `)` {
			depth--
		} else if c0 == `,` && depth == 1 {
			column++
			at_start = true
		} else if !c0.is_space() {
			at_start = false
		}
		sb.write_u8(c0)
		i++
	}

	return sb.str()
}

// sqlite_timestamp is a string as it's needed for a TIMESTAMP literal. SQLite also
// allows a date on its own, or a T before the time.
fn sqlite_timestamp(literal string) string {
	value := literal.trim("'")
	if value.len == 10 {
		return "'${value} 00:00:00'"
	}
	if value.len > 10 && value[10] == `T` {
		return "'${value[..10]} ${value[11..]}'"
	}

	return literal
}
