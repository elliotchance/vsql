module app

import json2
import strings
import vsql

// Confirm is a change that's shown (as sql) in a popup with the file it runs in,
// to be confirmed before it's run, such as dropping a table. Confirming posts
// name with value.
struct Confirm {
	sql     string
	name    string
	value   string
	catalog string
}

// page renders the sidebar, the tabs, the SQL editor for tab and its last
// result. If confirm has sql, it's shown to be confirmed.
fn (a &App) page(mut conn vsql.Connection, all_tabs []Tab, tab Tab, result TabResult, confirm Confirm) !string {
	mut sb := strings.new_builder(4096)
	sb.write_string('<!doctype html><html><head><meta charset="utf-8">')
	sb.write_string('<meta name="viewport" content="width=device-width, initial-scale=1">')
	sb.write_string('<title>vsql</title><style>${app_css.to_string()}</style></head><body>')
	a.write_sidebar(mut sb, mut conn, all_tabs, tab)!
	sb.write_string('<main>')
	a.write_tabs(mut sb, all_tabs, tab)

	if tab.id == no_tab.id {
		sb.write_string('</form><p class="empty">Choose a table, or use + to add a tab.</p>')
	} else if tab.tab_type == history_tab {
		// Choosing a query opens it in a new tab, it's not run.
		sb.write_string('</form>')
		entries := all_history(mut conn, tab.catalog)!
		if entries.len == 0 {
			sb.write_string('<p class="empty">No queries have been run.</p>')
		}
		if entries.len > 0 {
			write_history_search(mut sb)
		}
		write_history_list(mut sb, entries, true)
	} else if tab.tab_type == create_table_tab {
		write_create_table(mut sb, tab, result)
	} else if tab.tab_type == alter_table_tab {
		write_alter_table(mut sb, tab, result)
	} else if tab.tab_type == export_tab {
		a.write_export(mut sb, mut conn, tab, result)!
	} else if tab.tab_type == import_tab {
		a.write_import(mut sb, mut conn, tab)!
	} else {
		entries := history(mut conn, tab.catalog, tab.id)!

		// The editor is a transparent textarea over a highlighted copy of its
		// text (see app.js).
		sb.write_string('<div class="editor"><pre aria-hidden="true"></pre>')
		autofocus := if confirm.sql == '' { ' autofocus' } else { '' }
		sb.write_string('<textarea name="sql" rows="6" spellcheck="false"${autofocus} placeholder="SELECT * FROM ...">${html_escape(tab.query_text)}</textarea></div>')
		// The inputs for each "?" are added as the SQL changes (see app.js).
		sb.write_string('<div class="params" hidden data-values="${html_escape(json2.encode(tab.params.values))}" data-types="${html_escape(json2.encode(tab.params.types))}"></div>')
		// The file that the SQL runs in.
		// It's also where the SQL runs, so the names don't need a schema.
		schemas := a.query_schemas(mut conn, tab.catalog)!
		query_schema := query_tab_schema(schemas, tab.schema)
		sb.write_string('<div class="actions"><span class="catalog">${a.file_dot(tab.catalog)}${html_escape(tab.catalog)}</span><select name="query_schema" class="query-schema" title="The schema that the SQL runs in" aria-label="Schema">')
		for schema in schemas {
			selected := if schema == query_schema { ' selected' } else { '' }
			sb.write_string('<option value="${html_escape(schema)}"${selected}>${html_escape(schema)}</option>')
		}
		sb.write_string('</select><span class="status">${html_escape(result.status)}</span>')
		if result.has_rows {
			edit_attrs := if result.editable {
				''
			} else {
				' disabled title="Only the rows of SELECT * FROM a table with a PRIMARY KEY can be edited"'
			}
			sb.write_string('<span class="edit-hint" hidden>Empty = <code>DEFAULT</code>, <code>\\N</code> = <code>NULL</code>, <code>&quot;&quot;</code> = empty string</span>')
			sb.write_string('<button type="button" class="cancel-edit" hidden>Cancel edit</button><button type="button" class="edit"${edit_attrs}>Edit...</button>')
		}
		if entries.len > 0 {
			sb.write_string('<button type="button" class="show-history" title="Query History">Query History</button>')
		}
		sb.write_string('<button type="submit" name="export_query_tab" value="1" class="run export-query-tab" title="Export the result of this query">Export&hellip;</button>')
		sb.write_string('<button type="submit" name="explain" value="1" class="run explain" title="Run with EXPLAIN">Explain</button>')
		sb.write_string('<button type="submit" class="run" title="Run (Ctrl+Enter)">Run <span class="shortcut">&#8963;&#8629;</span></button></div></form>')
		// Choosing a query from the history puts it in the editor, it's not run
		// (see app_history.js).
		if entries.len > 0 {
			sb.write_string('<dialog class="history"><div class="history-header"><strong>Query History</strong><button type="button" class="close" title="Close">&times;</button></div>')
			write_history_search(mut sb)
			write_history_list(mut sb, entries, false)
			sb.write_string('</dialog>')
		}
	}
	if confirm.sql != '' {
		// It's a popup (see app_confirm.js), a DROP is run with a red button.
		run_class := if confirm.sql.starts_with('DROP ') { ' class="delete"' } else { '' }
		sb.write_string('<dialog class="confirm confirm-sql"><form method="post" action="/"><input type="hidden" name="tab" value="${html_escape(tab.ref())}">')
		sb.write_string('<input type="hidden" name="${html_escape(confirm.name)}" value="${html_escape(confirm.value)}"><p class="confirm-file">${html_escape(confirm.catalog)}</p><pre class="sql">${html_escape(confirm.sql)}</pre>')
		sb.write_string('<button type="submit"${run_class} autofocus>Run</button><a href="/" class="cancel">Cancel</a></form></dialog>')
	}
	// A CREATE_TABLE or ALTER_TABLE tab has its own error.
	if result.error != '' && tab.tab_type !in [create_table_tab, alter_table_tab, export_tab] {
		sb.write_string('<p class="error">${html_escape(result.error)}</p>')
	}
	if result.notice != '' {
		sb.write_string('<p class="notice">${html_escape(result.notice)}</p>')
	}
	if tab.tab_type == import_tab {
		sb.write_string(result.output)
	}
	if tab.id != no_tab.id && tab.tab_type == query_tab {
		sb.write_string(if result.output == '' && result.status == '' {
			'<p class="empty">Run to see the result.</p>'
		} else {
			result.output
		})
	}

	// Create schema (in the menu of a catalog) is a popup, see app_schema.js.
	sb.write_string('<dialog class="confirm create-schema"><form method="post" action="/"><input type="hidden" name="tab" value="${html_escape(tab.ref())}"><input type="hidden" name="create_schema" value=""><input type="hidden" name="create_schema_catalog" value="">')
	sb.write_string('<p class="confirm-file"></p><label class="schema-name">Schema name <input spellcheck="false" placeholder="NAME"></label><pre class="sql"></pre>')
	sb.write_string('<button type="submit" class="create">Create schema</button><button type="button" class="keep">Cancel</button></form></dialog>')

	// Create index (in the menu of a table) is a popup, see app_index.js.
	sb.write_string('<dialog class="confirm create-index"><form method="post" action="/"><input type="hidden" name="tab" value="${html_escape(tab.ref())}"><input type="hidden" name="create_index" value=""><input type="hidden" name="create_index_catalog" value="">')
	sb.write_string('<p class="confirm-file"></p><label class="index-name">Index name <input spellcheck="false" placeholder="NAME"></label><fieldset class="index-columns"><legend>Columns, in the order they&rsquo;re chosen</legend><ul></ul></fieldset><pre class="sql"></pre>')
	sb.write_string('<button type="submit" class="create">Create index</button><button type="button" class="keep">Cancel</button></form></dialog>')

	// The scripts are after the result, so they can find the editable table.
	// The full value of a cell in a result is a popup, see app_result.js.
	if tab.id != no_tab.id && tab.tab_type == query_tab {
		sb.write_string('<dialog class="confirm cell-value"><form method="dialog"><p class="confirm-file"></p><textarea rows="12" spellcheck="false"></textarea>')
		sb.write_string('<button type="button" class="create" hidden>Done</button><button type="button" class="copy">Copy</button><button type="button" class="keep">Close</button></form></dialog>')
	}

	sb.write_string('<script>${reserved_words_js()}${app_highlight_js.to_string()}${app_schema_js.to_string()}${app_index_js.to_string()}')
	if tab.id != no_tab.id && tab.tab_type == query_tab {
		sb.write_string(app_js.to_string() + app_result_js.to_string() + app_edit_js.to_string())
	}
	if tab.tab_type == export_tab {
		sb.write_string(app_export_js.to_string())
	}
	if tab.tab_type == import_tab {
		sb.write_string(if a.is_importing(tab.ref()) {
			app_import_progress_js.to_string()
		} else if json2.decode[ImportPayload](tab.payload)!.demo != '' {
			app_demo_js.to_string()
		} else {
			app_import_js.to_string()
		})
	}
	if tab.tab_type == create_table_tab {
		sb.write_string(app_columns_js.to_string() + app_create_table_js.to_string())
	}
	if tab.tab_type == alter_table_tab {
		sb.write_string(app_columns_js.to_string() + app_alter_table_js.to_string())
	}
	if confirm.sql != '' {
		sb.write_string(app_confirm_js.to_string())
	}
	sb.write_string('${app_history_js.to_string()}</script>')

	sb.write_string('</main></body></html>')
	return sb.str()
}

