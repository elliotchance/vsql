// The EXPORT tab of "vsql app". It builds the arguments of "vsql out", which are
// shown as a command that can be copied. Export runs the same arguments, without
// -file so that the output comes back as the download. See export_command.
module app

import json2
import os
import strings
import net.urllib
import time
import vsql

// ExportPayload is the PAYLOAD (JSON) of an EXPORT tab.
struct ExportPayload {
	// source is where it was opened from: file, schema, table or query. It decides
	// which formats there are, see export_formats.
	source string
	format string
	file   string
	// selected is each object as SCHEMA.NAME (or SCHEMA.* for a schema without
	// objects), for the sql format.
	selected []string
	// query and params (P1, P2, etc) are for the other formats.
	query                string
	params               []string
	no_header            bool
	null_value           string
	no_transaction       bool
	create_public_schema bool
	// compat is the -compat of "vsql out", empty for vsql.
	compat string
	// contents is the -schema-only or -data-only of "vsql out", empty for both.
	contents string
}

// ExportObject is a sequence, table or foreign key that can be selected. A schema
// without any objects is one with a name of "*".
struct ExportObject {
	schema string
	name   string
	kind   string
}

fn (o ExportObject) key() string {
	return '${o.schema}.${o.name}'
}

// export_formats are the formats that can be chosen, the first is the default.
fn export_formats(source string) []string {
	return match source {
		'table' { ['sql', 'csv', 'tsv', 'json'] }
		'query' { ['csv', 'tsv', 'json'] }
		else { ['sql'] }
	}
}

// export_objects is everything in a file that can be selected, by schema and
// then by name.
fn (a &App) export_objects(mut conn vsql.Connection, catalog_name string) ![]ExportObject {
	set_catalog(mut conn, catalog_name)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	mut objects := []ExportObject{}
	mut foreign_keys := map[string][]string{}
	for row in conn.query("SELECT constraint_schema, constraint_name FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE constraint_type = 'FOREIGN KEY'")! {
		foreign_keys[row.get_string('CONSTRAINT_SCHEMA')!] << row.get_string('CONSTRAINT_NAME')!
	}
	mut catalog := conn.catalog()
	mut schemas := catalog.schemas()!.filter(!it.is_virtual).map(it.name)
	schemas.sort()
	for schema in schemas {
		mut names := map[string]string{}
		for sequence in catalog.sequences(schema)! {
			names[sequence.name.entity_name] = 'sequence'
		}
		for table in catalog.schema_tables(schema)! {
			names[table.name.entity_name] = 'table'
		}
		for name in foreign_keys[schema] or { []string{} } {
			names[name] = 'foreign key'
		}
		if names.len == 0 {
			objects << ExportObject{schema, '*', 'schema'}
		}
		mut sorted := names.keys()
		sorted.sort()
		for name in sorted {
			objects << ExportObject{schema, name, names[name] or { '' }}
		}
	}

	return objects
}

// export_file_name is the default name of a download. It's the time as vsql
// shows a TIMESTAMP, but a colon can't be in a file name on Windows or FAT32.
fn export_file_name(catalog_name string, format string) string {
	catalog := catalog_name.runes().map(if it < ` ` || it in [`<`, `>`, `:`, `"`, `/`, `\\`, `|`,
		`?`, `*`] {
		`_`
	} else {
		it
	}).string()

	return '${catalog}-${time.now().format_ss().replace(':', '-')}.${format}'
}

// with_extension changes the extension of a file name to the format, if it has
// the extension of another format.
fn with_extension(file string, format string) string {
	for extension in ['sql', 'csv', 'tsv', 'json'] {
		if file.ends_with('.${extension}') {
			return '${file.all_before_last('.')}.${format}'
		}
	}

	return file
}

// new_export_payload is the payload of a new tab.
fn new_export_payload(catalog string, source string, selected []string, query string, params []string) string {
	format := export_formats(source)[0]

	return json2.encode(ExportPayload{
		source:   source
		format:   format
		file:     export_file_name(catalog, format)
		selected: selected
		query:    query
		params:   params
	})
}

