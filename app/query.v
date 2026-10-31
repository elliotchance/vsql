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
		// The rows of SELECT * FROM a table can be changed (see edit.v and
		// app_edit.js). A row can only be updated or deleted if the table has
		// a PRIMARY KEY.
		edit := a.editable_table(mut conn, query_text, result)
		mut has_key := false
		if table := edit {
			has_key = table.primary_key.len > 0
			output.write_string('<table class="editable" data-catalog="${html_escape(table.catalog)}" data-schema="${html_escape(table.schema)}" data-table="${html_escape(table.name)}"><thead><tr><th></th>')
		} else {
			output.write_string('<table><thead><tr>')
		}
		for column in result.columns {
			output.write_string('<th>${html_escape(column.name.sub_entity_name)}<span class="type">${html_escape(column.typ.str())}</span></th>')
		}
		output.write_string('</tr></thead><tbody>')
		mut count := 0
		for row in result {
			if table := edit {
				if has_key {
					output.write_string('<tr data-key="${html_escape(row_key(table, row)!)}"><td class="row-actions"><button type="button" class="delete" title="Delete">&times;</button></td>')
				} else {
					output.write_string('<tr><td class="row-actions"></td>')
				}
			} else {
				output.write_string('<tr>')
			}
			for i, column in result.columns {
				value := row.get_column(column)!
				mut attrs := if value.is_null { ' class="null"' } else { '' }
				if table := edit {
					if has_key && !table.columns[i].generated {
						attrs += ' data-column="${html_escape(column.name.sub_entity_name)}" title="Double-click to edit"'
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
			output.write_string('<tfoot><tr class="insert"><td class="row-actions"><button type="button" class="add" title="Add">+</button></td>')
			for column in table.columns {
				if column.generated {
					output.write_string('<td class="null">generated</td>')
				} else if column.typ.typ == .is_boolean {
					output.write_string('<td><select data-column="${html_escape(column.name)}"><option value="">DEFAULT</option><option>UNKNOWN</option><option>TRUE</option><option>FALSE</option></select></td>')
				} else {
					output.write_string('<td><input data-column="${html_escape(column.name)}" placeholder="DEFAULT" spellcheck="false"></td>')
				}
			}
			output.write_string('</tr></tfoot>')
		}
		output.write_string('</table>')
		status = '${count} ${vsql.pluralize(count, 'row')} (${elapsed} ms)'
	}

	return TabResult{
		status: status
		output: output.str()
	}
}
