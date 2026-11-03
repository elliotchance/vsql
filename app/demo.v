// The demo data of "vsql app". Load demo data in the menu of a file opens a tab to
// choose what to load. The browser downloads the latest file (see app_demo.js), so
// that it doesn't make the binary bigger, and it's imported like any other file with
// the progress of an IMPORT tab (see import_tab.v).
module app

import json2
import net.urllib
import strings
import vsql

// DemoData is something that can be loaded. Each one goes in its own new schema,
// so that it can't touch the tables of a file.
struct DemoData {
	key            string
	name           string
	description    string
	default_schema string
	file           string
	// format is the -format of "vsql in", and size is how much is downloaded.
	format string
	size   string
	// url is where the file is downloaded from, and project is the page that it's
	// from.
	url     string
	project string
	// table is the table that the file goes into, if it isn't a SQL file.
	table string
	// args are the options of "vsql in" for the file.
	args []string
}

// demo_data is everything that can be chosen on the tab.
const demo_data = [
	DemoData{
		key:            'chinook'
		name:           'Chinook'
		description:    'A digital media store with 11 tables and about 15,000 rows of artists, albums, tracks, playlists, customers, employees and invoices. It takes about a minute to load and uses about 15 MB. vsql has no indexes, so the indexes in the file are skipped and joins on it can take a minute too. The file drops its tables first, so a table in the schema with the same name is replaced. Loading it again into the same schema stops without changing anything, because those tables depend on each other.'
		default_schema: 'chinook'
		file:           'chinook.sql'
		format:         'sql'
		size:           '600 KB'
		url:            'https://raw.githubusercontent.com/lerocha/chinook-database/master/ChinookDatabase/DataSources/Chinook_Sqlite.sql'
		project:        'https://github.com/lerocha/chinook-database'
		args:           ['-compat', 'sqlite3', '-ignore-unsupported', '-single-transaction']
	},
	DemoData{
		key:            'countries'
		name:           'Countries'
		description:    'A single COUNTRIES table with the 249 countries and territories of ISO 3166, and their codes and regions. It loads in under a second. It stops without changing anything if the schema already has a COUNTRIES table. The data is licensed under CC BY-SA 4.0.'
		default_schema: 'countries'
		file:           'countries.csv'
		format:         'csv'
		size:           '21 KB'
		url:            'https://raw.githubusercontent.com/lukes/ISO-3166-Countries-with-Regional-Codes/master/all/all.csv'
		project:        'https://github.com/lukes/ISO-3166-Countries-with-Regional-Codes'
		table:          'COUNTRIES'
		args:           ['-table', 'COUNTRIES', '-create-table',
			'NAME VARCHAR(100), CODE VARCHAR(2), CODE3 VARCHAR(3), REGION VARCHAR(20), SUB_REGION VARCHAR(50)',
			'-map', 'name=NAME', '-map', 'alpha-2=CODE', '-map', 'alpha-3=CODE3', '-map',
			'region=REGION', '-map', 'sub-region=SUB_REGION']
	},
]

fn find_demo(key string) !DemoData {
	return demo_data.filter(it.key == key)[0] or { return error('no such demo data: ${key}') }
}

// open_demo opens a new tab to choose the demo data to load into a file.
fn (a &App) open_demo(mut conn vsql.Connection, catalog string) ! {
	first := demo_data[0]
	a.add_tab(mut conn, catalog, import_tab, 'Demo data', json2.encode(ImportPayload{
		schema: first.default_schema
		demo:   first.key
	}))!
}

// demo_form is the options of a tab with what's posted.
fn demo_form(form urllib.Values) ImportPayload {
	return ImportPayload{
		schema: form.get('demo_schema') or { '' }
		demo:   form.get('demo') or { '' }
	}
}

// is_demo_schema is true if the name doesn't need quotes. A quoted name isn't allowed
// since the file can be in the dialect of another database, where the name would
// be read differently (see -compat in "vsql in").
fn is_demo_schema(name string) bool {
	return name != '' && !name[0].is_digit()
		&& name.bytes().all(it.is_letter() || it.is_digit() || it == `_`)
}