fn reserved_words_js() string {
	reserved_words := vsql.reserved_words().map('"${it}"').join(',')

	extension_keywords := vsql.extension_keywords().map('"${it}"').join(',')

	return 'const reservedWords = new Set([${reserved_words}]);const extensionKeywords = new Set([${extension_keywords}]);'
}

// write_history_search writes the search of the history list after it, which
// filters it as it's typed (see app_history.js).
fn write_history_search(mut sb strings.Builder) {
	sb.write_string('<input type="search" class="history-search" placeholder="Search..." aria-label="Search the history" autocomplete="off" autofocus>')
	sb.write_string('<p class="history-no-match" hidden>No queries match.</p>')
}

// write_history_list writes each query with its outcome. It's chosen in the
// popup of a tab (see app_history.js), or opened in a new tab if open is true.
fn write_history_list(mut sb strings.Builder, entries []History, open bool) {
	if entries.len == 0 {
		return
	}
	sb.write_string('<ol class="history-list">')
	for h in entries {
		outcome := if h.error != '' {
			'<span class="failed">${html_escape(h.error)}</span>'
		} else if h.row_count >= 0 {
			'${h.row_count} ${vsql.pluralize(h.row_count, 'row')}'
		} else {
			html_escape(h.message)
		}
		attrs := if open {
			'type="submit" form="app" name="open" value="${html_escape(h.query_text)}" title="Open in a new tab"'
		} else {
			'type="button"'
		}
		sb.write_string('<li><button ${attrs}><pre class="sql">${html_escape(h.query_text)}</pre><span class="meta">${html_escape(h.ran_at)} &middot; ${outcome}</span></button></li>')
	}
	sb.write_string('</ol>')
}