// open_export adds a tab to export a file (["file"]), schema (["schema", name]) or
// table (["table", schema, name]).
fn (a &App) open_export(mut conn vsql.Connection, catalog string, value string) ! {
	args := json2.decode[[]string](value)!
	objects := a.export_objects(mut conn, catalog)!
	if args == ['file'] {
		// VSQL_APP is the tabs and history of the app, they are created again in any
		// file that's opened so loading them would fail.
		selected := objects.filter(it.schema != 'VSQL_APP').map(it.key())
		a.add_tab(mut conn, catalog, export_tab, 'Export ${catalog}', new_export_payload(catalog,
			'file', selected, '', []))!
		return
	}
	if args.len == 2 && args[0] == 'schema' {
		selected := objects.filter(it.schema == args[1]).map(it.key())
		a.add_tab(mut conn, catalog, export_tab, 'Export ${args[1]}', new_export_payload(catalog,
			'schema', selected, '', []))!
		return
	}
	if args.len == 3 && args[0] == 'table' {
		query := 'TABLE ${vsql.Identifier{
			schema_name: args[1]
			entity_name: args[2]
		}}'
		a.add_tab(mut conn, catalog, export_tab, 'Export ${args[2]}', new_export_payload(catalog,
			'table', ['${args[1]}.${args[2]}'], query, []))!
		return
	}

	return error('bad export: ${value}')
}

// open_query_export adds a tab to export the last statement of a query tab, if
// it's a query. A "?" that isn't text is changed to a CAST, because the value of
// P1, P2, etc is always a string.
fn (a &App) open_query_export(mut conn vsql.Connection, tab Tab, query_text string, params Params) ! {
	statements := vsql.split_statements(query_text)
	mut query := ''
	mut values := []string{}
	if statements.len > 0 && a.is_query(mut conn, tab.catalog, statements.last()) {
		mut offset := 0
		for stmt in statements[..statements.len - 1] {
			offset += question_marks(stmt).len
		}
		mut casts := []string{}
		for i in 0 .. question_marks(statements.last()).len {
			value, cast := export_param(params.values[offset + i] or { '' }, params.types[offset +
				i] or { 'auto:text' })
			values << value
			casts << cast
		}
		query = with_casts(statements.last(), casts)
	}
	a.add_tab(mut conn, tab.catalog, export_tab, 'Export result', new_export_payload(tab.catalog,
		'query', [], query, values))!
}

fn (a &App) is_query(mut conn vsql.Connection, catalog string, stmt string) bool {
	set_catalog(mut conn, catalog) or { return false }
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	prepared := conn.prepare(stmt) or { return false }
	function, _ := prepared.command_function()

	return function == 'SELECT CURSOR'
}

// export_param is the value of a "?" and the type that it's cast to, if any.
fn export_param(value string, typ string) (string, string) {
	return match typ.all_after('auto:') {
		'null' {
			'\\N', ''
		}
		'true', 'false', 'unknown' {
			typ.to_upper(), 'BOOLEAN'
		}
		'boolean' {
			value, 'BOOLEAN'
		}
		'number' {
			value, if value.to_upper().contains('E') {
				'DOUBLE PRECISION'
			} else {
				'DECIMAL(30, 10)'
			}
		}
		'date' {
			value, 'DATE'
		}
		'time' {
			value, 'TIME(6)'
		}
		'timestamp' {
			value.replace('T', ' '), 'TIMESTAMP(6)'
		}
		else {
			value, ''
		}
	}
}

// question_marks are the offsets of each "?" that's a parameter, which isn't in a
// string, a delimited identifier or a comment.
fn question_marks(text string) []int {
	mut offsets := []int{}
	mut i := 0
	for i < text.len {
		c := text[i]
		if c == `'` || c == `"` {
			i = text.index_after(c.ascii_str(), i + 1) or { text.len }
		} else if c == `-` && i + 1 < text.len && text[i + 1] == `-` {
			i = text.index_after('\n', i) or { text.len }
		} else if c == `/` && i + 1 < text.len && text[i + 1] == `*` {
			i = text.index_after('*/', i) or { text.len }
		} else if c == `?` {
			offsets << i
		}
		i++
	}

	return offsets
}

// with_casts puts each "?" with a type (or nothing) in a CAST.
fn with_casts(text string, casts []string) string {
	mut sb := strings.new_builder(text.len)
	mut last := 0
	for i, offset in question_marks(text) {
		sb.write_string(text[last..offset])
		sb.write_string(if casts[i] == '' { '?' } else { 'CAST(? AS ${casts[i]})' })
		last = offset + 1
	}
	sb.write_string(text[last..])

	return sb.str()
}

// export_pattern is a name for -include and -exclude, a character that would have
// another meaning in a pattern matches anything.
fn export_pattern(name string) string {
	return name.runes().map(if it in [`.`, `*`, `?`, `[`, `]`] { `?` } else { it }).string()
}

