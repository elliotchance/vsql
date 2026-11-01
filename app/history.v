module app

import vsql

// history_limit is the number of queries kept in the history of each tab.
const history_limit = 100

// History is a query that was run in a tab, with the number of rows (-1 if it's
// not a query, then it has a message instead, or it failed) or the error, and
// when it was run.
struct History {
	query_text string
	row_count  int = -1
	message    string
	error      string
	ran_at     string
}

// add_history records a query run in a tab, and removes the oldest so only
// history_limit are kept.
fn add_history(mut conn vsql.Connection, catalog string, tab_id int, h History) ! {
	table := app_table(catalog, 'history')
	row_count := if h.row_count < 0 {
		vsql.new_null_value(.is_integer)
	} else {
		vsql.new_integer_value(h.row_count)
	}
	mut stmt := conn.prepare('INSERT INTO ${table} (tab_id, query_text, row_count, message, error, ran_at) VALUES (?, ?, ?, ?, ?, LOCALTIMESTAMP(0))')!
	stmt.query({
		'?1': vsql.new_integer_value(tab_id)
		'?2': vsql.new_varchar_value(h.query_text)
		'?3': row_count
		'?4': nullable_varchar(h.message)
		'?5': nullable_varchar(h.error)
	})!

	mut oldest := conn.prepare('SELECT id FROM ${table} WHERE tab_id = ? ORDER BY id DESC OFFSET ${history_limit} ROWS FETCH FIRST 1 ROW ONLY')!
	for row in oldest.query({
		'?1': vsql.new_integer_value(tab_id)
	})! {
		mut remove := conn.prepare('DELETE FROM ${table} WHERE tab_id = ? AND id <= ?')!
		remove.query({
			'?1': vsql.new_integer_value(tab_id)
			'?2': vsql.new_integer_value(row.get_int('ID')!)
		})!
	}
}

// remove_history removes the history of a tab that's closed.
fn remove_history(mut conn vsql.Connection, catalog string, tab_id int) ! {
	mut stmt := conn.prepare('DELETE FROM ${app_table(catalog, 'history')} WHERE tab_id = ?')!
	stmt.query({
		'?1': vsql.new_integer_value(tab_id)
	})!
}

// history is the queries run in a tab, the latest first.
fn history(mut conn vsql.Connection, catalog string, tab_id int) ![]History {
	mut stmt := conn.prepare('SELECT query_text, row_count, message, error, ran_at FROM ${app_table(catalog, 'history')} WHERE tab_id = ? ORDER BY id DESC')!

	return history_entries(stmt.query({
		'?1': vsql.new_integer_value(tab_id)
	})!)
}

// all_history is the queries saved in a file, the latest first.
fn all_history(mut conn vsql.Connection, catalog string) ![]History {
	return history_entries(conn.query('SELECT query_text, row_count, message, error, ran_at FROM ${app_table(catalog, 'history')} ORDER BY id DESC')!)
}

fn history_entries(result vsql.Result) ![]History {
	mut entries := []History{}
	for row in result {
		entries << History{
			query_text: row.get_string('QUERY_TEXT')!
			row_count:  if row.get_null('ROW_COUNT')! { -1 } else { row.get_int('ROW_COUNT')! }
			message:    if row.get_null('MESSAGE')! { '' } else { row.get_string('MESSAGE')! }
			error:      if row.get_null('ERROR')! { '' } else { row.get_string('ERROR')! }
			ran_at:     row.get('RAN_AT')!.str().replace('T', ' ')
		}
	}

	return entries
}

fn nullable_varchar(s string) vsql.Value {
	return if s == '' { vsql.new_null_value(.is_varchar) } else { vsql.new_varchar_value(s) }
}
