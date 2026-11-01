module app

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

// run_query runs every statement and returns the result of the last one.
fn (a &App) run_query(mut conn vsql.Connection, query_text string) !TabResult {
	mut status := ''
	mut output := strings.new_builder(4096)
	// Every statement is run, the result of the last one is shown. The time
	// is for all of the statements, like the CLI.
	start := time.ticks()
	mut result := vsql.Result{}
	mut failed := false
	mut is_editable := false
	mut has_rows := false
	for stmt in vsql.split_statements(query_text) {
		result = conn.query(stmt) or {
			output.write_string('<p class="error">${html_escape(err.msg())}</p>')
			failed = true
			break
		}
	}
	elapsed := time.ticks() - start
	if failed {
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
		mut count := 0
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
	}
}