// export_filters are the -include and -exclude for the selected objects,
// whichever is shorter. A whole schema is a single pattern.
fn export_filters(source string, objects []ExportObject, selected []string) ([]string, []string) {
	chosen := objects.filter(it.key() in selected)
	if chosen.len == objects.len {
		return []string{}, []string{}
	}
	if chosen.len == 0 {
		return []string{}, ['*.*']
	}
	mut include := []string{}
	mut exclude := []string{}
	mut schemas := objects.map(it.schema)
	for i, schema in schemas {
		if i > 0 && schema == schemas[i - 1] {
			continue
		}
		name := export_pattern(schema)
		of_schema := objects.filter(it.schema == schema)
		yes := of_schema.filter(it.key() in selected)
		no := of_schema.filter(it.key() !in selected)
		// A table is exact even if it's the only object, so that it doesn't pick up
		// what's added to the schema later.
		if no.len == 0 && !(source == 'table' && yes.len == 1) {
			include << '${name}.*'
		} else {
			include << yes.map('${name}.${export_pattern(it.name)}')
		}
		if yes.len == 0 {
			exclude << '${name}.*'
		} else {
			exclude << no.map('${name}.${export_pattern(it.name)}')
		}
	}
	// A whole file has to leave out VSQL_APP, so it says so if it's just as short.
	if exclude.len < include.len || (source == 'file' && exclude.len == include.len) {
		return []string{}, exclude
	}

	return include, []string{}
}

// ExportCommand is what "vsql out" is run with: the value of each "?" and the
// arguments. The arguments without a file are for the download.
struct ExportCommand {
	params []string
	before []string
	file   string
	after  []string
}

// export_command is built from the payload. It's the only place that knows how
// the options become arguments, so what's shown is what's run.
fn export_command(payload ExportPayload, objects []ExportObject, path string) ExportCommand {
	mut before := ['out']
	mut after := []string{}
	if payload.format != 'sql' {
		before << ['-format', payload.format]
		if payload.format != 'json' {
			if payload.no_header {
				after << '-no-header'
			}
			if payload.null_value != '' {
				after << ['-null', payload.null_value]
			}
		}
		after << ['-query', payload.query]
	} else {
		if payload.no_transaction {
			after << '-no-transaction'
		}
		// "vsql out" only allows this for vsql.
		if payload.create_public_schema && payload.compat == '' {
			after << '-create-public-schema'
		}
		if payload.compat != '' {
			after << ['-compat', payload.compat]
		}
		if payload.contents != '' {
			after << '-${payload.contents}'
		}
		include, exclude := export_filters(payload.source, objects, payload.selected)
		for pattern in include {
			after << ['-include', pattern]
		}
		for pattern in exclude {
			after << ['-exclude', pattern]
		}
	}
	after << path
	params := []string{len: question_marks(payload.query).len, init: payload.params[index] or { '' }}

	return ExportCommand{
		params: if payload.format == 'sql' { []string{} } else { params }
		before: before
		file:   payload.file
		after:  after
	}
}

// str is the command to copy, for a POSIX shell.
fn (c ExportCommand) str() string {
	mut words := []string{}
	for i, value in c.params {
		words << 'P${i + 1}=${shell_quote(value)}'
	}
	words << 'vsql'
	words << c.before.map(shell_quote(it))
	if c.file != '' {
		words << ['-file', shell_quote(c.file)]
	}
	words << c.after.map(shell_quote(it))

	return words.join(' ')
}

// shell_quote leaves anything that's safe in a shell as it is, a flag or an option
// is easier to read that way.
fn shell_quote(word string) string {
	if word != '' && word.bytes().all(it.is_alnum() || it in [`-`, `_`, `.`, `/`, `:`, `,`, `=`,
		`@`, `%`, `+`]) {
		return word
	}

	return "'${word.replace("'", "'\\''")}'"
}

// run runs the command like it's shown, but the output comes back on stdout
// instead of going to the file.
fn (c ExportCommand) run() !string {
	mut env := os.environ()
	for i, value in c.params {
		env['P${i + 1}'] = value
	}
	mut process := os.new_process(os.executable())
	process.set_args(arrays_join(c.before, c.after))
	process.set_environment(env)
	process.set_redirect_stdio()
	process.run()
	mut output := strings.new_builder(4096)
	for process.is_alive() {
		chunk := process.stdout_read()
		if chunk == '' {
			time.sleep(time.millisecond)
		}
		output.write_string(chunk)
	}
	output.write_string(process.stdout_slurp())
	message := process.stderr_slurp()
	process.wait()
	code := process.code
	process.close()
	if code != 0 {
		return error(message.trim_space().trim_string_left('cli execution error: '))
	}

	return output.str()
}

