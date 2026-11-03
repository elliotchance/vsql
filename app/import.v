// Importing a SQL, CSV, TSV or JSON file, for "vsql in" (see docs/cli.rst). A file
// is read as it's imported, so it's never all in memory. A problem at the end of a
// file is only found when it gets there.
module app

import io
import strings
import vsql

// import_chunk_size is how much of a file is read at a time.
const import_chunk_size = 65536

// ImportInput reads a file a byte at a time, and knows where it's up to.
struct ImportInput {
mut:
	reader io.Reader
	buffer []u8
	pos    int
	at_eof bool
	// failure is why the file couldn't be read, which ends it.
	failure string
	// offset is the bytes that have been used, and line is the line that's next.
	offset i64
	line   int = 1
	// record_line is the line of the row being read, or the problem with it.
	record_line int = 1
	// json_started and json_finished are how far through the array of a JSON file,
	// and json_empty is true if it has no rows.
	json_started  bool
	json_finished bool
	json_empty    bool
}

fn (mut input ImportInput) fill() {
	if input.pos > 0 {
		input.buffer = input.buffer[input.pos..].clone()
		input.pos = 0
	}
	mut chunk := []u8{len: import_chunk_size}
	n := input.reader.read(mut chunk) or {
		if err !is io.Eof {
			input.failure = err.msg()
		}
		input.at_eof = true
		return
	}
	if n == 0 {
		input.at_eof = true
		return
	}
	input.buffer << chunk[..n]
}

// peek is the byte that's ahead bytes from the next one.
fn (mut input ImportInput) peek(ahead int) ?u8 {
	for input.pos + ahead >= input.buffer.len && !input.at_eof {
		input.fill()
	}
	if input.pos + ahead < input.buffer.len {
		return input.buffer[input.pos + ahead]
	}

	return none
}

// skip uses the next byte, which has been seen with peek.
fn (mut input ImportInput) skip() {
	if input.buffer[input.pos] == `\n` {
		input.line++
	}
	input.pos++
	input.offset++
}

// skip_bom skips the byte order mark that a file can start with.
fn (mut input ImportInput) skip_bom() {
	input.accept_text('\xef\xbb\xbf')
}

// accept_text skips text, if that's what is next.
fn (mut input ImportInput) accept_text(text string) bool {
	for i, c in text {
		next := input.peek(i) or { return false }
		if next != c {
			return false
		}
	}
	for _ in 0 .. text.len {
		input.skip()
	}

	return true
}

// take_chunk is what's left of the buffer, or the next part of the file. It's
// empty at the end of the file. offset and line aren't changed.
fn (mut input ImportInput) take_chunk() string {
	if input.pos >= input.buffer.len && !input.at_eof {
		input.fill()
	}
	text := input.buffer[input.pos..].bytestr()
	input.buffer = []u8{}
	input.pos = 0

	return text
}

// CellKind is a value, or that there isn't one.
enum CellKind {
	value
	null
	// missing isn't in the row, so the column gets its DEFAULT.
	missing
}

struct ImportCell {
	kind  CellKind
	value string
}

// delimited_record is the next line of CSV (RFC 4180), or TSV with the same rules,
// which is empty at the end of the file. A value that's empty is NULL, unless it's
// quoted (then it's an empty string). A blank line is ignored.
fn (mut input ImportInput) delimited_record(separator u8) ![]ImportCell {
	for {
		input.record_line = input.line
		mut record := []ImportCell{}
		mut field := strings.new_builder(64)
		mut quoted := false
		mut ended := false
		for {
			c := input.peek(0) or { break }
			if c == `"` && field.len == 0 && !quoted {
				quoted = true
				input.skip()
				input.quoted_field(mut field)!
				after := input.peek(0) or { break }
				if after !in [separator, `\r`, `\n`] {
					input.record_line = input.line
					return error('unexpected text after a closing quote')
				}
				continue
			}
			is_crlf := c == `\r` && (input.peek(1) or { u8(0) }) == `\n`
			if c == separator || c == `\n` || is_crlf {
				record << delimited_cell(field.str(), quoted)
				quoted = false
				input.skip()
				if is_crlf {
					input.skip()
				}
				if c == separator {
					continue
				}
				ended = true
				break
			}
			field.write_u8(c)
			input.skip()
		}
		if !ended {
			if field.len == 0 && !quoted && record.len == 0 {
				return []ImportCell{}
			}
			record << delimited_cell(field.str(), quoted)
		}
		if record.len == 1 && record[0].kind == .null {
			if ended {
				continue
			}
			return []ImportCell{}
		}

		return record
	}

	return []ImportCell{}
}