// write_sidebar is the version, a heading for each catalog with its schemas and their tables, both sorted by name, each
// with its tabs (tab is the active one). Choosing a tab goes to it, and choosing a
// table queries it in a new tab. Each tab has a menu to close it. The sidebar can
// be resized, and a heading or schema collapsed (see app_sidebar.js).
//
// Each catalog has a menu to create a schema (see app_schema.js), import (see
// import.v) or export (see export.v) the file, or open its Query History. Each schema and
// table (other than in INFORMATION_SCHEMA, which can't be changed, and VSQL_APP,
// which the app needs) has a menu to import, export or drop it, and a schema to add a table to it
// (see create_table.v) or an index to it (see app_index.js). They run in the
// file of the catalog, so it's not in the SQL. The indexes of a table are under
// it (see write_indexes).
fn (a &App) write_sidebar(mut sb strings.Builder, mut conn vsql.Connection, all_tabs []Tab, tab Tab) ! {
	// A local build has no version.
	version := if vsql.version() == '' { 'v0.0.0' } else { vsql.version() }
	sb.write_string('<nav class="sidebar"><div class="brand"><a href="${repo_url}" target="_blank" rel="noopener">vsql</a> <span class="version">${html_escape(version)}</span></div>')
	for catalog_name in a.catalog_names {
		set_catalog(mut conn, catalog_name)!
		mut catalog := conn.catalog()
		mut schemas := map[string][]vsql.Identifier{}
		// The indexes of each table, by its schema and name.
		mut indexes := map[string][]vsql.Index{}
		// The names of the columns of each table (by its schema and name), and
		// how they're used in SQL, for Create index (see app_index.js).
		mut columns := map[string][][]string{}
		for schema in catalog.schemas()! {
			schemas[schema.name] = []
			for index in catalog.indexes(schema.name)! {
				indexes['${schema.name}.${index.table_name.entity_name}'] << index
			}
			for table in catalog.schema_tables(schema.name)! {
				columns['${schema.name}.${table.name.entity_name}'] = table.column_names().map([
					it,
					vsql.Identifier{
						sub_entity_name: it
					}.str(),
				])
				// The tab of the table runs in this catalog, so it's left out of
				// the query.
				schemas[schema.name] << vsql.Identifier{
					...table.name
					catalog_name: ''
				}
			}
		}
		mut schema_names := schemas.keys()
		schema_names.sort()

		sb.write_string('<div class="folder-row catalog-row"><details class="menu"><summary title="More" aria-label="More">&#9776;</summary><div class="menu-items">')
		sb.write_string('<button type="button" class="create-schema" data-catalog="${html_escape(catalog_name)}">Create schema</button>')
		sb.write_string('<button type="submit" form="app" name="import:${html_escape(catalog_name)}" value="[]">Import&hellip;</button>')
		sb.write_string('<button type="submit" form="app" name="demo:${html_escape(catalog_name)}" value="1">Load demo data&hellip;</button>')
		sb.write_string('<button type="submit" form="app" name="export:${html_escape(catalog_name)}" value="${html_escape(json2.encode([
			'file',
		]))}">Export&hellip;</button>')
		sb.write_string('<button type="submit" form="app" name="history" value="${html_escape(catalog_name)}" class="history-nav" aria-label="Query History of ${html_escape(catalog_name)}">Query History</button></div></details>')
		sb.write_string('<details class="section" data-folder="catalog:${html_escape(catalog_name)}" open><summary><span class="icon" aria-hidden="true">&#128452;&#65039;</span>${a.file_dot(catalog_name)}${html_escape(catalog_name)}</summary>')
		catalog_tabs := all_tabs.filter(it.catalog == catalog_name)
		sb.write_string('<details class="folder" data-folder="tabs:${html_escape(catalog_name)}" open><summary><span class="icon" aria-hidden="true">&#128450;&#65039;</span>Tabs <span class="count">${catalog_tabs.len}</span>')
		sb.write_string('<button type="submit" form="app" name="new" value="${html_escape(catalog_name)}" class="new-tab" title="New tab" aria-label="New tab in ${html_escape(catalog_name)}">+</button></summary><ul>')
		for t in catalog_tabs {
			active := if t.ref() == tab.ref() { ' class="active"' } else { '' }
			sb.write_string('<li${active}><button type="submit" form="app" name="goto" value="${html_escape(t.ref())}">${a.file_dot(catalog_name)}${html_escape(t.title)}${a.import_mark(t)}</button>')
			// The menu of a tab (see app_sidebar.js).
			sb.write_string('<details class="menu"><summary title="More" aria-label="More">&#9776;</summary><div class="menu-items">')
			sb.write_string('<button type="submit" form="app" name="close" value="${html_escape(t.ref())}">Close</button></div></details></li>')
		}
		sb.write_string('</ul></details>')
		for schema_name in schema_names {
			mut tables := schemas[schema_name].clone()
			tables.sort(a.entity_name < b.entity_name)
			// The menu of a schema (see app_sidebar.js) is next to it, so it's shown
			// when the schema is collapsed.
			schema_sql := vsql.Identifier{
				schema_name: schema_name
			}.str()
			sb.write_string('<div class="folder-row schema-row">')
			is_system := schema_name in ['INFORMATION_SCHEMA', 'VSQL_APP']
			if !is_system {
				// A schema with tables is dropped with them.
				drop_behavior := if tables.len == 0 { 'RESTRICT' } else { 'CASCADE' }
				sb.write_string('<details class="menu"><summary title="More" aria-label="More">&#9776;</summary><div class="menu-items">')
				sb.write_string('<button type="submit" form="app" name="add_table:${html_escape(catalog_name)}" value="${html_escape(schema_sql)}">Add table</button>')
				sb.write_string('<button type="submit" form="app" name="import:${html_escape(catalog_name)}" value="${html_escape(json2.encode([
					schema_name,
				]))}">Import&hellip;</button>')
				sb.write_string('<button type="submit" form="app" name="export:${html_escape(catalog_name)}" value="${html_escape(json2.encode([
					'schema',
					schema_name,
				]))}">Export&hellip;</button>')
				sb.write_string('<button type="submit" form="app" name="drop:${html_escape(catalog_name)}" value="SCHEMA ${html_escape(schema_sql)} ${drop_behavior}" class="danger">Drop schema</button></div></details>')
			}
			// They are seldom looked at, so they start collapsed (see app_sidebar.js).
			folder_state := if is_system { ' data-default-closed' } else { ' open' }
			sb.write_string('<details class="folder" data-folder="schema:${html_escape(catalog_name)}.${html_escape(schema_name)}"${folder_state}><summary><span class="icon" aria-hidden="true">&#128193;</span>${html_escape(schema_name)} <span class="count">${tables.len}</span></summary><ul>')
			if tables.len == 0 {
				sb.write_string('<li class="empty">There are no tables.</li>')
			}
			for table in tables {
				sb.write_string('<li><button type="submit" form="app" name="query:${html_escape(catalog_name)}" value="${html_escape(table.str())}" title="SELECT * FROM ${html_escape(table.str())}"><span class="icon" aria-hidden="true">&#128196;</span>${html_escape(table.entity_name)}</button>')
				// The menu of a table (see app_sidebar.js).
				if !is_system {
					sb.write_string('<details class="menu"><summary title="More" aria-label="More">&#8943;</summary><div class="menu-items">')
					sb.write_string('<button type="submit" form="app" name="alter:${html_escape(catalog_name)}" value="${html_escape(json2.encode([
						schema_name,
						table.entity_name,
					]))}">Alter table</button>')
					sb.write_string('<button type="button" class="create-index" data-catalog="${html_escape(catalog_name)}" data-table="${html_escape(table.str())}" data-table-name="${html_escape(table.entity_name)}" data-columns="${html_escape(json2.encode(columns['${schema_name}.${table.entity_name}']))}">Create index</button>')
					sb.write_string('<button type="submit" form="app" name="import:${html_escape(catalog_name)}" value="${html_escape(json2.encode([
						schema_name,
						table.entity_name,
					]))}">Import&hellip;</button>')
					sb.write_string('<button type="submit" form="app" name="export:${html_escape(catalog_name)}" value="${html_escape(json2.encode([
						'table',
						schema_name,
						table.entity_name,
					]))}">Export&hellip;</button>')
					sb.write_string('<button type="submit" form="app" name="drop:${html_escape(catalog_name)}" value="TABLE ${html_escape(table.str())}" class="danger">Drop table</button></div></details>')
				}
				a.write_indexes(mut sb, catalog_name, indexes['${schema_name}.${table.entity_name}'],
					is_system)
				sb.write_string('</li>')
			}
			sb.write_string('</ul></details></div>')
		}
		sb.write_string('</details></div>')
	}
	set_catalog(mut conn, a.catalog_names[0])!

	// The width and collapsed headings and schemas are set before the page is
	// shown.
	sb.write_string('</nav><div class="resizer" title="Drag to resize"></div><script>${app_sidebar_js.to_string()}</script>')
}