fn arrays_join(a []string, b []string) []string {
	mut joined := a.clone()
	joined << b

	return joined
}

// export_form is the payload of a tab from what's posted. A file name that's
// been changed is kept, only its extension follows the format.
// export_compats and export_contents are the choices of a <select> as value and
// label. The first is the default, which isn't part of the command.
const export_compats = [['', 'vsql'], ['sqlite3', 'sqlite3'], ['mysql', 'mysql'],
	['postgresql', 'postgresql']]
const export_contents = [['', 'Schema and data'], ['schema-only', 'Schema only'],
	['data-only', 'Data only']]

// export_choice is a <select> of the form. Anything else is the default, because
// it would end up in the command.
fn export_choice(form urllib.Values, name string, choices [][]string) string {
	value := form.get(name) or { '' }

	return if choices.any(it[0] == value) { value } else { '' }
}

// export_select is the HTML of a <select>.
fn export_select(name string, label string, choices [][]string, value string) string {
	options := choices.map('<option value="${it[0]}"${if it[0] == value {
		' selected'
	} else {
		''
	}}>${it[1]}</option>').join('')

	return '<label><span class="field">${label}</span><select name="${name}">${options}</select></label>'
}

fn export_form(form urllib.Values, source string) ExportPayload {
	format := form.get('export_format') or { export_formats(source)[0] }
	mut params := []string{}
	for {
		params << form.get('export_param:${params.len + 1}') or { break }
	}

	return ExportPayload{
		source:               source
		format:               format
		file:                 with_extension(form.get('export_file') or { '' }, format)
		selected:             form.get_all('export_object')
		query:                form.get('export_query') or { '' }
		params:               params
		no_header:            (form.get('export_no_header') or { '' }) != ''
		null_value:           form.get('export_null') or { '' }
		no_transaction:       (form.get('export_no_transaction') or { '' }) != ''
		create_public_schema: (form.get('export_create_public_schema') or { '' }) != ''
		compat:               export_choice(form, 'export_compat', export_compats)
		contents:             export_choice(form, 'export_contents', export_contents)
	}
}

// write_export is an EXPORT tab, after the tabs. app_export.js asks the server for
// the command when anything changes. The form is closed.
fn (a &App) write_export(mut sb strings.Builder, mut conn vsql.Connection, tab Tab, result TabResult) ! {
	payload := json2.decode[ExportPayload](tab.payload)!
	objects := a.export_objects(mut conn, tab.catalog)!
	command := export_command(payload, objects, a.db_path(tab.catalog))
	sb.write_string('<div class="export"><div class="export-command"><pre class="sql">${html_escape(command.str())}</pre>')
	sb.write_string('<button type="button" class="copy-command">Copy</button></div>')
	if result.error != '' {
		sb.write_string('<p class="error">${html_escape(result.error)}</p>')
	}

	sb.write_string('<div class="export-formats"><span class="field">Format</span>')
	for format in export_formats(payload.source) {
		checked := if format == payload.format { ' checked' } else { '' }
		sb.write_string('<label><input type="radio" name="export_format" value="${format}"${checked}>${format.to_upper()}</label>')
	}
	sb.write_string('</div>')
	sb.write_string('<label class="export-file"><span class="field">File name</span><input name="export_file" spellcheck="false" value="${html_escape(payload.file)}"></label>')

	// Objects, for SQL.
	sb.write_string('<div class="export-sql" data-formats="sql"><div class="export-objects">')
	mut last_schema := ''
	for object in objects {
		if object.schema != last_schema {
			if last_schema != '' {
				sb.write_string('</ul></div>')
			}
			last_schema = object.schema
			// A schema without objects is itself what's selected.
			if object.name == '*' {
				checked := if object.key() in payload.selected { ' checked' } else { '' }
				sb.write_string('<div class="export-schema"><label><input type="checkbox" name="export_object" value="${html_escape(object.key())}"${checked}>${html_escape(object.schema)}</label><ul>')
				continue
			}
			sb.write_string('<div class="export-schema"><label><input type="checkbox" class="all">${html_escape(object.schema)}</label><ul>')
		}
		checked := if object.key() in payload.selected { ' checked' } else { '' }
		sb.write_string('<li><label><input type="checkbox" name="export_object" value="${html_escape(object.key())}"${checked}>${html_escape(object.name)} <span class="kind">${object.kind}</span></label></li>')
	}
	if last_schema != '' {
		sb.write_string('</ul></div>')
	}
	sb.write_string('</div>')
	no_transaction := if payload.no_transaction { ' checked' } else { '' }
	create_public := if payload.create_public_schema { ' checked' } else { '' }
	sb.write_string('<label><input type="checkbox" name="export_no_transaction" value="1"${no_transaction}>No transaction</label>')
	sb.write_string('<label><input type="checkbox" name="export_create_public_schema" value="1"${create_public}>Create the PUBLIC schema</label>')
	sb.write_string(export_select('export_compat', 'Compatible with', export_compats,
		payload.compat))
	sb.write_string(export_select('export_contents', 'Contents', export_contents, payload.contents))
	sb.write_string('</div>')

	// The query, for the other formats.
	sb.write_string('<div class="export-query" data-formats="csv tsv json"><label class="field">Query<textarea name="export_query" rows="6" spellcheck="false" placeholder="SELECT * FROM ...">${html_escape(payload.query)}</textarea></label>')
	sb.write_string('<div class="export-params">')
	for i in 0 .. question_marks(payload.query).len {
		sb.write_string(export_param_input(i + 1, payload.params[i] or { '' }))
	}
	sb.write_string('</div></div>')
	no_header := if payload.no_header { ' checked' } else { '' }
	sb.write_string('<div class="export-delimited" data-formats="csv tsv"><label><input type="checkbox" name="export_no_header" value="1"${no_header}>No header</label>')
	sb.write_string('<label>NULL is written as <input name="export_null" spellcheck="false" value="${html_escape(payload.null_value)}" placeholder="empty"></label></div>')

	sb.write_string('<div class="create-actions"><button type="submit" name="export_run" value="1" class="create">Export</button></div></div></form>')
}