// quoted_field reads up to the closing quote.
fn (mut input ImportInput) quoted_field(mut field strings.Builder) ! {
	for {
		c := input.peek(0) or { return error('a quote is never closed') }
		input.skip()
		if c != `"` {
			field.write_u8(c)
			continue
		}
		if (input.peek(0) or { u8(0) }) != `"` {
			return
		}
		field.write_u8(`"`)
		input.skip()
	}
}

fn delimited_cell(value string, quoted bool) ImportCell {
	return if value == '' && !quoted {
		ImportCell{.null, ''}
	} else {
		ImportCell{.value, value}
	}
}

fn check_import_columns(columns []string) ! {
	mut seen := map[string]bool{}
	for i, column in columns {
		if column == '' {
			return error('column ${i + 1} has no name')
		}
		if column.to_upper() in seen {
			return error('there is more than one column named ${column}')
		}
		seen[column.to_upper()] = true
	}
}

// The rest of ImportInput reads JSON. It's not json2, so that a number isn't changed
// (such as 1.50, or an integer that's too big for a f64), the keys stay in the
// order that they're in the file, and only one row at a time is read.

fn (mut input ImportInput) json_error(message string) IError {
	input.record_line = input.line

	return error(message)
}

fn (mut input ImportInput) json_skip_space() {
	for {
		c := input.peek(0) or { return }
		if c !in [` `, `\t`, `\r`, `\n`] {
			return
		}
		input.skip()
	}
}

// json_accept skips c (after any white space), if that's what is next.
fn (mut input ImportInput) json_accept(c u8) bool {
	input.json_skip_space()
	if (input.peek(0) or { return false }) == c {
		input.skip()
		return true
	}

	return false
}

// json_row is the next object of a JSON array of objects, where each key is a
// column. json_finished is true once the last one has been read.
fn (mut input ImportInput) json_row() !map[string]ImportCell {
	if !input.json_started {
		if !input.json_accept(`[`) {
			return input.json_error('the file must be an array of objects')
		}
		input.json_started = true
		if input.json_accept(`]`) {
			input.json_end()!
			input.json_empty = true
			return map[string]ImportCell{}
		}
	}

	input.json_skip_space()
	input.record_line = input.line
	row_line := input.line
	object := input.json_object()!
	if input.json_accept(`]`) {
		input.json_end()!
	} else if !input.json_accept(`,`) {
		return input.json_error('expected "," or "]"')
	}
	input.record_line = row_line

	return object
}

fn (mut input ImportInput) json_end() ! {
	input.json_finished = true
	input.json_skip_space()
	if _ := input.peek(0) {
		return input.json_error('unexpected text after the array')
	}
}

fn (mut input ImportInput) json_object() !map[string]ImportCell {
	if !input.json_accept(`{`) {
		return input.json_error('each row must be an object')
	}
	mut object := map[string]ImportCell{}
	if input.json_accept(`}`) {
		return object
	}
	for {
		input.json_skip_space()
		name := input.json_string()!
		if !input.json_accept(`:`) {
			return input.json_error('expected ":"')
		}
		object[name] = input.json_value(name)!
		if input.json_accept(`}`) {
			return object
		}
		if !input.json_accept(`,`) {
			return input.json_error('expected "," or "}"')
		}
	}

	return object
}

fn (mut input ImportInput) json_value(name string) !ImportCell {
	input.json_skip_space()
	c := input.peek(0) or { return input.json_error('expected a value') }
	if c == `"` {
		return ImportCell{.value, input.json_string()!}
	}
	if c in [`{`, `[`] {
		return input.json_error('${name} is an object or array, only a string, number, boolean or null can be imported')
	}
	if input.accept_text('true') {
		return ImportCell{.value, 'TRUE'}
	}
	if input.accept_text('false') {
		return ImportCell{.value, 'FALSE'}
	}
	if input.accept_text('null') {
		return ImportCell{.null, ''}
	}

	mut sb := strings.new_builder(32)
	for {
		next := input.peek(0) or { break }
		if !next.is_digit() && next !in [`-`, `+`, `.`, `e`, `E`] {
			break
		}
		sb.write_u8(next)
		input.skip()
	}
	number := sb.str()
	if !is_json_number(number) {
		return input.json_error('expected a value')
	}

	return ImportCell{.value, number}
}

