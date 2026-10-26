module main

// ISO/IEC 9075-3:2003(E), 6.26, FreeHandle
//
// Free a resource.

@[export: 'SQLFreeHandle']
fn sql_free_handle(handle_type i16, handle SQLInteger) i16 {
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
			// - 3.c.vii. An open cursor is closed with the statement.
			if h !in stmts {
				return sql_invalid_handle
			}

			stmts.delete(h)
		}
		else {
			// There are no CLI descriptor areas, so a DESCRIPTOR HANDLE can't
			// identify one.
			return sql_invalid_handle
		}
	}

	return sql_success
}
