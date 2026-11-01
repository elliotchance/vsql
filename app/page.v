module app

import strings
import vsql

// page renders the sidebar, the tabs, the SQL editor for tab and its last
// result.
fn (a &App) page(mut conn vsql.Connection, all_tabs []Tab, tab Tab, result TabResult) !string {
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
		sb.write_string('<script>${reserved_words_js()}${app_highlight_js.to_string()}${app_history_js.to_string()}</script>')
	} else {
		output := if result.output == '' && result.status == '' {
			'<p class="empty">Run to see the result.</p>'
		} else {
			result.output
		}

		entries := history(mut conn, tab.catalog, tab.id)!

		// The editor is a transparent textarea over a highlighted copy of its
		// text (see app.js).
		sb.write_string('<div class="editor"><pre aria-hidden="true"></pre>')
		sb.write_string('<textarea name="sql" rows="6" spellcheck="false" autofocus placeholder="SELECT * FROM ...">${html_escape(tab.query_text)}</textarea></div>')
		// The file that the SQL runs in.
		sb.write_string('<div class="actions"><span class="catalog">${a.file_dot(tab.catalog)}${html_escape(tab.catalog)}</span><span class="status">${html_escape(result.status)}</span>')
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
		sb.write_string('<button type="submit" class="run" title="Run (Ctrl+Enter)">Run <span class="shortcut">&#8963;&#8629;</span></button></div></form>')
		// Choosing a query from the history puts it in the editor, it's not run
		// (see app_history.js).
		if entries.len > 0 {
			sb.write_string('<dialog class="history"><div class="history-header"><strong>Query History</strong><button type="button" class="close" title="Close">&times;</button></div>')
			write_history_search(mut sb)
			write_history_list(mut sb, entries, false)
			sb.write_string('</dialog>')
		}
		if result.error != '' {
			sb.write_string('<p class="error">${html_escape(result.error)}</p>')
		}
		sb.write_string(output)
		// The scripts are after the result, so they can find the editable
		// table.
		sb.write_string('<script>${reserved_words_js()}${app_highlight_js.to_string()}${app_js.to_string()}${app_edit_js.to_string()}${app_history_js.to_string()}</script>')
	}

	sb.write_string('</main></body></html>')
	return sb.str()
}

