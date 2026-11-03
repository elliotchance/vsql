// The web server of "vsql app", see docs/cli.rst.
module app

import io
import json2
import net
import net.urllib
import sync
import time
import vsql

// serve runs the web server on host and port for the files (see App). It
// doesn't return unless it can't start.
pub fn serve(paths []string, host string, port int) ! {
	// The other files are attached as catalogs, named after their file. The
	// names must be unique. Each request opens the files again (see below), so
	// an in-memory database would be empty for each request.
	mut catalog_names := []string{}
	for path in paths {
		if path == ':memory:' {
			return error('${path}: an in-memory database is not supported, use a file')
		}
		name := vsql.catalog_name_from_path(path)
		if name in catalog_names {
			return error('${path}: there is already a catalog named "${name}" (catalogs are named after their file, up to the first ".")')
		}
		catalog_names << name
	}

	// Each request opens its own connection (so it sees the latest committed
	// data), they must share the same mutex for each file like the server, see
	// ConnectionOptions. A query that uses more than one catalog locks each of
	// them, so they can't share a mutex.
	mut options := []vsql.ConnectionOptions{}
	for _ in paths {
		mut file_options := vsql.default_connection_options()
		file_options.mutex = sync.new_rwmutex()
		options << file_options
	}

	mut family := net.AddrFamily.ip
	mut address := '${host}:${port}'
	if host.contains(':') {
		family = .ip6
		address = '[${host}]:${port}'
	}
	mut listener := net.listen_tcp(family, address) or {
		return error('cannot listen on ${address}: ${err}')
	}
	println('ready on http://${listener.addr()!}')

	for i, path in paths {
		create_app_tables(path, options[i])!
	}

	a := &App{
		db_files:      paths
		catalog_names: catalog_names
		options:       options
	}
	for {
		mut conn := listener.accept() or { continue }
		spawn a.handle(mut conn)
	}
}

struct App {
	// db_files are the files opened, each has its own VSQL_APP and the first one
	// is the current catalog. catalog_names and options are for each file.
	db_files      []string
	catalog_names []string
	options       []vsql.ConnectionOptions
mut:
	// results is the last result of each tab (by id), so it's shown again
	// without running the tab when switching back to it. They are not kept
	// when the app is restarted.
	results shared map[string]TabResult
	// imports are the files being imported, by tab (see import_tab.v).
	imports shared map[string]ImportJob
}