fn is_json_number(s string) bool {
	return s != '' && s[s.len - 1].is_digit() && s[0] != `+` && s[0] != `.` && s[0] != `e`
		&& s[0] != `E`
}

fn (mut input ImportInput) json_string() !string {
	if (input.peek(0) or { u8(0) }) != `"` {
		return input.json_error('expected a string')
	}
	input.skip()
	mut sb := strings.new_builder(32)
	for {
		c := input.peek(0) or { break }
		input.skip()
		if c == `"` {
			return sb.str()
		}
		if c != `\\` {
			sb.write_u8(c)
			continue
		}
		escape := input.peek(0) or { break }
		input.skip()
		match escape {
			`"`, `\\`, `/` { sb.write_u8(escape) }
			`b` { sb.write_u8(`\b`) }
			`f` { sb.write_u8(`\f`) }
			`n` { sb.write_u8(`\n`) }
			`r` { sb.write_u8(`\r`) }
			`t` { sb.write_u8(`\t`) }
			`u` { sb.write_string(input.json_unicode_escape()!) }
			else { return input.json_error('unknown escape') }
		}
	}

	return input.json_error('a string is never closed')
}

// json_unicode_escape is the character after "\u", which is two escapes when it's a
// surrogate pair.
fn (mut input ImportInput) json_unicode_escape() !string {
	high := input.json_hex4()!
	if high >= 0xd800 && high < 0xdc00 && input.accept_text('\\u') {
		low := input.json_hex4()!
		return utf32_to_str(u32(0x10000 + ((high - 0xd800) << 10) + (low - 0xdc00)))
	}

	return utf32_to_str(u32(high))
}

fn (mut input ImportInput) json_hex4() !int {
	mut hex := ''
	for _ in 0 .. 4 {
		c := input.peek(0) or { return input.json_error('a \\u escape needs 4 hex digits') }
		if !c.is_hex_digit() {
			return input.json_error('a \\u escape needs 4 hex digits')
		}
		hex += c.ascii_str()
		input.skip()
	}

	return int('0x${hex}'.i64())
}

// import_name is a name as it's entered: upper case, unless it's in double
// quotes to keep its case.
fn import_name(name string) string {
	trimmed := name.trim_space()
	if trimmed.len >= 2 && trimmed[0] == `"` && trimmed[trimmed.len - 1] == `"` {
		return trimmed[1..trimmed.len - 1].replace('""', '"')
	}

	return trimmed.to_upper()
}

// import_column finds the column of a table for a name in a file, which can be
// in any case.
fn import_column(table EditTable, name string) !EditColumn {
	for column in table.columns {
		if column.name == name {
			if column.generated {
				return error('${column.name} is generated, so it cannot be imported')
			}
			return column
		}
	}
	for column in table.columns {
		if column.name == name.to_upper() {
			if column.generated {
				return error('${column.name} is generated, so it cannot be imported')
			}
			return column
		}
	}

	return error('${table.name} has no column named ${name}')
}

// import_batch_size is the most rows in one INSERT. Parsing one statement with
// many rows is much faster than parsing a statement for each row.
const import_batch_size = 200

// ImportRow is a row of a file, ready to be inserted.
struct ImportRow {
	names  string
	values string
	// line is where it starts in the file, and end is the byte after it.
	line int
	end  i64
}

// import_row is the columns and values for the INSERT of a row of a file. A column
// that isn't in the row gets its DEFAULT.
fn import_row(columns []EditColumn, row []ImportCell, first EditColumn) (string, string) {
	mut names := []string{}
	mut values := []string{}
	for i, cell in row {
		if cell.kind == .missing {
			continue
		}
		names << columns[i].sql_name()
		values << if cell.kind == .null { 'NULL' } else { sql_literal(columns[i].typ, cell.value) }
	}
	if names.len == 0 {
		return first.sql_name(), '(DEFAULT)'
	}

	return names.join(', '), '(${values.join(', ')})'
}

// import_field is the column for a field of a file, or an empty string if it isn't
// imported. With no mapping (each is the field and its column), each field goes
// to the column with its name.
fn import_field(field string, mapping [][]string) string {
	if mapping.len == 0 {
		return field
	}
	for pair in mapping {
		if pair.len == 2 && pair[0] == field {
			return pair[1]
		}
	}

	return ''
}

