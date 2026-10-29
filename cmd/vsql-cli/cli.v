module main

import cli
import os
import time
import vsql

fn register_cli_command(mut cmd cli.Command) {
	mut cli_cmd := cli.Command{
		name:          'cli'
		usage:         '<file>'
		required_args: 1
		description:   'Run SQL in a vsql file'
		execute:       cli_command
	}
	cli_cmd.add_flag(cli.Flag{
		flag:          .bool
		name:          'autocommit'
		default_value: ['true']
		description:   'Commit each statement that is not inside a START TRANSACTION (default true). The SQL standard has no autocommit, which is the same as -autocommit=false'
	})
	cmd.add_command(cli_cmd)
}

fn cli_command(cmd cli.Command) ! {
	print_version()
	println('')

	mut db := vsql.open(cmd.args[0])!
	autocommit := cmd.flags.get_bool('autocommit')!

	for arg in cmd.args[1..] {
		catalog_name := vsql.catalog_name_from_path(arg)
		options := vsql.default_connection_options()
		db.add_catalog(catalog_name, arg, options)!
	}

	// Each statement is a <direct SQL statement> (ISO/IEC 9075-2:2016(E), 22.1),
	// so it ends with a semicolon and can be over many lines.
	mut unfinished := ''
	for {
		print(if unfinished == '' { 'vsql> ' } else { '   -> ' })
		os.flush()

		// An empty string means there is no more input. This happens when the
		// statements are being fed through a pipe like:
		//
		//   echo "VALUES CURRENT_CATALOG;" | vsql cli
		line := os.get_raw_line()
		if line == '' {
			println('')
			break
		}

		// When running on Docker, ctrl+C doesn't always get passed through. Also,
		// this provides another text based way to break out of the shell.
		if unfinished == '' && line.trim_space() == 'exit' {
			break
		}

		statements, rest := vsql.split_terminated_statements(unfinished + line)
		unfinished = rest
		for stmt in statements {
			run_direct(mut db, stmt + ';', autocommit)
		}
	}

	// A statement without a semicolon at the end of the input is a syntax error.
	if unfinished != '' {
		run_direct(mut db, unfinished, autocommit)
	}

	// - 22.1 GR 2.a. Without autocommit, an SQL-transaction that is still active
	// at the end is committed. If the shell stops any other way (such as with
	// ctrl+C), or a START TRANSACTION isn't finished with autocommit, it's
	// rolled back.
	if !autocommit && db.in_transaction() {
		db.query('COMMIT') or { print_error('Error', err) }
	}
}

fn run_direct(mut db vsql.Connection, stmt string, autocommit bool) {
	start := time.ticks()
	db.clear_warnings()
	result := db.direct(stmt, autocommit: autocommit) or {
		print_error('Error', err)
		return
	}

	for warning in db.warnings {
		// 02000 (no data) is a completion condition, not a warning.
		if vsql.sqlstate_from_int(warning.code()).starts_with('02') {
			print_error('Notice', warning)
		} else {
			print_error('Warning', warning)
		}
	}

	if result.msg != '' {
		println('${result.msg} (${time.ticks() - start} ms)\n')
		return
	}

	total_rows := print_table(result) or {
		print_error('Error', err)
		return
	}

	println('${total_rows} ${vsql.pluralize(total_rows, 'row')} (${time.ticks() - start} ms)\n')
}

fn print_error(prefix string, err IError) {
	if err.code() > 0 {
		sqlstate := vsql.sqlstate_from_int(err.code())
		println('${prefix} ${sqlstate}: ${err.msg()}\n')
	} else {
		println('ERROR: ${err}\n')
	}
}

// print_table prints the rows of a result as a table, and returns the number of
// rows:
//
//   NAME   | PRICE
//   -------+------
//   Bagel  |  2.25
//   Coffee |  4.50
//
// Numbers are right-aligned so that their digits line up. Nothing is printed
// when there are no rows.
fn print_table(result vsql.Result) !int {
	mut rows := [][]string{}
	for row in result {
		mut cells := []string{}
		for column in result.columns {
			cells << row.get_column(column)!.str()
		}
		rows << cells
	}

	if rows.len == 0 {
		return 0
	}

	mut header := []string{}
	mut widths := []int{}
	mut right_align := []bool{}
	for column in result.columns {
		header << column.name.sub_entity_name
		widths << utf8_str_visible_length(column.name.sub_entity_name)
		right_align << is_number(column.typ)
	}

	for cells in rows {
		for i, cell in cells {
			widths[i] = int_max(widths[i], utf8_str_visible_length(cell))
		}
	}

	println(table_line(header, widths, right_align))
	println(widths.map('-'.repeat(it)).join('-+-'))
	for cells in rows {
		println(table_line(cells, widths, right_align))
	}

	return rows.len
}

// table_line pads each cell to the width of its column. The last cell isn't
// padded on the right, so that lines don't end with spaces.
fn table_line(cells []string, widths []int, right_align []bool) string {
	mut padded := []string{}
	for i, cell in cells {
		padding := ' '.repeat(widths[i] - utf8_str_visible_length(cell))
		padded << if right_align[i] {
			padding + cell
		} else if i == cells.len - 1 {
			cell
		} else {
			cell + padding
		}
	}

	return padded.join(' | ')
}

fn is_number(typ vsql.Type) bool {
	return typ.typ in [.is_smallint, .is_integer, .is_bigint, .is_real, .is_double_precision,
		.is_numeric, .is_decimal]
}