// export_param_input is the value of a "?", also see app_export.js.
fn export_param_input(number int, value string) string {
	return '<label class="export-param">P${number} <input name="export_param:${number}" spellcheck="false" value="${html_escape(value)}" placeholder="empty, or \\N for NULL"></label>'
}

// db_path is the absolute path of a file, so the command works from any folder.
fn (a &App) db_path(catalog string) string {
	return os.real_path(a.db_files[a.catalog_names.index(catalog)])
}

// ExportPreview is the answer to app_export.js.
struct ExportPreview {
	command     string
	file        string
	param_count int
}

// export_tab_of is the EXPORT tab that was posted, and its payload from the form.
fn (a &App) export_tab_of(mut conn vsql.Connection, form urllib.Values) !(Tab, ExportPayload) {
	tab_ref := form.get('tab') or { '' }
	tab := a.tabs(mut conn)!.filter(it.ref() == tab_ref)[0] or {
		return error('no such tab: ${tab_ref}')
	}
	if tab.tab_type != export_tab {
		return error('not an export: ${tab_ref}')
	}

	return tab, export_form(form, json2.decode[ExportPayload](tab.payload)!.source)
}

// export_preview is what a tab would do with what's posted, which is also saved
// so that the options are still there when the tab is opened again.
fn (a &App) export_preview(form urllib.Values) !string {
	mut conn := a.open()!
	defer {
		conn.close()
	}
	tab, payload := a.export_tab_of(mut conn, form)!
	encoded := json2.encode(payload)
	if encoded != tab.payload {
		save_payload(mut conn, tab, encoded)!
	}
	command := export_command(payload, a.export_objects(mut conn, tab.catalog)!, a.db_path(tab.catalog))

	return json2.encode(ExportPreview{command.str(), payload.file, command.params.len})
}

// export_download runs a tab. The connection is closed first, so that "vsql out"
// isn't waiting for it.
fn (a &App) export_download(form urllib.Values) !Download {
	mut conn := a.open()!
	tab, payload := a.export_tab_of(mut conn, form) or {
		conn.close()
		return err
	}
	objects := a.export_objects(mut conn, tab.catalog) or {
		conn.close()
		return err
	}
	conn.close()
	output := ExportCommand{
		...export_command(payload, objects, a.db_path(tab.catalog))
		file: ''
	}.run()!
	content_type := match payload.format {
		'sql' { 'application/sql' }
		'csv' { 'text/csv' }
		'tsv' { 'text/tab-separated-values' }
		else { 'application/json' }
	}
	// Only the name is used, a folder in -file is on the command line.
	mut filename := payload.file.replace('\\', '/').all_after_last('/')
	if filename == '' {
		filename = export_file_name(tab.catalog, payload.format)
	}

	return Download{filename, '${content_type}; charset=utf-8', output}
}

// Download is a file that's exported.
struct Download {
	filename     string
	content_type string
	body         string
}