// ImportRows reads the rows of a CSV, TSV or JSON file.
struct ImportRows {
	format  string
	mapping [][]string
	table   EditTable
mut:
	// columns and indexes are the columns of a CSV or TSV file, and which field
	// each one is.
	columns []EditColumn
	indexes []int
	fields  int
	// seen_mapped is true if a JSON row has had a field that's imported.
	seen_mapped bool
	rows        int
}

// read_header reads the first line of a CSV or TSV file, which is the names of the
// columns.
fn (mut r ImportRows) read_header(mut input ImportInput) ! {
	separator := if r.format == 'csv' { `,` } else { `\t` }
	cells := input.delimited_record(separator)!
	if cells.len == 0 {
		return error('the file is empty, it needs a line with the names of the columns')
	}
	fields := cells.map(it.value.trim_space())
	check_import_columns(fields)!
	r.fields = fields.len
	for i, field in fields {
		target := import_field(field, r.mapping)
		if target != '' {
			r.indexes << i
			r.columns << import_column(r.table, target)!
		}
	}
	if r.columns.len == 0 {
		return error('none of the fields are mapped to a column')
	}
	check_import_columns(r.columns.map(it.name))!
}

// next is the next row, or none at the end of the file.
fn (mut r ImportRows) next(mut input ImportInput) !ImportRow {
	mut json_columns := []EditColumn{}
	mut cells := []ImportCell{}
	if r.format == 'json' {
		if input.json_finished {
			return error(import_end_of_rows)
		}
		object := input.json_row()!
		if input.json_empty {
			return error(import_end_of_rows)
		}
		for field, cell in object {
			target := import_field(field, r.mapping)
			if target != '' {
				r.seen_mapped = true
				json_columns << import_column(r.table, target)!
				cells << cell
			}
		}
	} else {
		separator := if r.format == 'csv' { `,` } else { `\t` }
		record := input.delimited_record(separator)!
		if record.len == 0 {
			return error(import_end_of_rows)
		}
		if record.len != r.fields {
			return error('has ${record.len} values, but there are ${r.fields} columns')
		}
		for i in r.indexes {
			cells << record[i]
		}
	}
	r.rows++
	first := r.table.columns.filter(!it.generated)[0] or {
		return error('${r.table.name} has no columns that can be imported')
	}
	names, values := import_row(if r.format == 'json' { json_columns } else { r.columns }, cells,
		first)

	return ImportRow{names, values, input.record_line, input.offset}
}

// import_end_of_rows is the error of ImportRows.next at the end of the file.
const import_end_of_rows = 'end of rows'

// ImportStatement is a statement of a SQL file, as it's run.
struct ImportStatement {
	sql string
	// unsupported is what it is if it can be ignored, such as CREATE VIEW, see
	// unsupported_statement.
	unsupported string
	// ignore_missing is true if it's fine that the table doesn't exist.
	ignore_missing bool
	// line is where it is in the file, if it's run later than its place in the file.
	line int
}

// is_transaction_statement is a statement that starts or ends a transaction.
fn is_transaction_statement(stmt string) bool {
	words := top_level_words(stmt)

	return words.len > 0 && (words[0] in ['COMMIT', 'ROLLBACK']
		|| (words.len > 1 && words[0] == 'START' && words[1] == 'TRANSACTION'))
}

// unsupported_statement is what a statement is if -ignore-unsupported can ignore
// it. They would be a loss, but the rest of the file is still useful without them.
fn unsupported_statement(words []string) string {
	if words.len < 2 || words[0] != 'CREATE' {
		return ''
	}
	kind := if words[1] in ['TEMP', 'TEMPORARY', 'UNIQUE'] { words[2] or { '' } } else { words[1] }

	return if kind in ['VIEW', 'TRIGGER', 'INDEX'] { 'CREATE ${kind}' } else { '' }
}

// ImportRun prints what happens as statements are run. See docs/cli.rst for the
// format, which the IMPORT tab of "vsql app" also reads (see import_tab.v).
struct ImportRun {
	options ImportOptions
	// total is the size of the file, or less than zero if it's not known.
	total i64
mut:
	failed bool
}

// print_line prints a line of output, which all start the same way.
fn (r &ImportRun) print_line(line int, done i64, message string) {
	total := if r.total < 0 { '?' } else { r.total.str() }
	println('${line} ${done}/${total} ${message}')
}