// create_demo_schema creates the schema if it doesn't exist, since loading into one
// that does is fine. Only a schema of the app or the database itself is refused.
// This has the same effect as CREATE SCHEMA IF NOT EXISTS, which isn't on main yet.
fn create_demo_schema(mut conn vsql.Connection, catalog string, schema string) ! {
	set_catalog(mut conn, catalog)!
	mut cat := conn.catalog()
	existing := cat.schemas()!.filter(it.name == schema)
	if existing.len == 0 {
		conn.query('CREATE SCHEMA ${schema}')!
	} else if existing[0].is_virtual || schema == 'VSQL_APP' {
		return error('demo data cannot be loaded into ${schema}')
	}
}

// start_demo is Load on a tab, with the file that the browser downloaded. A schema
// that's created stays there, even if the import of the file is then rolled back.
fn (a &App) start_demo(form urllib.Values, file_text string) ! {
	mut conn := a.open()!
	defer {
		conn.close()
	}
	tab := a.import_tab_of(mut conn, form)!
	options := demo_form(form)
	demo := find_demo(options.demo)!
	schema := options.schema.trim_space().to_upper()
	if !is_demo_schema(schema) {
		return error('the schema must be a name with only letters, digits and underscores')
	}
	// A name that can't be used is shown on the tab, which can then be changed.
	create_demo_schema(mut conn, tab.catalog, schema) or {
		save_payload(mut conn, tab, json2.encode(options))!
		lock a.results {
			a.results[tab.ref()] = import_failed(a, tab, demo.file, err)
		}
		return
	}
	mut args := ['-schema', schema]
	args << demo.args
	args << a.db_path(tab.catalog)
	view := if demo.table == '' { '' } else { '${schema}.${demo.table}' }
	a.run_in_background(mut conn, tab, ImportCommand{demo.file, demo.format, args, view},
		ImportPayload{
			...options
			running_file: demo.file
		}, file_text)!
}

// write_demo is an IMPORT tab that's choosing demo data, after the tabs. The
// description goes with what's chosen, see app_demo.js. The form is closed.
fn write_demo(mut sb strings.Builder, payload ImportPayload) {
	sb.write_string('<div class="import demo-data">')
	if payload.running_file != '' {
		sb.write_string('<p class="error">The import of ${html_escape(payload.running_file)} was interrupted because the app was stopped.</p>')
	}
	sb.write_string('<label><span class="field">Demo data</span><select name="demo">')
	for demo in demo_data {
		selected := if demo.key == payload.demo { ' selected' } else { '' }
		sb.write_string('<option value="${html_escape(demo.key)}" data-schema="${html_escape(demo.default_schema)}" data-url="${html_escape(demo.url)}"${selected}>${html_escape(demo.name)}</option>')
	}
	sb.write_string('</select></label>')
	for demo in demo_data {
		hidden := if demo.key == payload.demo { '' } else { ' hidden' }
		sb.write_string('<p class="demo-description" data-demo="${html_escape(demo.key)}"${hidden}>${html_escape(demo.description)} The latest version is downloaded from <a href="${html_escape(demo.project)}" target="_blank" rel="noopener">${html_escape(demo.project.trim_string_left('https://'))}</a> (about ${html_escape(demo.size)}).</p>')
	}
	sb.write_string('<label><span class="field">Schema</span><input name="demo_schema" spellcheck="false" value="${html_escape(payload.schema)}"></label>')
	sb.write_string('<p class="import-hint">This schema is created if it doesn&rsquo;t exist. It can have letters, digits and underscores.</p>')
	sb.write_string('<p class="import-message demo-message" hidden></p><input type="hidden" name="demo_text" disabled>')
	sb.write_string('<div class="create-actions"><button type="submit" name="demo_load" value="1" class="create demo-load">Load</button></div></div></form>')
}