// write_indexes lists the indexes of a table under it, with their columns. Each
// one has a menu to drop it (see app_sidebar.js), unless it's in a system schema.
fn (a &App) write_indexes(mut sb strings.Builder, catalog_name string, indexes []vsql.Index, is_system bool) {
	if indexes.len == 0 {
		return
	}

	sb.write_string('<ul class="indexes">')
	for index in indexes {
		// The index is dropped in the file of the catalog, so it's left out.
		name := vsql.Identifier{
			schema_name: index.name.schema_name
			entity_name: index.name.entity_name
		}.str()
		columns := index.columns.map(if it.desc { '${it.name} DESC' } else { it.name }).join(', ')
		sb.write_string('<li class="index"><span class="index-name" title="${html_escape(index.str())}"><span class="icon" aria-hidden="true">&#128199;</span><span class="name">${html_escape(index.name.entity_name)}</span> <span class="columns">(${html_escape(columns)})</span></span>')
		if !is_system {
			sb.write_string('<details class="menu"><summary title="More" aria-label="More">&#8943;</summary><div class="menu-items">')
			sb.write_string('<button type="submit" form="app" name="drop:${html_escape(catalog_name)}" value="INDEX ${html_escape(name)}" class="danger">Drop index</button></div></details>')
		}
		sb.write_string('</li>')
	}
	sb.write_string('</ul>')
}