fn (r &ImportRun) print_statement(line int, done i64, message string) {
	if r.options.verbose {
		r.print_line(line, done, message)
	}
}

// import_general_error is the SQLSTATE of a problem that doesn't have its own, such
// as a row of a file that can't be read, since every line has one.
const import_general_error = 'HY000'

// print_condition prints an ERROR, WARNING or NOTICE.
fn (r &ImportRun) print_condition(kind string, code int, line int, done i64, message string) {
	sqlstate := if code > 0 { vsql.sqlstate_from_int(code) } else { import_general_error }
	r.print_line(line, done, '${kind} ${sqlstate} ${message}')
}

// fail is an error that was caused by line of the file, or 0 if it isn't in the
// file.
fn (mut r ImportRun) fail(line int, done i64, err IError) {
	r.failed = true
	r.print_condition('ERROR', err.code(), line, done, err.msg())
}

// execute runs a statement and prints the line for it, which is a count of the rows
// for a statement that has no message, such as a SELECT. An error isn't printed.
fn (r &ImportRun) execute(mut conn vsql.Connection, stmt string, line int, done i64) ! {
	conn.clear_warnings()
	mut result := conn.query(stmt)!
	mut message := result.msg
	if message == '' {
		mut count := 0
		for _ in result {
			count++
		}
		message = '${top_level_words(stmt)[0] or { 'OK' }} ${count}'
	}
	for warning in conn.warnings {
		// 02000 (no data) is a completion condition, not a warning.
		if vsql.sqlstate_from_int(warning.code()).starts_with('02') {
			if r.options.verbose {
				r.print_condition('NOTICE', warning.code(), line, done, warning.msg())
			}
		} else {
			r.print_condition('WARNING', warning.code(), line, done, warning.msg())
		}
	}
	r.print_statement(line, done, message)
}

// generated runs a statement that isn't in the file, and is false if it failed.
fn (mut r ImportRun) generated(mut conn vsql.Connection, stmt string, done i64) bool {
	r.execute(mut conn, stmt, 0, done) or {
		r.fail(0, done, err)
		return false
	}

	return true
}

// rollback is shown even if the statements aren't, because it means that what was
// before it wasn't kept.
fn (mut r ImportRun) rollback(mut conn vsql.Connection, done i64) {
	conn.query('ROLLBACK') or {
		r.fail(0, done, err)
		return
	}
	r.print_line(0, done, 'ROLLBACK')
}

// insert_batch inserts rows next to each other with the same columns. If the INSERT
// fails (which changes nothing) the rows are run one at a time, to find the rows
// that are wrong. It's false if it should stop.
fn (mut r ImportRun) insert_batch(mut conn vsql.Connection, table_name string, batch []ImportRow) bool {
	last := batch[batch.len - 1]
	r.execute(mut conn, 'INSERT INTO ${table_name} (${batch[0].names}) VALUES ${batch.map(it.values).join(', ')}',
		batch[0].line, last.end) or {
		for row in batch {
			r.execute(mut conn, 'INSERT INTO ${table_name} (${row.names}) VALUES ${row.values}',
				row.line, row.end) or {
				r.fail(row.line, row.end, err)
				if !r.options.continue_on_error {
					return false
				}
			}
		}
	}

	return true
}

// import_rows imports a CSV, TSV or JSON file into a table of a file, which is
// always in one transaction. A row that the file doesn't let us read stops it, even
// with continue_on_error, since there's no way to know where the next row is.
fn (a &App) import_rows(mut conn vsql.Connection, catalog string, mut input ImportInput, total i64, options ImportOptions) !bool {
	schema := if options.schema == '' { 'PUBLIC' } else { import_name(options.schema) }
	name := import_name(options.table)
	table_name := vsql.Identifier{
		schema_name: schema
		entity_name: name
	}.str()

	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	mut run := ImportRun{
		options: options
		total:   total
	}
	if !run.generated(mut conn, 'START TRANSACTION', 0) {
		return false
	}
	if !run.import_rows_in_transaction(a, mut conn, catalog, schema, name, table_name, mut input) {
		run.rollback(mut conn, input.offset)
		return false
	}
	run.generated(mut conn, 'COMMIT', input.offset)

	return !run.failed
}