fn reserved_words_js() string {
	reserved_words := vsql.reserved_words().map('"${it}"').join(',')

	return 'const reservedWords = new Set([${reserved_words}]);'
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

// write_sidebar is the version, a heading for each catalog (with a button for
// its Query History) with its tables under their schema (a schema without tables
// isn't shown), both sorted by name, each with its tabs (tab is the active one).
// Choosing a tab goes to it, and choosing a table queries it in a new tab. Each
// tab has a menu to close it. The sidebar can be resized, and a heading or schema
// collapsed (see app_sidebar.js).
fn (a &App) write_sidebar(mut sb strings.Builder, mut conn vsql.Connection, all_tabs []Tab, tab Tab) ! {
	// A local build has no version.
	version := if vsql.version() == '' { 'v0.0.0' } else { vsql.version() }
	sb.write_string('<nav class="sidebar"><div class="brand">vsql <span class="version">${html_escape(version)}</span></div>')
	for catalog_name in a.catalog_names {
		set_catalog(mut conn, catalog_name)!
		mut catalog := conn.catalog()
		mut schemas := map[string][]vsql.Identifier{}
		for schema in catalog.schemas()! {
			for table in catalog.schema_tables(schema.name)! {
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

		sb.write_string('<details class="section" data-folder="catalog:${html_escape(catalog_name)}" open><summary><span class="icon" aria-hidden="true">&#128452;&#65039;</span>${a.file_dot(catalog_name)}${html_escape(catalog_name)}')
		history_active := if tab.tab_type == history_tab && tab.catalog == catalog_name {
			' active'
		} else {
			''
		}
		// The icon is from app.css, so it isn't part of the text of the heading.
		sb.write_string('<button type="submit" form="app" name="history" value="${html_escape(catalog_name)}" class="history-nav${history_active}" title="Query History" aria-label="Query History of ${html_escape(catalog_name)}"></button></summary>')
		catalog_tabs := all_tabs.filter(it.catalog == catalog_name)
		sb.write_string('<details class="folder" data-folder="tabs:${html_escape(catalog_name)}" open><summary><span class="icon" aria-hidden="true">&#128450;&#65039;</span>Tabs <span class="count">${catalog_tabs.len}</span>')
		sb.write_string('<button type="submit" form="app" name="new" value="${html_escape(catalog_name)}" class="new-tab" title="New tab" aria-label="New tab in ${html_escape(catalog_name)}">+</button></summary><ul>')
		for t in catalog_tabs {
			active := if t.ref() == tab.ref() { ' class="active"' } else { '' }
			icon := if t.tab_type == history_tab { '&#128337;' } else { '&#128221;' }
			sb.write_string('<li${active}><button type="submit" form="app" name="goto" value="${html_escape(t.ref())}"><span class="icon" aria-hidden="true">${icon}</span>${html_escape(t.title)}</button>')
			// The menu of a tab (see app_sidebar.js).
			sb.write_string('<details class="menu"><summary title="More" aria-label="More">&#9776;</summary><div class="menu-items">')
			sb.write_string('<button type="submit" form="app" name="close" value="${html_escape(t.ref())}">Close</button></div></details></li>')
		}
		sb.write_string('</ul></details>')
		if schema_names.len == 0 {
			sb.write_string('<p class="empty">There are no tables.</p>')
		}
		for schema_name in schema_names {
			mut tables := schemas[schema_name].clone()
			tables.sort(a.entity_name < b.entity_name)
			sb.write_string('<details class="folder" data-folder="schema:${html_escape(catalog_name)}.${html_escape(schema_name)}" open><summary><span class="icon" aria-hidden="true">&#128193;</span>${html_escape(schema_name)} <span class="count">${tables.len}</span></summary><ul>')
			for table in tables {
				sb.write_string('<li><button type="submit" form="app" name="query:${html_escape(catalog_name)}" value="${html_escape(table.str())}" title="SELECT * FROM ${html_escape(table.str())}"><span class="icon" aria-hidden="true">&#128196;</span>${html_escape(table.entity_name)}</button></li>')
			}
			sb.write_string('</ul></details>')
		}
		sb.write_string('</details>')
	}
	set_catalog(mut conn, a.catalog_names[0])!

	// The width and collapsed headings and schemas are set before the page is
	// shown.
	sb.write_string('</nav><div class="resizer" title="Drag to resize"></div><script>${app_sidebar_js.to_string()}</script>')
}

// write_tabs starts the form, with the tabs of all of the files (tab is the active
// one). The form must be closed by the caller.
fn (a &App) write_tabs(mut sb strings.Builder, all_tabs []Tab, tab Tab) {
	sb.write_string('<form method="post" action="/" id="app"><input type="hidden" name="tab" value="${html_escape(tab.ref())}"><div class="tabs">')
	for t in all_tabs {
		active := if t.ref() == tab.ref() { ' active' } else { '' }
		// With more than one file, it says which file the tab is in.
		file := if a.catalog_names.len > 1 { ' title="${html_escape(t.catalog)}"' } else { '' }
		sb.write_string('<span class="tab${active}"><button type="submit" name="goto" value="${html_escape(t.ref())}"${file}>${a.file_dot(t.catalog)}${html_escape(t.title)}</button>')
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

const app_css = $embed_file('app.css')
const app_js = $embed_file('app.js')
const app_edit_js = $embed_file('app_edit.js')
const app_sidebar_js = $embed_file('app_sidebar.js')
const app_highlight_js = $embed_file('app_highlight.js')
const app_history_js = $embed_file('app_history.js')

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
