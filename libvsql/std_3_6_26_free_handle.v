module main

// ISO/IEC 9075-3:2003(E), 6.26, FreeHandle
//
// Free a resource.

@[export: 'SQLFreeHandle']
fn sql_free_handle(handle_type i16, handle SQLInteger) i16 {
	entry := enter(handle_type, i64(handle))
	defer {
		entry.leave()
	}
	h := i64(handle)

	match handle_type {
		sql_handle_env {
			mut env := envs[h] or { return sql_invalid_handle }
			env.diag.clear()

			// - 3.a.iv. If an allocated SQL-connection is associated with E, then
			// an exception condition is raised: CLI-specific condition — function
			// sequence error.
			for _, dbc in dbcs {
				if dbc.env == h {
					return env.diag.error(cli_error('HY010', 'function sequence error'))
				}
			}

			envs.delete(h)
		}
		sql_handle_dbc {
			mut dbc := dbcs[h] or { return sql_invalid_handle }
			dbc.diag.clear()

			// - 3.b.iv. If an established SQL-connection is associated with C,
			// then an exception condition is raised: CLI-specific condition —
			// function sequence error.
			if dbc.conn != none {
				return dbc.diag.error(cli_error('HY010', 'function sequence error'))
			}

			dbcs.delete(h)
		}
		sql_handle_stmt {
			// - 3.c.vii, 3.c.viii. An open cursor is closed, and the
			// automatically allocated descriptors are freed, with the statement.
			mut stmt := stmts[h] or { return sql_invalid_handle }
			stmt.diag.clear()

			// - 3.c.v, 3.c.vi. EC becomes the current SQL-connection, and if
			// there is a deferred parameter number associated with S, then an
			// exception condition is raised: CLI-specific condition — function
			// sequence error.
			stmt.invoke(false) or { return stmt.diag.error(err) }
			stmt.close_cursor()
			autocommit(mut stmt.diag, stmt.dbc, true) or { return stmt.diag.error(err) }

			free_stmt(h)
		}
		sql_handle_desc {
			mut desc := descs[h] or { return sql_invalid_handle }
			desc.diag.clear()

			// - 3.d.v. EC becomes the current SQL-connection.
			desc.invoke() or { return desc.diag.error(err) }

			// - 3.d.vi. See 5.11, "Deferred parameter check".
			check_desc_deferred(h) or { return desc.diag.error(err) }

			// - 3.d.viii. If AT indicates AUTOMATIC, then an exception condition
			// is raised: CLI-specific condition — invalid use of
			// automatically-allocated descriptor handle.
			if desc.stmt != 0 {
				return desc.diag.error(cli_error('HY017', 'invalid use of automatically-allocated descriptor handle'))
			}

			free_desc(h)
		}
		else {
			return sql_invalid_handle
		}
	}

	return sql_success
}