// import_rows_in_transaction is false if it should be rolled back.
fn (mut r ImportRun) import_rows_in_transaction(a &App, mut conn vsql.Connection, catalog string, schema string, name string, table_name string, mut input ImportInput) bool {
	options := r.options
	if options.create_table != ''
		&& !r.generated(mut conn, 'CREATE TABLE ${table_name} (${options.create_table})', 0) {
		return false
	}
	table := a.find_edit_table(mut conn, catalog, schema, name) or {
		r.fail(0, input.offset, err)
		return false
	}
	set_catalog(mut conn, catalog) or {
		r.fail(0, input.offset, err)
		return false
	}

	input.skip_bom()
	mut rows := ImportRows{
		format:  options.format
		mapping: options.mapping
		table:   table
	}
	if options.format != 'json' {
		rows.read_header(mut input) or {
			r.fail(input.record_line, input.offset, err)
			return false
		}
	}

	mut batch := []ImportRow{}
	for {
		row := rows.next(mut input) or {
			if err.msg() == import_end_of_rows {
				break
			}
			r.fail(input.record_line, input.offset, err)
			return false
		}
		if batch.len > 0 && (batch.len == import_batch_size || row.names != batch[0].names) {
			if !r.insert_batch(mut conn, table_name, batch) {
				return false
			}
			batch = []ImportRow{}
		}
		batch << row
	}
	if input.failure != '' {
		r.fail(input.line, input.offset, error(input.failure))
		return false
	}
	if rows.format == 'json' && options.mapping.len > 0 && rows.rows > 0 && !rows.seen_mapped {
		r.fail(0, input.offset, error('none of the fields are mapped to a column'))
		return false
	}
	if batch.len > 0 && !r.insert_batch(mut conn, table_name, batch) {
		return false
	}

	return !r.failed || options.continue_on_error
}

// ImportSql runs the statements of a SQL file as they're read.
struct ImportSql {
mut:
	run    ImportRun
	compat SqliteCompat
	// trigger is the start of a trigger, and its line. Its body has semicolons in
	// it, so it's put back together. Otherwise what's in the body would be run as
	// statements if the trigger can't be created.
	trigger      string
	trigger_line int
	// stopped is true once it won't run any more of the file.
	stopped bool
}

// statement is the next statement in the file, and done is the byte after it.
fn (mut s ImportSql) statement(mut conn vsql.Connection, stmt string, line int, done i64) {
	words := top_level_words(stmt)
	if words.len == 0 {
		return
	}
	if s.trigger != '' {
		s.trigger += '; ${stmt}'
		if words[words.len - 1] == 'END' {
			s.finish_trigger(mut conn, done)
		}
		return
	}
	if unsupported_statement(words) == 'CREATE TRIGGER' && words.contains('BEGIN')
		&& words[words.len - 1] != 'END' {
		s.trigger = stmt
		s.trigger_line = line
		return
	}
	s.translated(mut conn, stmt, line, done)
}

fn (mut s ImportSql) finish_trigger(mut conn vsql.Connection, done i64) {
	stmt := s.trigger
	s.trigger = ''
	s.translated(mut conn, stmt, s.trigger_line, done)
}

fn (mut s ImportSql) translated(mut conn vsql.Connection, stmt string, line int, done i64) {
	options := s.run.options
	unsupported := if options.ignore_unsupported {
		unsupported_statement(top_level_words(stmt))
	} else {
		''
	}
	if unsupported != '' {
		s.execute(mut conn, ImportStatement{
			sql:         stmt
			unsupported: unsupported
		}, line, done)
	} else if options.compat == 'sqlite3' {
		s.compat.line = line
		for translated in s.compat.translate(stmt) {
			s.execute(mut conn, translated, line, done)
		}
	} else {
		s.execute(mut conn, ImportStatement{
			sql: stmt
		}, line, done)
	}
}

fn (mut s ImportSql) execute(mut conn vsql.Connection, stmt ImportStatement, line int, done i64) {
	if s.stopped {
		return
	}
	if s.run.options.single_transaction && is_transaction_statement(stmt.sql) {
		s.run.fail(line, done, error('a file with its own transactions cannot be run with -single-transaction'))
		s.stopped = true
		return
	}
	s.run.execute(mut conn, stmt.sql, line, done) or {
		if stmt.ignore_missing && err.msg().contains('no such table') {
			s.run.print_statement(line, done, 'DROP TABLE 0')
			return
		}
		if stmt.unsupported != '' {
			s.run.print_condition('WARNING', vsql.sqlstate_to_int('01000'), line, done, '${stmt.unsupported} is not supported, so it was ignored')
			return
		}
		s.run.fail(line, done, err)
		s.stopped = !s.run.options.continue_on_error
	}
}

