module app

import net.urllib
import strings
import time
import vsql

struct TabResult {
	// status is the number of rows (or the message of a statement) and the
	// time, shown next to the Run button.
	status string
	// output is the HTML of the rows or error.
	output string
	// error is from a change to a row (see edit.v), which is shown above the
	// output. It's not kept.
	error string
	// has_rows is true if output is a table of rows, which shows the Edit
	// button. It's disabled unless editable is true (see edit.v).
	has_rows bool
	editable bool
	// notice is what happened (such as a file that was imported), shown above
	// the output until the tab is run again.
	notice string
}

// max_result_rows is the most rows of a result that are shown, a page with more
// would be slow. The query has to change to see the others.
const max_result_rows = 10000

// max_cell_length is the most characters of a string shown in a cell, see
// app_result.js.
const max_cell_length = 50

// explain_terms are the terms that start a line of a plan and have more than
// one word. The others are the first word, such as EXPR or WHERE.
const explain_terms = ['VIRTUAL TABLE', 'PRIMARY KEY', 'GROUP BY', 'ORDER BY', 'FETCH FIRST',
	'INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN']

// explain_keywords are the keywords in a line of a plan, after its first term,
// that are highlighted: the table of an INDEX, the range of a PRIMARY KEY or
// INDEX, and the condition of a join.
const explain_keywords = {
	'INDEX':       [' ON ', ' RANGE ']
	'PRIMARY KEY': [' RANGE ']
	'INNER JOIN':  [' ON ']
	'LEFT JOIN':   [' ON ']
	'RIGHT JOIN':  [' ON ']
}

// explain_line is the HTML of a line of a plan, with the first term (and the
// explain_keywords of that term) highlighted.
fn explain_line(line string) string {
	text := line.trim_left(' ')
	indent := line[..line.len - text.len]
	mut term := text.all_before(' ')
	for known in explain_terms {
		if text.starts_with('${known} ') {
			term = known
		}
	}

	mut html := '${indent}<span class="kw">${html_escape(term)}</span>'
	mut rest := text[term.len..]
	for keyword in explain_keywords[term] or { []string{} } {
		i := top_level_index(rest, keyword)
		if i < 0 {
			continue
		}
		html += '${html_escape(rest[..i])} <span class="kw">${keyword.trim_space()}</span> '
		rest = rest[i + keyword.len..]
	}

	return html + html_escape(rest)
}

// top_level_index is the position of the first s in text that isn't in a
// quoted name or string, or in parentheses (such as the columns of a table),
// or -1 if there isn't one.
fn top_level_index(text string, s string) int {
	mut depth := 0
	mut quote := u8(0)
	for i, c in text {
		if quote != 0 {
			// A quote in a name or string is doubled, which is the same as the
			// name or string ending and another one starting.
			if c == quote {
				quote = 0
			}
		} else if c == `"` || c == `'` {
			quote = c
		} else if c == `(` {
			depth++
		} else if c == `)` {
			depth--
		} else if depth == 0 && text[i..].starts_with(s) {
			return i
		}
	}

	return -1
}

// default_query_schema is the schema of a QUERY tab, unless another one is chosen.
const default_query_schema = 'PUBLIC'

// query_schemas is the schemas that can be chosen on a QUERY tab of a file, by name.
fn (a &App) query_schemas(mut conn vsql.Connection, catalog string) ![]string {
	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	mut cat := conn.catalog()
	mut names := cat.schemas()!.map(it.name)
	names.sort()

	return names
}

// query_tab_schema is the schema that a QUERY tab runs in, which is the default if
// the one that's saved no longer exists.
fn query_tab_schema(schemas []string, schema string) string {
	return if schema in schemas { schema } else { default_query_schema }
}