// write_tabs starts the form, with the tabs of all of the files (tab is the active
// one). The form must be closed by the caller.
fn (a &App) write_tabs(mut sb strings.Builder, all_tabs []Tab, tab Tab) {
	sb.write_string('<form method="post" action="/" id="app"><input type="hidden" name="tab" value="${html_escape(tab.ref())}"><div class="tabs">')
	for t in all_tabs {
		active := if t.ref() == tab.ref() { ' active' } else { '' }
		// With more than one file, it says which file the tab is in.
		file := if a.catalog_names.len > 1 { ' title="${html_escape(t.catalog)}"' } else { '' }
		sb.write_string('<span class="tab${active}"><button type="submit" name="goto" value="${html_escape(t.ref())}"${file}>${a.file_dot(t.catalog)}${html_escape(t.title)}${a.import_mark(t)}</button>')
		sb.write_string('<button type="submit" name="close" value="${html_escape(t.ref())}" class="close" title="Close">&times;</button></span>')
	}
	sb.write_string('<button type="submit" name="new" value="" class="new" title="New tab">+</button></div>')
}

// file_dots is the number of colors for file_dot, see .dot-0 onwards in app.css.
const file_dots = 8

// file_dot is the colored dot of a file, which is next to its name in the
// sidebar and in front of each of its tabs. Each file has its own color, until
// there are more files than colors.
fn (a &App) file_dot(catalog string) string {
	return '<span class="dot dot-${a.catalog_names.index(catalog) % file_dots}" aria-hidden="true"></span>'
}