// handle answers a single HTTP request and closes the connection. A GET shows
// the active tab. The tabs and editor are one form that POSTs with the
// current tab, so the SQL in the editor is always saved before running it, or
// switching, adding or closing a tab.
fn (a &App) handle(mut conn net.TcpConn) {
	defer {
		conn.close() or {}
	}
	conn.set_read_timeout(10 * time.second)
	mut reader := io.new_buffered_reader(reader: conn)
	defer {
		reader.free()
	}

	// For example: "GET / HTTP/1.1"
	parts := (reader.read_line() or { return }).split(' ')
	if parts.len != 3 {
		write_response(mut conn, '400 Bad Request', 'text/plain', 'bad request')
		return
	}
	method, url := parts[0], parts[1]
	if method !in ['GET', 'POST'] || url.all_before('?') != '/' {
		write_response(mut conn, '404 Not Found', 'text/plain', 'not found')
		return
	}

	mut content_length := 0
	for {
		line := reader.read_line() or { return }
		if line == '' {
			break
		}
		if line.to_lower().starts_with('content-length:') {
			content_length = line.all_after(':').trim_space().int()
		}
	}

	mut body := []u8{len: content_length}
	mut n := 0
	for n < content_length {
		n += reader.read(mut body[n..]) or { return }
	}

	form := urllib.parse_query(body.bytestr()) or { urllib.new_values() }
	// The command of an EXPORT tab as its options change, see export.v.
	if _ := form.get('export_command') {
		preview := a.export_preview(form) or {
			write_response(mut conn, '400 Bad Request', 'text/plain; charset=utf-8', err.msg())
			return
		}
		write_response(mut conn, '200 OK', 'application/json', preview)
		return
	}
	// The command of an IMPORT tab as its options change, see import.v.
	if _ := form.get('import_command') {
		preview := a.import_preview(form) or {
			write_response(mut conn, '400 Bad Request', 'text/plain; charset=utf-8', err.msg())
			return
		}
		write_response(mut conn, '200 OK', 'application/json', preview)
		return
	}
	// How an IMPORT tab is going, see import_tab.v.
	if _ := form.get('import_status') {
		write_response(mut conn, '200 OK', 'application/json', a.import_status(form.get('tab') or {
			''
		}))
		return
	}
	if _ := form.get('import_cancel') {
		a.cancel_import(form.get('tab') or { '' }, false)
		conn.write_string('HTTP/1.0 303 See Other\r\nLocation: /\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or {}
		return
	}
	// Load on a tab of demo data, with the file that the browser downloaded. It runs
	// in the background like any other file.
	if demo_text := form.get('demo_text') {
		a.start_demo(form, demo_text) or {
			write_response(mut conn, '500 Internal Server Error', 'text/plain', err.msg())
			return
		}
		conn.write_string('HTTP/1.0 303 See Other\r\nLocation: /\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or {}
		return
	}
	// The file of an IMPORT tab is only posted by its Import button. It runs in the
	// background.
	if import_text := form.get('import_text') {
		a.start_import(form, import_text) or {
			write_response(mut conn, '500 Internal Server Error', 'text/plain', err.msg())
			return
		}
		conn.write_string('HTTP/1.0 303 See Other\r\nLocation: /\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or {}
		return
	}
	// Export is a download so the page isn't changed, unless it fails and then the
	// error is shown on the tab.
	if _ := form.get('export_run') {
		a.respond(true, form) or {}
		ref := form.get('tab') or { '' }
		if download := a.export_download(form) {
			lock a.results {
				a.results[ref] = TabResult{}
			}
			// The filename is quoted, so it can't have a quote.
			filename := download.filename.runes().map(if it < ` ` || it == `"` { `_` } else { it }).string()
			conn.write_string('HTTP/1.0 200 OK\r\nContent-Type: ${download.content_type}\r\nContent-Disposition: attachment; filename="${filename}"\r\nContent-Length: ${download.body.len}\r\nConnection: close\r\n\r\n${download.body}') or {}
			return
		} else {
			lock a.results {
				a.results[ref] = TabResult{
					error: err.msg()
				}
			}
			conn.write_string('HTTP/1.0 303 See Other\r\nLocation: /\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or {}
			return
		}
	}
	response := a.respond(method == 'POST', form) or {
		write_response(mut conn, '500 Internal Server Error', 'text/plain', err.msg())
		return
	}
	if response.starts_with('/') {
		conn.write_string('HTTP/1.0 303 See Other\r\nLocation: ${response}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or {}
	} else {
		write_response(mut conn, '200 OK', 'text/html; charset=utf-8', response)
	}
}

fn write_response(mut conn net.TcpConn, status string, content_type string, body string) {
	conn.write_string('HTTP/1.0 ${status}\r\nContent-Type: ${content_type}\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or {}
}

// open opens the first file, and attaches the others as catalogs.
fn (a &App) open() !&vsql.Connection {
	mut conn := vsql.open_database(a.db_files[0], a.options[0])!
	for i, path in a.db_files {
		if i > 0 {
			conn.add_catalog(a.catalog_names[i], path, a.options[i])!
		}
	}

	return conn
}

// respond returns the page, or the URL (starting with /) to redirect to.
fn (a &App) respond(is_post bool, form urllib.Values) !string {
	mut conn := a.open()!
	defer {
		conn.close()
	}

	all_tabs := a.tabs(mut conn)!

	// Showing a tab doesn't run it (that's only done with Run), it shows the
	// last result.
	if !is_post {
		tab := all_tabs.filter(it.active)[0] or { no_tab }
		result := rlock a.results {
			a.results[tab.ref()] or { TabResult{} }
		}
		return a.page(mut conn, all_tabs, tab, result, Confirm{})
	}

	tab_ref := form.get('tab') or { '' }
	tab := all_tabs.filter(it.ref() == tab_ref)[0] or { no_tab }
	query_text := form.get('sql') or { tab.query_text }
	// The value and type of each "?" are posted with the SQL.
	params := if _ := form.get('sql') { posted_params(form) } else { tab.params }
	payload := if tab.tab_type == export_tab && (form.get('export_file') or { '\0' }) != '\0' {
		json2.encode(export_form(form, json2.decode[ExportPayload](tab.payload)!.source))
	} else if tab.tab_type == import_tab && (form.get('import_schema') or { '\0' }) != '\0' {
		json2.encode(import_form(form))
	} else if tab.tab_type == import_tab && (form.get('demo_schema') or { '\0' }) != '\0' {
		json2.encode(demo_form(form))
	} else {
		form.get('payload') or { tab.payload }
	}
	if tab.tab_type == query_tab && tab.id != no_tab.id {
		save_tab(mut conn, tab, query_text, params)!
	}
	if tab.tab_type != query_tab && payload != tab.payload {
		save_payload(mut conn, tab, payload)!
	}
	// With no tab, a new tab is in the first file.
	catalog := if tab.id == no_tab.id { a.catalog_names[0] } else { tab.catalog }

	// Export on a query tab opens a new tab to export it.
	if tab.tab_type == query_tab && tab.id != no_tab.id && (form.get('export_query_tab') or { '' }) != '' {
		a.open_query_export(mut conn, tab, query_text, params)!
		return '/'
	}

	for file in a.catalog_names {
		// Export in the menu of a file, schema or table opens a new tab to export it.
		if value := form.get('export:${file}') {
			a.open_export(mut conn, file, value)!
			return '/'
		}
		// Load demo data in the menu of a file opens a new tab to choose it.
		if _ := form.get('demo:${file}') {
			a.open_demo(mut conn, file)!
			return '/'
		}
		// Import in the menu of a file, schema or table opens a new tab to import
		// into it.
		if value := form.get('import:${file}') {
			a.open_import(mut conn, file, value)!
			return '/'
		}
		// A table in the sidebar opens a new tab of its file that runs SELECT * on
		// it. The tab runs in that file, so the query doesn't need the catalog.
		if table := form.get('query:${file}') {
			a.query_table(mut conn, file, table)!
			return '/'
		}
		// A table or schema in the sidebar is dropped (such as "TABLE FOO.BAR" or
		// "SCHEMA FOO CASCADE") in its file once it's confirmed. Then the tab is
		// shown again, its result isn't run again.
		if object := form.get('drop:${file}') {
			last := rlock a.results {
				a.results[tab.ref()] or { TabResult{} }
			}
			return a.page(mut conn, all_tabs, Tab{
				...tab
				query_text: query_text
				params:     params
				payload:    payload
			}, last, Confirm{'DROP ${object}', 'drop_confirmed:${file}', object, file})
		}
		if object := form.get('drop_confirmed:${file}') {
			a.run_in_file(mut conn, file, 'DROP ${object}') or {
				last := rlock a.results {
					a.results[tab.ref()] or { TabResult{} }
				}
				return a.page(mut conn, all_tabs, tab, TabResult{
					...last
					error: err.msg()
				}, Confirm{})
			}
			return '/'
		}
		// A table in the sidebar (its schema and name as JSON) opens a new tab of
		// its file to alter it.
		if table := form.get('alter:${file}') {
			names := json2.decode[[]string](table)!
			if names.len != 2 {
				return error('bad table: ${table}')
			}
			a.add_tab(mut conn, file, alter_table_tab, 'Alter ${names[1]}', a.alter_table_payload(mut conn,
				file, names[0], names[1])!)!
			return '/'
		}
		// A schema in the sidebar opens a new tab of its file to create a table in
		// it.
		if schema := form.get('add_table:${file}') {
			a.add_tab(mut conn, file, create_table_tab, 'New table', new_table_payload(schema))!
			return '/'
		}
	}
	// Create schema in the menu of a catalog posts the CREATE SCHEMA.
	if create_schema := form.get('create_schema') {
		schema_catalog := form.get('create_schema_catalog') or { '' }
		if schema_catalog !in a.catalog_names {
			return error('no such catalog: ${schema_catalog}')
		}
		a.run_in_file(mut conn, schema_catalog, create_schema) or {
			last := rlock a.results {
				a.results[tab.ref()] or { TabResult{} }
			}
			return a.page(mut conn, all_tabs, Tab{
				...tab
				query_text: query_text
				params:     params
				payload:    payload
			}, TabResult{
				...last
				error: err.msg()
			}, Confirm{})
		}
		return '/'
	}
	if other_tab := form.get('goto') {
		a.activate_tab(mut conn, all_tabs.filter(it.ref() == other_tab)[0] or { no_tab })!
		return '/'
	}
	// The sidebar adds a tab to its file, the tab bar to the file of the tab.
	if new_catalog := form.get('new') {
		a.add_query_tab(mut conn, if new_catalog in a.catalog_names { new_catalog } else { catalog },
			show_tables_sql)!
		return '/'
	}
	if close := form.get('close') {
		for t in all_tabs {
			if t.ref() == close {
				a.close_tab(mut conn, t, tab)!
			}
		}
		return '/'
	}
	// The history tab shows the history of a file, a query from it opens in a new
	// tab of that file without running it.
	if history_catalog := form.get('history') {
		a.show_history_tab(mut conn, all_tabs, if history_catalog in a.catalog_names {
			history_catalog
		} else {
			a.catalog_names[0]
		})!
		return '/'
	}
	if open_sql := form.get('open') {
		a.add_query_tab(mut conn, catalog, open_sql)!
		return '/'
	}

	// An ALTER_TABLE tab is closed once its statements are run (in a
	// transaction), and the table is queried in a new tab of the file. If it
	// fails, nothing is changed and the error is shown on the tab.
	if tab.tab_type == alter_table_tab {
		if _ := form.get('alter_table') {
			a.run_in_transaction(mut conn, tab.catalog, form.get('alter_sql') or { '' }) or {
				return a.page(mut conn, all_tabs, Tab{
					...tab
					payload: payload
				}, TabResult{
					error: err.msg()
				}, Confirm{})
			}
			a.close_tab(mut conn, tab, tab)!
			a.query_table(mut conn, tab.catalog, json2.decode[AlterTablePayload](payload)!.table)!
		}
		return '/'
	}
	// A CREATE_TABLE tab is closed once the table is created, and the table
	// (which is empty) is queried in a new tab of the file. If it fails, the error
	// is shown on the tab. Anything else (such as saving the payload) shows it
	// again.
	if tab.tab_type == create_table_tab {
		if _ := form.get('create_table') {
			a.run_in_file(mut conn, tab.catalog, form.get('create_sql') or { '' }) or {
				return a.page(mut conn, all_tabs, Tab{
					...tab
					payload: payload
				}, TabResult{
					error: err.msg()
				}, Confirm{})
			}
			a.close_tab(mut conn, tab, tab)!
			a.query_table(mut conn, tab.catalog, form.get('created_table') or { '' })!
		}
		return '/'
	}
	if tab.id == no_tab.id || tab.tab_type != query_tab {
		return '/'
	}

	// The changes to the rows of an editable result (see edit.v), which all
	// run in one transaction. If they fail, the page has the error and
	// app_edit.js keeps the changes to try again.
	if changes := form.get('changes') {
		last := rlock a.results {
			a.results[tab.ref()] or { TabResult{} }
		}
		table := a.find_edit_table(mut conn, form.get('catalog') or { '' }, form.get('schema') or {
			''
		}, form.get('table') or { '' })!
		mut queries := []string{}
		for i in 0 .. changes.int() {
			queries << build_change(table, change_form(form, i)) or {
				return a.page(mut conn, all_tabs, tab, TabResult{
					...last
					error: err.msg()
				}, Confirm{})
			}
		}
		a.apply_changes(mut conn, tab, queries, query_text, params) or {
			return a.page(mut conn, all_tabs, tab, TabResult{
				...last
				error: err.msg()
			}, Confirm{})
		}
		return '/'
	}

	result, h := a.run_query(mut conn, query_text, params, catalog)!
	add_history(mut conn, catalog, tab.id, h)!
	lock a.results {
		a.results[tab.ref()] = result
	}
	title_tab(mut conn, tab, query_text)!
	a.activate_tab(mut conn, tab)!
	return a.page(mut conn, a.tabs(mut conn)!, Tab{tab.id, tab.tab_type, tab_title(query_text), query_text, true, params, '', catalog},
		result, Confirm{})
}

// run_in_transaction runs every statement with a file as the current catalog,
// or none of them if one fails.
fn (a &App) run_in_transaction(mut conn vsql.Connection, catalog string, statements string) ! {
	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	conn.query('START TRANSACTION')!
	for stmt in vsql.split_statements(statements) {
		conn.query(stmt) or {
			conn.query('ROLLBACK') or {}
			return err
		}
	}
	conn.query('COMMIT')!
}

// query_table opens a new tab of a file that runs SELECT * on a table.
fn (a &App) query_table(mut conn vsql.Connection, catalog string, table string) !Tab {
	table_sql := 'SELECT * FROM ${table}'
	new_tab := a.add_query_tab(mut conn, catalog, table_sql)!
	result, h := a.run_query(mut conn, table_sql, Params{}, catalog)!
	add_history(mut conn, catalog, new_tab.id, h)!
	lock a.results {
		a.results[new_tab.ref()] = result
	}

	return new_tab
}

// run_in_file runs SQL with a file as the current catalog.
fn (a &App) run_in_file(mut conn vsql.Connection, catalog string, query_text string) ! {
	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	conn.query(query_text)!
}

// apply_changes runs the changes to the rows (see run_changes), then the SQL
// of the tab again for its result.
fn (a &App) apply_changes(mut conn vsql.Connection, tab Tab, queries []string, query_text string, params Params) ! {
	run_changes(mut conn, queries)!
	result, _ := a.run_query(mut conn, query_text, params, tab.catalog)!
	lock a.results {
		a.results[tab.ref()] = TabResult{
			...result
			status: 'Saved ${queries.len} ${vsql.pluralize(queries.len, 'change')}, ${result.status}'
		}
	}
}
