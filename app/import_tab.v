// The IMPORT tab of "vsql app". It shows the command of "vsql in" and runs it, see
// cmd/vsql-cli/in_import.v for what the command does.
module app

import json2
import net.urllib
import os
import rand
import strings
import time
import vsql

// ImportPayload is the PAYLOAD (JSON) of an IMPORT tab. They're the options of the
// tab, the file itself isn't kept.
struct ImportPayload {
	schema string
	// table is an existing table, or empty for a new table.
	table       string
	on_error    string
	transaction bool
	// compat and ignore_unsupported are for a SQL file.
	compat             string
	ignore_unsupported bool
	// running_file is the file while it's being imported, so that the tab can say
	// if the import didn't finish because the app was stopped.
	running_file string
}

const import_compats = [['', 'vsql'], ['sqlite3', 'sqlite3']]
const import_on_error = [['stop', 'Stop on first failure'], ['continue', 'Continue']]

// ImportMessage is an ERROR, WARNING or NOTICE that "vsql in" printed, as kind (in
// lower case). line is 0 if it's not in the file.
struct ImportMessage {
	kind     string
	line     int
	sqlstate string
	message  string
}

// ImportOperation is how much of something was done, which is the sum of its
// counts: the rows for INSERT 200, and how many times for COMMIT.
pub struct ImportOperation {
pub:
	name string
pub mut:
	count int
}

// ImportReport is what happened, from the output of "vsql in".
struct ImportReport {
mut:
	operations []ImportOperation
	// messages are in the order they were printed.
	messages []ImportMessage
	// executed is the statements that are in the file.
	executed    int
	rolled_back bool
	left_open   bool
	// single_transaction is true if it's all in one transaction, which means that
	// nothing is kept if it doesn't finish.
	single_transaction bool
	// done is the bytes of the file that have been read.
	done i64
}

// add_line handles a line of output of "vsql in", see docs/cli.rst.
fn (mut r ImportReport) add_line(line string) {
	parts := line.split_nth(' ', 3)
	if parts.len != 3 || !parts[1].contains('/') {
		return
	}
	r.done = parts[1].all_before('/').i64()
	source := parts[0].int()
	message := parts[2]
	for kind in ['ERROR', 'WARNING', 'NOTICE'] {
		if message.starts_with('${kind} ') {
			words := message.split_nth(' ', 3)
			text := words[2] or { '' }
			r.messages << ImportMessage{kind.to_lower(), source, words[1], text}
			if text == import_left_open {
				r.left_open = true
			}
			return
		}
	}
	if source != 0 {
		r.executed++
	}
	match message {
		'START TRANSACTION' {
			if source == 0 {
				r.single_transaction = true
				return
			}
		}
		'COMMIT' {
			if source == 0 {
				return
			}
		}
		'ROLLBACK' {
			if source == 0 {
				r.rolled_back = true
				return
			}
		}
		else {}
	}
	r.add_result(message)
}

// import_left_open is the warning of a file that left a transaction open.
const import_left_open = 'the file left a transaction open'

// add_result counts the message of a statement, such as "INSERT 3" or "COMMIT".
fn (mut r ImportReport) add_result(message string) {
	words := message.fields()
	if words.len == 0 {
		return
	}
	last := words[words.len - 1]
	has_count := last.bytes().all(it.is_digit())
	name := if has_count { words[..words.len - 1].join(' ') } else { message }
	count := if has_count { last.int() } else { 1 }
	for mut operation in r.operations {
		if operation.name == name {
			operation.count += count
			return
		}
	}
	r.operations << ImportOperation{name, count}
}

fn (r &ImportReport) count_kind(kind string) int {
	return r.messages.filter(it.kind == kind).len
}

fn (r &ImportReport) count_of(name string) int {
	for operation in r.operations {
		if operation.name == name {
			return operation.count
		}
	}

	return 0
}