// set_schema makes a schema current, in the current catalog.
fn set_schema(mut conn vsql.Connection, name string) ! {
	conn.query("SET SCHEMA '${name.replace("'", "''")}'")!
}

// run_query runs every statement in a file and returns the result of the last
// one, and what to record in the history. If explain is true, a plan is shown
// as lines of text instead of a table.
fn (a &App) run_query(mut conn vsql.Connection, query_text string, params Params, catalog string, schema string, explain bool) !(TabResult, History) {
	schemas := a.query_schemas(mut conn, catalog)!
	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	// This isn't part of the SQL of the tab, or its history.
	query_schema := query_tab_schema(schemas, schema)
	if query_schema in schemas {
		set_schema(mut conn, query_schema)!
	}
	defer {
		set_schema(mut conn, default_query_schema) or {}
	}

	mut status := ''
	mut output := strings.new_builder(4096)
	// Every statement is run, the result of the last one is shown. The time
	// is for all of the statements, like the CLI.
	start := time.ticks()
	mut result := vsql.Result{}
	mut failure := ''
	mut count := -1
	mut is_editable := false
	mut has_rows := false
	mut next_param := 0
	for stmt in vsql.split_statements(query_text) {
		result = run_statement(mut conn, stmt, params, mut &next_param) or {
			output.write_string('<p class="error">${html_escape(err.msg())}</p>')
			failure = err.msg()
			break
		}
	}
	elapsed := time.ticks() - start
	if failure != '' {
		status = 'Error (${elapsed} ms)'
	} else if result.msg != '' {
		status = '${result.msg} (${elapsed} ms)'
	} else if explain && result.columns.len == 1
		&& result.columns[0].name.sub_entity_name == 'EXPLAIN' {
		// Only the first statement has EXPLAIN in front of it, so the last one
		// might not be a plan.
		mut lines := []string{}
		for row in result {
			lines << row.get_column(result.columns[0])!.str()
		}
		output.write_string('<pre class="explain">${lines.map(explain_line(it)).join('\n')}</pre>')
		count = lines.len
		status = '${count} ${vsql.pluralize(count, 'row')} (${elapsed} ms)'
	} else if result.columns.len > 0 {
		// The rows of SELECT * FROM a table with a PRIMARY KEY can be changed
		// (see edit.v and app_edit.js) after choosing Edit, until then the row
		// actions are hidden.
		edit := a.editable_table(mut conn, query_text, result)
		if table := edit {
			is_editable = true
			output.write_string('<table class="result editable" data-catalog="${html_escape(table.catalog)}" data-schema="${html_escape(table.schema)}" data-table="${html_escape(table.name)}"><thead><tr><th class="row-actions"></th>')
		} else {
			output.write_string('<table class="result"><thead><tr>')
		}
		// A column of a table is NOT NULL, but vsql also says that for a column on
		// the outer side of a join, which can be NULL, so it's left out for a join.
		// It's not known for a column that's named in the SELECT (see #897).
		for i, column in result.columns {
			is_not_null := column.not_null && !query_text.to_upper().contains('JOIN')
			// The name of a NOT NULL column is underlined, like in the sidebar.
			mut classes := []string{}
			if is_number_type(column.typ) {
				classes << 'number'
			}
			if is_not_null {
				classes << 'not-null'
			}
			mut th_attrs := if classes.len > 0 { ' class="${classes.join(' ')}"' } else { '' }
			// A column without a name (such as COL1) can't be sorted, see
			// app_result.js.
			th_attrs += if column.unnamed { ' data-unnamed' } else { ' title="Click to sort"' }
			if table := edit {
				if !table.columns[i].generated {
					th_attrs += ' data-column="${html_escape(column.name.sub_entity_name)}"'
					if column.typ.typ == .is_boolean {
						th_attrs += ' data-boolean'
					}
					if table.columns[i].required {
						th_attrs += ' data-required'
					}
				}
			}
			not_null := if is_not_null { ' NOT NULL' } else { '' }
			output.write_string('<th${th_attrs}><span class="title"><span class="icon" aria-hidden="true">${type_emoji(column.typ)}</span><span class="name">${html_escape(column.name.sub_entity_name)}</span></span><span class="type">${html_escape(column.typ.str())}${not_null}</span></th>')
		}
		output.write_string('</tr></thead><tbody>')
		count = 0
		for row in result {
			// The others are only counted.
			count++
			if count > max_result_rows {
				continue
			}
			if table := edit {
				output.write_string('<tr data-key="${html_escape(row_key(table, row)!)}"><td class="row-actions"><button type="button" class="delete" title="Delete">&times;</button></td>')
			} else {
				output.write_string('<tr>')
			}
			for i, column in result.columns {
				value := row.get_column(column)!
				text := value.str()
				mut classes := []string{}
				if value.is_null {
					classes << 'null'
				}
				if is_number_type(column.typ) {
					classes << 'number'
				}
				if column.typ.typ == .is_boolean {
					classes << 'boolean-${text.to_lower()}'
				}
				mut attrs := if classes.len > 0 { ' class="${classes.join(' ')}"' } else { '' }
				if table := edit {
					if !table.columns[i].generated {
						attrs += ' data-column="${html_escape(column.name.sub_entity_name)}"'
						if column.typ.typ == .is_boolean {
							attrs += ' data-boolean'
						}
					}
				}
				// A long string is shortened by app_result.js, which can show all of
				// it.
				if !value.is_null && column.typ.typ in [.is_varchar, .is_character]
					&& text.runes().len > max_cell_length {
					attrs += ' data-full="${html_escape(text)}"'
				}
				output.write_string('<td${attrs}>${html_escape(text)}</td>')
			}
			output.write_string('</tr>')
		}
		output.write_string('</tbody>')
		if table := edit {
			output.write_string('<tfoot><tr><td class="row-actions"><button type="button" class="add" title="Add a row">+</button></td><td colspan="${table.columns.len}"></td></tr></tfoot>')
		}
		output.write_string('</table>')
		if count > max_result_rows {
			output.write_string('<p class="more-rows">There are more rows than the ${max_result_rows} shown. Change the query to see the others, such as with WHERE or OFFSET.</p>')
			status = '${max_result_rows}+ rows (${elapsed} ms)'
		} else {
			status = '${count} ${vsql.pluralize(count, 'row')} (${elapsed} ms)'
		}
		has_rows = true
	}

	return TabResult{
		status:   status
		output:   output.str()
		has_rows: has_rows
		editable: is_editable
	}, History{
		query_text: query_text
		row_count:  count
		message:    if failure == '' { result.msg } else { '' }
		error:      failure
	}
}

// is_number_type is true for a type that's shown as a number.
fn is_number_type(typ vsql.Type) bool {
	return typ.typ in [.is_smallint, .is_integer, .is_bigint, .is_real, .is_double_precision,
		.is_decimal, .is_numeric]
}

// Params are the value and type of each "?" of a tab. The "?"s are numbered
// through all of the statements of the tab. A parameter isn't cast to the type
// it's used as, so it needs a type. The type is chosen for each "?" or guessed
// from its value (see app.js), which is posted as "auto:" and the type.
struct Params {
	values []string
	types  []string
}

// run_statement runs a statement with the next params for each "?" in it.
fn run_statement(mut conn vsql.Connection, stmt string, params Params, mut next_param &int) !vsql.Result {
	mut prepared := conn.prepare(stmt)!
	mut values := map[string]vsql.Value{}
	for i in 1 .. prepared.dynamic_parameter_count() + 1 {
		text := params.values[*next_param] or { '' }
		typ := params.types[*next_param] or { 'auto:text' }
		next_param++
		values['?${i}'] = param_value(text, typ) or {
			return error('?${*next_param}: ${err.msg()}')
		}
	}

	return prepared.query(values)
}

// param_value is the value of a "?" with its type. TRUE, FALSE, UNKNOWN and NULL
// are the value. Only text can be empty if it's chosen, a guess needs a value.
fn param_value(text string, typ string) !vsql.Value {
	match typ {
		'null' {
			return vsql.new_null_value(.is_varchar)
		}
		'true' {
			return vsql.new_boolean_value(true)
		}
		'false' {
			return vsql.new_boolean_value(false)
		}
		'unknown' {
			return vsql.new_unknown_value()
		}
		'text' {
			return vsql.new_varchar_value(text)
		}
		else {}
	}
	if text == '' {
		return error('no value')
	}
	match typ.all_after('auto:') {
		'text' {
			return vsql.new_varchar_value(text)
		}
		'number' {
			upper := text.to_upper()
			if is_decimal(text) {
				return vsql.new_numeric_value(text)
			}
			if upper.contains('E') && is_decimal(upper.all_before('E'))
				&& is_decimal(upper.all_after('E')) {
				return vsql.new_double_precision_value(text.f64())
			}
			return error('${text} is not a number')
		}
		'boolean' {
			match text.to_upper() {
				'TRUE' { return vsql.new_boolean_value(true) }
				'FALSE' { return vsql.new_boolean_value(false) }
				'UNKNOWN' { return vsql.new_unknown_value() }
				else { return error('${text} is not TRUE, FALSE or UNKNOWN') }
			}
		}
		'date' {
			return vsql.new_date_value(text)
		}
		'time' {
			return vsql.new_time_value(text)
		}
		'timestamp' {
			return vsql.new_timestamp_value(text.replace('T', ' '))
		}
		else {
			return error('unknown type: ${typ}')
		}
	}
}

// is_decimal is true for digits with an optional sign and decimal point.
fn is_decimal(text string) bool {
	digits := text.trim_left('+-')
	return text.len - digits.len <= 1 && digits.count('.') <= 1 && digits.replace('.', '') != ''
		&& digits.bytes().all(it.is_digit() || it == `.`)
}

// posted_params are the value and type of each "?" posted with the SQL, as
// param:1 and param_type:1, param:2 and param_type:2, etc.
fn posted_params(form urllib.Values) Params {
	mut values := []string{}
	mut types := []string{}
	for {
		values << form.get('param:${values.len + 1}') or { break }
		types << form.get('param_type:${values.len}') or { 'auto:text' }
	}

	return Params{values, types}
}
