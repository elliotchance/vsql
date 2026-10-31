module app

import strings
import vsql

// Confirm is a change that's shown (as sql) in a popup to be confirmed before
// it's run, such as a change to a row (see edit.v) or dropping a table.
// Confirming posts name with value.
struct Confirm {
	sql   string
	name  string
	value string
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
	write_tabs(mut sb, all_tabs, tab)

	if tab.id == no_tab.id {
		sb.write_string('</form><p class="empty">Choose a table, or use + to add a tab.</p>')
	} else {
		// The editor is a transparent textarea over a highlighted copy of its
		// text (see app.js).
		sb.write_string('<div class="editor"><pre aria-hidden="true"></pre>')
		autofocus := if confirm.sql == '' { ' autofocus' } else { '' }
		sb.write_string('<textarea name="sql" rows="6" spellcheck="false"${autofocus} placeholder="SELECT * FROM ...">${html_escape(tab.query_text)}</textarea></div>')
		sb.write_string('<div class="actions"><span class="status">${html_escape(result.status)}</span>')
		sb.write_string('<button type="submit" class="run" title="Run (Ctrl+Enter)">Run <span class="shortcut">&#8963;&#8629;</span></button></div></form>')
	}
	if confirm.sql != '' {
		// It's a popup (see app_confirm.js), a DELETE or DROP is run with a
		// red button.
		run_class := if confirm.sql.starts_with('DELETE ') || confirm.sql.starts_with('DROP ') {
			' class="delete"'
		} else {
			''
		}
		sb.write_string('<dialog class="confirm"><form method="post" action="/"><input type="hidden" name="tab" value="${tab.id}">')
		sb.write_string('<input type="hidden" name="${confirm.name}" value="${html_escape(confirm.value)}"><pre class="sql">${html_escape(confirm.sql)}</pre>')
		sb.write_string('<button type="submit"${run_class} autofocus>Run</button><a href="/" class="cancel">Cancel</a></form></dialog>')
	}
	if result.error != '' {
		sb.write_string('<p class="error">${html_escape(result.error)}</p>')
	}
	if tab.id != no_tab.id {
		sb.write_string(if result.output == '' && result.status == '' {
			'<p class="empty">Run to see the result.</p>'
		} else {
			result.output
		})
	}

	// The scripts are after the result, so they can find the editable table.
	reserved_words := vsql.reserved_words().map('"${it}"').join(',')
	sb.write_string('<script>const reservedWords = new Set([${reserved_words}]);${app_highlight_js.to_string()}')
	if tab.id != no_tab.id {
		sb.write_string(app_js.to_string() + app_edit_js.to_string())
	}
	if confirm.sql != '' {
		sb.write_string(app_confirm_js.to_string())
	}
	sb.write_string('</script>')

	sb.write_string('</main></body></html>')
	return sb.str()
}

// write_sidebar is the version, a heading for each catalog with its tables
// under their schema (a schema without tables isn't shown), both sorted by
// name, then a heading for the tabs (tab is the active one). Choosing a tab goes to it,
// and choosing a table queries it in a new tab. Each table (other than
// INFORMATION_SCHEMA and VSQL_APP) has a menu to drop it. The sidebar can be resized, and
// a heading or schema collapsed (see app_sidebar.js).
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
				// With one file, the catalog is left out of the query.
				schemas[schema.name] << vsql.Identifier{
					...table.name
					catalog_name: if a.catalog_names.len == 1 { '' } else { catalog_name }
				}
			}
		}
		mut schema_names := schemas.keys()
		schema_names.sort()

		sb.write_string('<details class="section" data-folder="catalog:${html_escape(catalog_name)}" open><summary><span class="icon" aria-hidden="true">&#128452;&#65039;</span>${html_escape(catalog_name)}</summary>')
		if schema_names.len == 0 {
			sb.write_string('<p class="empty">There are no tables.</p>')
		}
		for schema_name in schema_names {
			mut tables := schemas[schema_name].clone()
			tables.sort(a.entity_name < b.entity_name)
			sb.write_string('<details class="folder" data-folder="schema:${html_escape(catalog_name)}.${html_escape(schema_name)}" open><summary><span class="icon" aria-hidden="true">&#128193;</span>${html_escape(schema_name)} <span class="count">${tables.len}</span></summary><ul>')
			for table in tables {
				sb.write_string('<li><button type="submit" form="app" name="query" value="${html_escape(table.str())}" title="SELECT * FROM ${html_escape(table.str())}"><span class="icon" aria-hidden="true">&#128196;</span>${html_escape(table.entity_name)}</button>')
				// The menu of a table (see app_sidebar.js). INFORMATION_SCHEMA
				// can't be dropped, and the app needs VSQL_APP.
				if schema_name !in ['INFORMATION_SCHEMA', 'VSQL_APP'] {
					sb.write_string('<details class="menu"><summary title="More" aria-label="More">&#8943;</summary><div class="menu-items">')
					sb.write_string('<button type="submit" form="app" name="drop" value="${html_escape(table.str())}" class="danger">Drop table</button></div></details>')
				}
				sb.write_string('</li>')
			}
			sb.write_string('</ul></details>')
		}
		sb.write_string('</details>')
	}
	set_catalog(mut conn, a.catalog_names[0])!

	sb.write_string('<details class="section" data-folder="tabs" open><summary><span class="icon" aria-hidden="true">&#128450;&#65039;</span>Tabs <span class="count">${all_tabs.len}</span></summary><ul>')
	for t in all_tabs {
		active := if t.id == tab.id { ' class="active"' } else { '' }
		sb.write_string('<li${active}><button type="submit" form="app" name="goto" value="${t.id}"><span class="icon" aria-hidden="true">&#128221;</span>${html_escape(t.title)}</button></li>')
	}
	sb.write_string('</ul></details>')

	// The width and collapsed headings and schemas are set before the page is
	// shown.
	sb.write_string('</nav><div class="resizer" title="Drag to resize"></div><script>${app_sidebar_js.to_string()}</script>')
}

// write_tabs starts the form, with the tabs (tab is the active one). The form
// must be closed by the caller.
fn write_tabs(mut sb strings.Builder, all_tabs []Tab, tab Tab) {
	sb.write_string('<form method="post" action="/" id="app"><input type="hidden" name="tab" value="${tab.id}"><div class="tabs">')
	for t in all_tabs {
		active := if t.id == tab.id { ' active' } else { '' }
		sb.write_string('<span class="tab${active}"><button type="submit" name="goto" value="${t.id}">${html_escape(t.title)}</button>')
		sb.write_string('<button type="submit" name="close" value="${t.id}" class="close" title="Close">&times;</button></span>')
	}
	sb.write_string('<button type="submit" name="new" value="1" class="new" title="New tab">+</button></div>')
}

const app_css = $embed_file('app.css')
const app_highlight_js = $embed_file('app_highlight.js')
const app_js = $embed_file('app.js')
const app_confirm_js = $embed_file('app_confirm.js')
const app_edit_js = $embed_file('app_edit.js')
const app_sidebar_js = $embed_file('app_sidebar.js')

const show_tables_sql = 'SELECT * FROM INFORMATION_SCHEMA.TABLES'

// tab_title is the start of the first line of SQL in a tab.
fn tab_title(query_text string) string {
	line := query_text.trim_space().all_before('\n').trim_space()
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