// repo_url is where vsql in the sidebar goes.
const repo_url = 'https://github.com/elliotchance/vsql'

const app_css = $embed_file('app.css')
const app_js = $embed_file('app.js')
const app_result_js = $embed_file('app_result.js')
const app_edit_js = $embed_file('app_edit.js')
const app_sidebar_js = $embed_file('app_sidebar.js')
const app_confirm_js = $embed_file('app_confirm.js')
const app_schema_js = $embed_file('app_schema.js')
const app_index_js = $embed_file('app_index.js')
const app_import_js = $embed_file('app_import.js')
const app_import_progress_js = $embed_file('app_import_progress.js')
const app_demo_js = $embed_file('app_demo.js')

// import_formats are the files that can be imported.
const import_formats = '.sql,.csv,.tsv,.json'
const app_columns_js = $embed_file('app_columns.js')
const app_create_table_js = $embed_file('app_create_table.js')
const app_highlight_js = $embed_file('app_highlight.js')
const app_history_js = $embed_file('app_history.js')
const app_alter_table_js = $embed_file('app_alter_table.js')
const app_export_js = $embed_file('app_export.js')

const show_tables_sql = 'SELECT * FROM INFORMATION_SCHEMA.TABLES'

// tab_title is the start of the SQL in a tab, on one line.
fn tab_title(query_text string) string {
	line := query_text.replace_each(['\r\n', ' ', '\n', ' ', '\r', ' ']).fields().join(' ')
	if line == '' {
		return 'New tab'
	}

	return if line.runes().len > 30 { line.runes()[..30].string() + '...' } else { line }
}

// set_catalog makes a catalog current, such as to read its tables.
fn set_catalog(mut conn vsql.Connection, name string) ! {
	conn.query("SET CATALOG '${name.replace("'", "''")}'")!
}

fn html_escape(s string) string {
	return s.replace_each(['&', '&amp;', '<', '&lt;', '>', '&gt;', '"', '&quot;', "'", '&#39;'])
}

// import_mark is next to the title of a tab that's importing a file.
fn (a &App) import_mark(t Tab) string {
	return if a.is_importing(t.ref()) { ' &hellip;' } else { '' }
}