// import_sql runs a SQL file. A statement that fails changes nothing. In a single
// transaction, stopping at a failure rolls it back. A transaction that's still open
// at the end of the file is rolled back.
fn (a &App) import_sql(mut conn vsql.Connection, catalog string, mut input ImportInput, total i64, options ImportOptions) !bool {
	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	mut s := ImportSql{
		run: ImportRun{
			options: options
			total:   total
		}
	}
	if options.schema != ''
		&& !s.run.generated(mut conn, "SET SCHEMA '${import_name(options.schema).replace("'", "''")}'", 0) {
		return false
	}
	if options.single_transaction && !s.run.generated(mut conn, 'START TRANSACTION', 0) {
		return false
	}

	input.skip_bom()
	mut pending := ''
	mut base := input.offset
	mut line := 1
	mut stopped_at := i64(0)
	for !s.stopped {
		chunk := input.take_chunk()
		pending += chunk
		statements, rest := vsql.statement_ranges(pending)
		mut counted := 0
		for range in statements {
			line += pending[counted..range.first].count('\n')
			counted = range.first
			s.statement(mut conn, pending[range.start..range.end].trim_space(), line,
				base + range.end + 1)
			if s.stopped {
				stopped_at = base + range.end + 1
				break
			}
		}
		if s.stopped {
			base = stopped_at
			break
		}
		if chunk == '' {
			if !s.stopped && rest.first >= 0 {
				line += pending[counted..rest.first].count('\n')
				s.statement(mut conn, pending[rest.start..].trim_space(), line, base + pending.len)
			}
			base += pending.len
			break
		}
		line += pending[counted..rest.start].count('\n')
		base += rest.start
		pending = pending[rest.start..]
	}
	if s.trigger != '' {
		s.finish_trigger(mut conn, base)
	}
	if input.failure != '' {
		s.run.fail(line, base, error(input.failure))
		s.stopped = true
	}
	for foreign_key in s.compat.foreign_keys {
		s.execute(mut conn, foreign_key, foreign_key.line, base)
	}

	if options.single_transaction {
		if s.stopped {
			s.run.rollback(mut conn, base)
		} else {
			s.run.generated(mut conn, 'COMMIT', base)
		}
	} else if _ := conn.query('ROLLBACK') {
		if !s.stopped {
			s.run.print_condition('WARNING', vsql.sqlstate_to_int('01000'), 0, base, 'the file left a transaction open')
		}
		s.run.print_line(0, base, 'ROLLBACK')
	}

	return !s.run.failed
}

// ImportOptions are the options of "vsql in", also see cmd/vsql-cli/in.v.
pub struct ImportOptions {
pub:
	// format is sql, csv, tsv or json.
	format string
	// schema is the current schema for SQL, and the schema of table otherwise. It's
	// PUBLIC if it's empty. schema and table are as they're entered, see import_name.
	schema string
	table  string
	// create_table is the definitions of the columns to create table with.
	create_table string
	// mapping has the field in the file and the column for it. The other fields
	// aren't imported. With no mapping, each field goes to the column with its name.
	mapping            [][]string
	continue_on_error  bool
	single_transaction bool
	// compat is the dialect of a SQL file: empty for vsql, or sqlite3 (see
	// import_compat.v).
	compat string
	// ignore_unsupported makes a warning of a statement that can't be run, if it
	// isn't essential to the rest of the file (see unsupported_statement).
	ignore_unsupported bool
	// verbose also prints each statement, with where it is in the file.
	verbose bool
}

// import_database is "vsql in", which prints what happens. total is the size of the
// file, or less than zero if it's not known. It returns false if a statement failed.
// An error means that nothing could be imported.
pub fn import_database(path string, mut reader io.Reader, total i64, options ImportOptions) !bool {
	catalog := vsql.catalog_name_from_path(path)
	connection_options := vsql.default_connection_options()
	mut conn := vsql.open_database(path, connection_options)!
	defer {
		conn.close()
	}
	a := &App{
		db_files:      [path]
		catalog_names: [catalog]
		options:       [connection_options]
	}
	mut input := ImportInput{
		reader: reader
	}
	if options.format == 'sql' {
		return a.import_sql(mut conn, catalog, mut input, total, options)
	}

	return a.import_rows(mut conn, catalog, mut input, total, options)
}