// summary is one line about what happened.
fn (r &ImportReport) summary(c ImportCommand) string {
	mut s := if c.format == 'sql' {
		'${c.file}: ${r.executed} ${vsql.pluralize(r.executed, 'statement')} executed'
	} else {
		rows := r.count_of('INSERT')
		'${c.file}: ${rows} ${vsql.pluralize(rows, 'row')} inserted'
	}
	failed := r.count_kind('error')
	if failed > 0 {
		s += ', ${failed} failed'
	}
	warnings := r.count_kind('warning')
	if warnings > 0 {
		s += ', ${warnings} ${vsql.pluralize(warnings, 'warning')}'
	}
	if r.left_open {
		s += '. The file left a transaction open, so it was rolled back'
	} else if r.rolled_back {
		s += '. It was rolled back, so nothing was changed'
	}

	return s
}

// import_messages_shown is the most messages on the page, and import_sql_shown is
// the most of each statement. A big file could otherwise make a huge page.
const import_messages_shown = 1000
const import_sql_shown = 500

// import_source is what's on a line of the file, up to the end of a statement for
// SQL.
fn import_source(lines []string, line int, format string) string {
	if line < 1 || line > lines.len {
		return ''
	}
	mut shown := []string{}
	for source in lines[line - 1..] {
		shown << source
		if format != 'sql' || source.trim_space().ends_with(';') || shown.len > 20 {
			break
		}
	}
	runes := shown.join('\n').trim_space().runes()

	return if runes.len > import_sql_shown {
		runes[..import_sql_shown].string() + '...'
	} else {
		runes.string()
	}
}

// result is the summary, and the failures with their own messages.
fn (r &ImportReport) result(c ImportCommand, text string, catalog string) TabResult {
	if r.executed == 0 && r.messages.len == 0 && c.format == 'sql' {
		return TabResult{
			error: '${c.file}: the file has no statements: nothing was imported'
		}
	}

	mut sb := strings.new_builder(1024)
	sb.write_string('<div class="import-report">')
	if c.table != '' && !r.rolled_back {
		sb.write_string('<button type="submit" form="app" name="query:${html_escape(catalog)}" value="${html_escape(c.table)}" class="view-table">View ${html_escape(c.table)}</button>')
	}
	if r.operations.len > 0 {
		sb.write_string('<table class="import-operations">')
		for operation in r.operations {
			sb.write_string('<tr><td>${html_escape(operation.name)}</td><td>${operation.count}</td></tr>')
		}
		sb.write_string('</table>')
	}
	if r.messages.len > 0 {
		lines := text.split_into_lines()
		sb.write_string('<ol class="import-messages">')
		for message in r.messages#[..import_messages_shown] {
			source := if message.kind == 'error' {
				import_source(lines, message.line, c.format)
			} else {
				''
			}
			title := if message.line > 0 { '<strong>Line ${message.line}</strong> ' } else { '' }
			shown := if source == '' { '' } else { '<pre class="sql">${html_escape(source)}</pre>' }
			sb.write_string('<li class="import-${message.kind}">${title}<span class="kind">${message.kind.to_upper()} ${html_escape(message.sqlstate)}</span> ${html_escape(message.message)}${shown}</li>')
		}
		sb.write_string('</ol>')
		if r.messages.len > import_messages_shown {
			sb.write_string('<p class="empty">And ${r.messages.len - import_messages_shown} more.</p>')
		}
	}
	sb.write_string('</div>')

	summary := r.summary(c)
	is_error := r.count_kind('error') > 0 || r.left_open

	return TabResult{
		output: sb.str()
		error:  if is_error { summary } else { '' }
		notice: if is_error { '' } else { summary }
	}
}

// open_import opens a new tab to import into a file. value is the schema and
// table from the menu it was chosen from (JSON), which are the first options of
// the tab. From the menu of a file, it's the PUBLIC schema.
fn (a &App) open_import(mut conn vsql.Connection, catalog string, value string) ! {
	names := json2.decode[[]string](value)!
	schema := names[0] or { 'PUBLIC' }
	table := names[1] or { '' }
	a.add_tab(mut conn, catalog, import_tab, 'Import', json2.encode(ImportPayload{
		schema:      schema
		table:       table
		on_error:    'stop'
		transaction: true
	}))!
}

