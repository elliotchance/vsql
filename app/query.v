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
}

// run_query runs every statement and returns the result of the last one.
fn run_query(mut conn vsql.Connection, query_text string) !TabResult {
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
		output.write_string('<table><thead><tr>')
		for column in result.columns {
			output.write_string('<th>${html_escape(column.name.sub_entity_name)}<span class="type">${html_escape(column.typ.str())}</span></th>')
		}
		output.write_string('</tr></thead><tbody>')
		mut count := 0
		for row in result {
			output.write_string('<tr>')
			for column in result.columns {
				value := row.get_column(column)!
				if value.is_null {
					output.write_string('<td class="null">${value}</td>')
				} else {
					output.write_string('<td>${html_escape(value.str())}</td>')
				}
			}
			output.write_string('</tr>')
			count++
		}
		output.write_string('</tbody></table>')
		status = '${count} ${vsql.pluralize(count, 'row')} (${elapsed} ms)'
	}

	return TabResult{status, output.str()}
}
