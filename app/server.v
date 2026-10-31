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

	create_app_tables(paths[0], options[0])!

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
	// db_files are the files opened, the first one has VSQL_APP.TABS and is the
	// current catalog. catalog_names and options are for each file.
	db_files      []string
	catalog_names []string
	options       []vsql.ConnectionOptions
mut:
	// results is the last result of each tab (by id), so it's shown again
	// without running the tab when switching back to it. They are not kept
	// when the app is restarted.
	results shared map[int]TabResult
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

	all_tabs := tabs(mut conn)!

	// Showing a tab doesn't run it (that's only done with Run), it shows the
	// last result.
	if !is_post {
		tab := all_tabs.filter(it.active)[0] or { no_tab }
		result := rlock a.results {
			a.results[tab.id] or { TabResult{} }
		}
		return a.page(mut conn, all_tabs, tab, result, Confirm{})
	}

	tab_id := (form.get('tab') or { '' }).int()
	tab := all_tabs.filter(it.id == tab_id)[0] or { no_tab }
	query_text := form.get('sql') or { tab.query_text }
	payload := form.get('payload') or { tab.payload }
	if tab.tab_type == query_tab && tab.id != no_tab.id {
		save_tab(mut conn, tab.id, query_text)!
	}
	if tab.tab_type != query_tab && payload != tab.payload {
		save_payload(mut conn, tab.id, payload)!
	}

	// A table in the sidebar opens a new tab that runs SELECT * on it.
	if table := form.get('query') {
		a.query_table(mut conn, table)!
		return '/'
	}
	// A table or schema in the sidebar is dropped (such as "TABLE FOO.BAR" or
	// "SCHEMA FOO CASCADE") once it's confirmed. Then the tab is shown again,
	// its result isn't run again.
	if object := form.get('drop') {
		last := rlock a.results {
			a.results[tab.id] or { TabResult{} }
		}
		return a.page(mut conn, all_tabs, Tab{
			...tab
			query_text: query_text
			payload:    payload
		}, last, Confirm{'DROP ${object}', 'drop_confirmed', object})
	}
	if object := form.get('drop_confirmed') {
		conn.query('DROP ${object}') or {
			last := rlock a.results {
				a.results[tab.id] or { TabResult{} }
			}
			return a.page(mut conn, all_tabs, tab, TabResult{
				...last
				error: err.msg()
			}, Confirm{})
		}
		return '/'
	}
	// Create schema in the menu of a catalog posts the CREATE SCHEMA.
	if create_schema := form.get('create_schema') {
		conn.query(create_schema) or {
			last := rlock a.results {
				a.results[tab.id] or { TabResult{} }
			}
			return a.page(mut conn, all_tabs, Tab{
				...tab
				query_text: query_text
				payload:    payload
			}, TabResult{
				...last
				error: err.msg()
			}, Confirm{})
		}
		return '/'
	}
	// A table in the sidebar (its catalog, schema and name as JSON) opens a
	// new tab to alter it.
	if table := form.get('alter') {
		names := json2.decode[[]string](table)!
		if names.len != 3 {
			return error('bad table: ${table}')
		}
		insert_tab(mut conn, alter_table_tab, 'Alter ${names[2]}', a.alter_table_payload(mut conn,
			names[0], names[1], names[2])!)!
		return '/'
	}
	// A schema in the sidebar opens a new tab to create a table in it.
	if schema := form.get('add_table') {
		insert_tab(mut conn, create_table_tab, 'New table', new_table_payload(schema))!
		return '/'
	}
	if other_tab := form.get('goto') {
		activate_tab(mut conn, other_tab.int())!
		return '/'
	}
	if _ := form.get('new') {
		add_tab(mut conn, show_tables_sql)!
		return '/'
	}
	if close := form.get('close') {
		a.close_tab(mut conn, close.int(), tab.id)!
		return '/'
	}
	if tab.id == no_tab.id {
		return '/'
	}

	// An ALTER_TABLE tab is closed once its statements are run (in a
	// transaction), and the table is queried in a new tab. If it fails,
	// nothing is changed and the error is shown on the tab.
	if tab.tab_type == alter_table_tab {
		if _ := form.get('alter_table') {
			run_in_transaction(mut conn, form.get('alter_sql') or { '' }) or {
				return a.page(mut conn, all_tabs, Tab{
					...tab
					payload: payload
				}, TabResult{
					error: err.msg()
				}, Confirm{})
			}
			a.close_tab(mut conn, tab.id, tab.id)!
			a.query_table(mut conn, json2.decode[AlterTablePayload](payload)!.table)!
		}
		return '/'
	}
	// A CREATE_TABLE tab is closed once the table is created, and the table
	// (which is empty) is queried in a new tab. If it fails,
	// the error is shown on the tab. Anything else (such as saving the
	// payload) shows it again.
	if tab.tab_type == create_table_tab {
		if _ := form.get('create_table') {
			conn.query(form.get('create_sql') or { '' }) or {
				return a.page(mut conn, all_tabs, Tab{
					...tab
					payload: payload
				}, TabResult{
					error: err.msg()
				}, Confirm{})
			}
			a.close_tab(mut conn, tab.id, tab.id)!
			a.query_table(mut conn, form.get('created_table') or { '' })!
		}
		return '/'
	}

	// A change to a row of an editable result (see edit.v). An update or
	// delete is shown to be confirmed before it's run, an insert is run
	// straight away. If it fails, the values entered to insert are kept.
	if kind := form.get('change') {
		last := rlock a.results {
			a.results[tab.id] or { TabResult{} }
		}
		table := a.find_edit_table(mut conn, form.get('catalog') or { '' }, form.get('schema') or {
			''
		}, form.get('table') or { '' })!
		change_sql := build_change(table, form) or {
			return a.page(mut conn, all_tabs, tab, TabResult{
				...last
				error: err.msg()
			}, Confirm{})
		}
		if kind != 'insert' {
			return a.page(mut conn, all_tabs, tab, last, Confirm{change_sql, 'confirm', change_sql})
		}
		a.apply_change(mut conn, tab.id, change_sql, query_text) or {
			return a.page(mut conn, all_tabs, tab, TabResult{
				...last
				output: keep_insert_values(last.output, form)
				error:  err.msg()
			}, Confirm{})
		}
		return '/'
	}
	if change_sql := form.get('confirm') {
		a.apply_change(mut conn, tab.id, change_sql, query_text) or {
			last := rlock a.results {
				a.results[tab.id] or { TabResult{} }
			}
			return a.page(mut conn, all_tabs, tab, TabResult{
				...last
				error: err.msg()
			}, Confirm{})
		}
		return '/'
	}

	result := a.run_query(mut conn, query_text)!
	lock a.results {
		a.results[tab.id] = result
	}
	title_tab(mut conn, tab.id, query_text)!
	activate_tab(mut conn, tab.id)!
	return a.page(mut conn, tabs(mut conn)!, Tab{tab.id, tab.tab_type, tab_title(query_text), query_text, true, ''},
		result, Confirm{})
}

// run_in_transaction runs every statement, or none of them if one fails.
fn run_in_transaction(mut conn vsql.Connection, statements string) ! {
	conn.query('START TRANSACTION')!
	for stmt in vsql.split_statements(statements) {
		conn.query(stmt) or {
			conn.query('ROLLBACK') or {}
			return err
		}
	}
	conn.query('COMMIT')!
}

// query_table opens a new tab that runs SELECT * on a table.
fn (a &App) query_table(mut conn vsql.Connection, table string) ! {
	table_sql := 'SELECT * FROM ${table}'
	id := add_tab(mut conn, table_sql)!
	result := a.run_query(mut conn, table_sql)!
	lock a.results {
		a.results[id] = result
	}
}

// apply_change runs a change to a row (see run_change), then the SQL of the tab
// again to show it.
fn (a &App) apply_change(mut conn vsql.Connection, tab_id int, change_sql string, query_text string) ! {
	msg := run_change(mut conn, change_sql)!
	result := a.run_query(mut conn, query_text)!
	lock a.results {
		a.results[tab_id] = TabResult{
			...result
			status: '${msg}, ${result.status}'
		}
	}
}
