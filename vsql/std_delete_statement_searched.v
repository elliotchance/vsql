module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>
//
// # Function
//
// Delete rows of a table.
//
// # Format
//~
//~ <delete statement: searched> /* Stmt */ ::=
//~     DELETE FROM <target table>   -> delete_statement
//~   | DELETE FROM <target table>
//~     WHERE <search condition>     -> delete_statement_where

struct DeleteStatementSearched {
	table_name Identifier
	where      ?BooleanValueExpression
}

fn parse_delete_statement(table_name Identifier) !Stmt {
	return DeleteStatementSearched{table_name, none}
}

fn parse_delete_statement_where(table_name Identifier, where BooleanValueExpression) !Stmt {
	return DeleteStatementSearched{table_name, where}
}

fn (stmt DeleteStatementSearched) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut plan := create_plan(stmt, params, mut conn)!

	return plan.explain(elapsed_parse)
}

fn (stmt DeleteStatementSearched) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut plan := create_plan(stmt, params, mut conn)!
	mut rows := plan.execute([]Row{})!

	for mut row in rows {
		catalog.storage.delete_row(table_name.storage_id(), mut row)!
	}

	return new_result_msg('DELETE ${rows.len}', elapsed_parse, t.elapsed())
}
