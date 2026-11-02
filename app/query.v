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
}

// run_query runs every statement in a file and returns the result of the last
// one, and what to record in the history.
fn (a &App) run_query(mut conn vsql.Connection, query_text string, params Params, catalog string) !(TabResult, History) {
	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
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
	} else if result.columns.len > 0 {
		// The rows of SELECT * FROM a table with a PRIMARY KEY can be changed
		// (see edit.v and app_edit.js) after choosing Edit, until then the row
		// actions are hidden.
		edit := a.editable_table(mut conn, query_text, result)
		if table := edit {
			is_editable = true
			output.write_string('<table class="editable" data-catalog="${html_escape(table.catalog)}" data-schema="${html_escape(table.schema)}" data-table="${html_escape(table.name)}"><thead><tr><th class="row-actions"></th>')
		} else {
			output.write_string('<table><thead><tr>')
		}
		for i, column in result.columns {
			mut th_attrs := ''
			if table := edit {
				if !table.columns[i].generated {
					th_attrs = ' data-column="${html_escape(column.name.sub_entity_name)}"'
					if column.typ.typ == .is_boolean {
						th_attrs += ' data-boolean'
					}
					if table.columns[i].required {
						th_attrs += ' data-required'
					}
				}
			}
			output.write_string('<th${th_attrs}>${html_escape(column.name.sub_entity_name)}<span class="type">${html_escape(column.typ.str())}</span></th>')
		}
		output.write_string('</tr></thead><tbody>')
		count = 0
		for row in result {
			if table := edit {
				output.write_string('<tr data-key="${html_escape(row_key(table, row)!)}"><td class="row-actions"><button type="button" class="delete" title="Delete">&times;</button></td>')
			} else {
				output.write_string('<tr>')
			}
			for i, column in result.columns {
				value := row.get_column(column)!
				mut attrs := if value.is_null { ' class="null"' } else { '' }
				if table := edit {
					if !table.columns[i].generated {
						attrs += ' data-column="${html_escape(column.name.sub_entity_name)}"'
						if column.typ.typ == .is_boolean {
							attrs += ' data-boolean'
						}
					}
				}
				output.write_string('<td${attrs}>${html_escape(value.str())}</td>')
			}
			output.write_string('</tr>')
			count++
		}
		output.write_string('</tbody>')
		if table := edit {
			output.write_string('<tfoot><tr><td class="row-actions"><button type="button" class="add" title="Add a row">+</button></td><td colspan="${table.columns.len}"></td></tr></tfoot>')
		}
		output.write_string('</table>')
		status = '${count} ${vsql.pluralize(count, 'row')} (${elapsed} ms)'
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