fn import_form(form urllib.Values) ImportPayload {
	on_error := form.get('import_on_error') or { '' }

	return ImportPayload{
		schema:             form.get('import_schema') or { '' }
		table:              form.get('import_table') or { '' }
		on_error:           if on_error == 'continue' { on_error } else { 'stop' }
		transaction:        (form.get('import_transaction') or { '' }) != ''
		compat:             export_choice(form, 'import_compat', import_compats)
		ignore_unsupported: (form.get('import_ignore_unsupported') or { '' }) != ''
	}
}

// ImportCommand is "vsql in" with the options of a tab.
struct ImportCommand {
	file   string
	format string
	args   []string
	// table is the name of the table for "View", if the file goes into a table.
	table string
}

// import_name is a name as it's entered: upper case, unless it's in double
// quotes to keep its case. "vsql in" reads -schema and -table the same way.
fn import_name(name string) string {
	trimmed := name.trim_space()
	if trimmed.len >= 2 && trimmed[0] == `"` && trimmed[trimmed.len - 1] == `"` {
		return trimmed[1..trimmed.len - 1].replace('""', '"')
	}

	return trimmed.to_upper()
}

// import_quote is a name exactly, for -schema and -table (see import_name).
fn import_quote(name string) string {
	return if name == name.to_upper() { name } else { '"${name.replace('"', '""')}"' }
}

// import_command is built from what's posted. It's the only place that knows how
// the options become arguments, so what's shown is what's run. Each mapping is a
// field and its column, which is empty to skip the field. -map isn't needed if
// each field goes to the column with its name.
fn import_command(form urllib.Values, path string) !ImportCommand {
	options := import_form(form)
	format := form.get('import_format') or { '' }
	mut args := []string{}
	mut name := ''
	if options.schema != '' && options.schema != 'PUBLIC' {
		args << ['-schema', import_quote(options.schema)]
	}
	if format == 'sql' {
		if options.compat != '' {
			args << ['-compat', options.compat]
		}
		if options.ignore_unsupported {
			args << '-ignore-unsupported'
		}
		if options.transaction {
			args << '-single-transaction'
		}
	} else {
		mut pairs := json2.decode[[][]string](form.get('import_mapping') or { '[]' })!
		if options.table != '' {
			name = options.table
			args << ['-table', import_quote(options.table)]
		} else {
			name = import_name(form.get('import_new') or { '' })
			args << ['-table', (form.get('import_new') or { '' }).trim_space()]
			columns := json2.decode[[][]string](form.get('import_columns') or { '[]' })!
			args << ['-create-table', columns.map('${import_column_sql(it[0])} ${it[1]}').join(', ')]
			pairs = pairs.map(if it[1] == '' { it } else { [it[0], import_name(it[1])] })
		}
		if !pairs.all(it[1] == it[0] || it[1] == it[0].to_upper()) {
			for pair in pairs {
				if pair[1] != '' {
					args << ['-map', '${pair[0]}=${pair[1]}']
				}
			}
		}
	}
	if options.on_error == 'continue' {
		args << '-continue-on-error'
	}
	args << path

	table := if name == '' {
		''
	} else {
		vsql.Identifier{
			schema_name: if options.schema == '' { 'PUBLIC' } else { options.schema }
			entity_name: name
		}.str()
	}

	return ImportCommand{form.get('import_file') or { '' }, format, args, table}
}

// import_column_sql is a column name for -create-table, as it's entered. It's only
// quoted if it needs to be.
fn import_column_sql(name string) string {
	return vsql.Identifier{
		sub_entity_name: import_name(name)
	}.str()
}

// str is the command to copy, for a POSIX shell. It's run from the folder of the
// file.
fn (c ImportCommand) str() string {
	mut words := ['vsql', 'in', '-file', shell_quote(c.file)]
	words << c.args.map(shell_quote(it))

	return words.join(' ')
}

// import_cancelled is the error of a command that was cancelled.
const import_cancelled = 'cancelled'

// run runs the command like it's shown, but the file comes from stdin instead of
// -file since the browser only has its contents, and -verbose is how the progress
// goes to the job of the tab. Cancelling kills the process, which leaves the file as
// if an open transaction was never started.
fn (c ImportCommand) run(a &App, tab_ref string, text string) !ImportReport {
	stdin_path := os.join_path(os.temp_dir(), 'vsql-import-${rand.ulid()}')
	mut stdin_file := os.open_file(stdin_path, 'w', 0o600)!
	defer {
		os.rm(stdin_path) or {}
	}
	stdin_file.write_string(text)!
	stdin_file.close()

	mut process := os.new_process(os.executable())
	process.set_args(arrays_join(['in', '-format', c.format, '-verbose'], c.args))
	process.set_stdin_path(stdin_path)
	process.set_redirect_stdio()
	process.run()
	mut report := ImportReport{}
	mut output := ''
	mut killed := false
	for process.is_alive() {
		if !killed && a.import_job(tab_ref).cancelled {
			process.signal_kill()
			killed = true
		}
		// Reading would wait for the next line, which can be a long time.
		chunk := if process.is_pending(.stdout) { process.stdout_read() } else { '' }
		if chunk == '' {
			time.sleep(20 * time.millisecond)
			continue
		}
		output += chunk
		for output.contains('\n') {
			report.add_line(output.all_before('\n'))
			output = output.all_after('\n')
		}
		a.update_import_progress(tab_ref, report, text.len)
	}
	output += process.stdout_slurp()
	message := process.stderr_slurp()
	process.wait()
	code := process.code
	process.close()
	if killed {
		a.update_import_progress(tab_ref, report, text.len)
		return error(import_cancelled)
	}
	for line in output.split('\n') {
		report.add_line(line)
	}
	if code != 0 && report.count_kind('error') == 0 {
		return error(message.trim_space().trim_string_left('cli execution error: '))
	}

	return report
}

// update_import_progress is what the progress of a tab shows. total is the size of
// the file, which "vsql in" doesn't know since it comes from stdin.
fn (a &App) update_import_progress(tab_ref string, report ImportReport, total int) {
	lock a.imports {
		if job := a.imports[tab_ref] {
			a.imports[tab_ref] = ImportJob{
				...job
				progress: ImportProgress{report.done, total, report.single_transaction, report.operations, report.messages#[..import_messages_shown].clone()}
			}
		}
	}
}

// ImportProgress is the progress of a tab, in bytes of the file.
struct ImportProgress {
	done               i64
	total              i64
	single_transaction bool
	operations         []ImportOperation
	messages           []ImportMessage
}

// ImportJob is a file being imported by a tab, in the background. The other tabs
// can be used in the meantime.
struct ImportJob {
	file     string
	progress ImportProgress
	// cancelled is true once Cancel is chosen. closed is true if the tab was closed.
	cancelled bool
	closed    bool
}

// import_job is the job of a tab, if there is one.
fn (a &App) import_job(tab_ref string) ImportJob {
	return rlock a.imports {
		a.imports[tab_ref] or { ImportJob{} }
	}
}

fn (a &App) is_importing(tab_ref string) bool {
	return rlock a.imports {
		tab_ref in a.imports
	}
}

// cancel_import is Cancel on a tab, or closing it.
fn (a &App) cancel_import(tab_ref string, closed bool) {
	lock a.imports {
		if job := a.imports[tab_ref] {
			a.imports[tab_ref] = ImportJob{
				...job
				cancelled: true
				closed:    closed
			}
		}
	}
}

// ImportStatus is the answer to app_import_progress.js.
struct ImportStatus {
	running   bool
	cancelled bool
	progress  ImportProgress
}

fn (a &App) import_status(tab_ref string) string {
	job := a.import_job(tab_ref)

	return json2.encode(ImportStatus{a.is_importing(tab_ref), job.cancelled, job.progress})
}

// import_tab_of is the IMPORT tab that was posted.
fn (a &App) import_tab_of(mut conn vsql.Connection, form urllib.Values) !Tab {
	tab_ref := form.get('tab') or { '' }
	tab := a.tabs(mut conn)!.filter(it.ref() == tab_ref)[0] or {
		return error('no such tab: ${tab_ref}')
	}
	if tab.tab_type != import_tab {
		return error('not an import: ${tab_ref}')
	}

	return tab
}

// ImportPreview is the answer to app_import.js.
struct ImportPreview {
	command string
}

// import_preview is the command of a tab with what's posted, which is also saved
// so that the options are still there when the tab is opened again.
fn (a &App) import_preview(form urllib.Values) !string {
	mut conn := a.open()!
	defer {
		conn.close()
	}
	tab := a.import_tab_of(mut conn, form)!
	encoded := json2.encode(import_form(form))
	if encoded != tab.payload {
		save_payload(mut conn, tab, encoded)!
	}

	return json2.encode(ImportPreview{import_command(form, a.db_path(tab.catalog))!.str()})
}

// start_import starts a tab, which runs in the background. A tab can only be
// importing one file at a time.
fn (a &App) start_import(form urllib.Values, text string) ! {
	mut conn := a.open()!
	defer {
		conn.close()
	}
	tab := a.import_tab_of(mut conn, form)!
	file := form.get('import_file') or { '' }
	command := import_command(form, a.db_path(tab.catalog))!
	mut started := false
	lock a.imports {
		if tab.ref() !in a.imports {
			a.imports[tab.ref()] = ImportJob{
				file: file
			}
			started = true
		}
	}
	if !started {
		return
	}
	lock a.results {
		a.results.delete(tab.ref())
	}
	save_payload(mut conn, tab, json2.encode(ImportPayload{
		...import_form(form)
		running_file: file
	}))!
	title_tab(mut conn, tab, 'Import ${file}')!
	spawn a.run_import(tab, command, file, text)
}

// run_import runs in the background, and what happened is the result of the tab.
fn (a &App) run_import(tab Tab, command ImportCommand, file string, text string) {
	result := if report := command.run(a, tab.ref(), text) {
		report.result(command, text, tab.catalog)
	} else {
		import_failed(a, tab, file, err)
	}

	job := a.import_job(tab.ref())
	if !job.closed {
		a.finish_import_payload(tab) or {}
		lock a.results {
			a.results[tab.ref()] = result
		}
	}
	lock a.imports {
		a.imports.delete(tab.ref())
	}
}

// import_failed is the result of a command that didn't finish.
fn import_failed(a &App, tab Tab, file string, err IError) TabResult {
	if err.msg() != import_cancelled {
		return TabResult{
			error: '${file}: ${err.msg()}: nothing was imported'
		}
	}
	reason := if a.import_job(tab.ref()).progress.single_transaction {
		'It was in one transaction, so nothing was changed'
	} else {
		'What had already run was kept'
	}

	return TabResult{
		notice: '${file}: it was cancelled. ${reason}'
	}
}

// finish_import_payload saves that the tab is no longer importing.
fn (a &App) finish_import_payload(tab Tab) ! {
	mut conn := a.open()!
	defer {
		conn.close()
	}
	save_payload(mut conn, tab, json2.encode(ImportPayload{
		...json2.decode[ImportPayload](a.tabs(mut conn)!.filter(it.ref() == tab.ref())[0] or {
			return
		}.payload)!
		running_file: ''
	}))!
}

// write_import_progress is an IMPORT tab while it's importing, which is kept up to
// date by app_import_progress.js. The form is closed.
fn write_import_progress(mut sb strings.Builder, job ImportJob) {
	sb.write_string('<div class="import import-running"><p class="import-status">Importing ${html_escape(job.file)}</p>')
	sb.write_string('<p class="import-bar-row"><progress class="import-bar"></progress> <span class="import-percent"></span></p>')
	sb.write_string('<table class="import-operations" hidden></table><ol class="import-messages" hidden></ol>')
	sb.write_string('<div class="create-actions"><button type="submit" name="import_cancel" value="1" class="delete import-cancel">Cancel</button></div></div></form>')
}

// ImportTable is a table that a file can be imported into, without the columns
// that can't be assigned.
struct ImportTable {
	name    string
	columns []string
}

struct ImportSchema {
	name   string
	tables []ImportTable
}

// import_schemas is everything that can be chosen on an IMPORT tab, by name.
fn (a &App) import_schemas(mut conn vsql.Connection, catalog_name string) ![]ImportSchema {
	set_catalog(mut conn, catalog_name)!
	mut cat := conn.catalog()
	mut names := cat.schemas()!.filter(!it.is_virtual && it.name != 'VSQL_APP').map(it.name)
	names.sort()
	mut tables := map[string][]string{}
	for name in names {
		tables[name] = cat.schema_tables(name)!.map(it.name.entity_name)
		tables[name].sort()
	}

	mut schemas := []ImportSchema{}
	for name in names {
		mut schema_tables := []ImportTable{}
		for table in tables[name] {
			found := a.find_edit_table(mut conn, catalog_name, name, table)!
			schema_tables << ImportTable{table, found.columns.filter(!it.generated).map(it.name)}
		}
		schemas << ImportSchema{name, schema_tables}
	}
	set_catalog(mut conn, a.catalog_names[0])!

	return schemas
}

// write_import is an IMPORT tab, after the tabs. The options depend on the file
// that's chosen and it shows the command of "vsql in", see app_import.js. The form
// is closed.
fn (a &App) write_import(mut sb strings.Builder, mut conn vsql.Connection, tab Tab) ! {
	if a.is_importing(tab.ref()) {
		write_import_progress(mut sb, a.import_job(tab.ref()))
		return
	}
	payload := json2.decode[ImportPayload](tab.payload)!
	schemas := a.import_schemas(mut conn, tab.catalog)!
	sb.write_string('<div class="import" data-table="${html_escape(payload.table)}" data-schemas="${html_escape(json2.encode(schemas))}">')
	if payload.running_file != '' {
		sb.write_string('<p class="error">The import of ${html_escape(payload.running_file)} was interrupted because the app was stopped.</p>')
	}
	sb.write_string('<label class="import-choose"><span class="field">File</span><input type="file" class="import-file" accept="${import_formats}"></label>')
	sb.write_string('<p class="import-message" hidden></p>')
	sb.write_string('<div class="export-command import-command" hidden><pre class="sql"></pre><button type="button" class="copy-command">Copy</button></div>')
	sb.write_string('<table class="import-stats" hidden></table>')
	sb.write_string('<div class="import-options" hidden>')
	sb.write_string(export_select('import_schema', 'Schema', schemas.map([
		html_escape(it.name),
		html_escape(it.name),
	]), html_escape(payload.schema)))
	sb.write_string('<div data-formats="sql"><p class="import-hint">Statements that don&#39;t name a schema run in this schema.</p>')
	sb.write_string(export_select('import_compat', 'Compatible with', import_compats, payload.compat))
	ignore_unsupported := if payload.ignore_unsupported { ' checked' } else { '' }
	sb.write_string('<label><input type="checkbox" name="import_ignore_unsupported" value="1"${ignore_unsupported}>Ignore CREATE VIEW, CREATE TRIGGER and CREATE INDEX</label></div>')
	sb.write_string('<div data-formats="csv tsv json">')
	sb.write_string('<label><span class="field">Table</span><select name="import_table"></select></label>')
	sb.write_string('<label class="import-new"><span class="field">Table name</span><input name="import_new" spellcheck="false" placeholder="NAME"></label>')
	sb.write_string('<table class="import-map"><thead><tr><th>Field in the file</th><th>Column</th><th class="import-type">Type</th></tr></thead><tbody></tbody></table><datalist id="import-types"></datalist></div>')
	sb.write_string(export_select('import_on_error', 'On failure', import_on_error, payload.on_error))
	transaction := if payload.transaction { ' checked' } else { '' }
	sb.write_string('<label data-formats="sql"><input type="checkbox" name="import_transaction" value="1"${transaction}>Run in one transaction</label>')
	for name in ['import_format', 'import_file', 'import_mapping', 'import_columns'] {
		sb.write_string('<input type="hidden" name="${name}">')
	}
	sb.write_string('<input type="hidden" name="import_text" disabled>')
	sb.write_string('<div class="create-actions"><button type="submit" class="create import-run">Import</button></div></div></div></form>')
}
