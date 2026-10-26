module main

// ISO/IEC 9075-3:2003(E), 6.3, AllocHandle
//
// Allocate a resource and assign a handle to it.

@[export: 'SQLAllocHandle']
fn sql_alloc_handle(handle_type i16, input_handle SQLInteger, output_handle &SQLInteger) i16 {
	ih := i64(input_handle)

	match handle_type {
		sql_handle_env {
			if output_handle == unsafe { nil } {
				return sql_error
			}
			h := new_handle()
			envs[h] = &Env{}
			unsafe {
				*output_handle = SQLInteger(h)
			}
		}
		sql_handle_dbc {
			// - 3.b.i. If IH does not identify an allocated SQL-environment, then
			// OutputHandle is set to zero and an exception condition is raised:
			// CLI-specific condition — invalid handle.
			mut env := envs[ih] or { return set_zero(output_handle, sql_invalid_handle) }
			env.diag.clear()
			if output_handle == unsafe { nil } {
				return env.diag.error(cli_error('HY009', 'invalid use of null pointer'))
			}
			h := new_handle()
			dbcs[h] = &Dbc{
				env: ih
			}
			unsafe {
				*output_handle = SQLInteger(h)
			}
		}
		sql_handle_stmt, sql_handle_desc {
			mut dbc := dbcs[ih] or { return set_zero(output_handle, sql_invalid_handle) }
			dbc.diag.clear()
			if output_handle == unsafe { nil } {
				return dbc.diag.error(cli_error('HY009', 'invalid use of null pointer'))
			}

			// - 3.c.iv. If there is no established SQL-connection associated with
			// C, then OutputHandle is set to zero and an exception condition is
			// raised: connection exception — connection does not exist.
			if dbc.conn == none {
				return set_zero(output_handle, dbc.diag.error(cli_error('08003', 'connection does not exist')))
			}

			// CLI descriptor areas are not supported yet.
			if handle_type == sql_handle_desc {
				return set_zero(output_handle, dbc.diag.error(cli_error('HYC00', 'optional feature not implemented')))
			}

			h := new_handle()
			stmts[h] = &Stmt{
				dbc: ih
			}
			unsafe {
				*output_handle = SQLInteger(h)
			}
		}
		else {
			// - 2. If HT is not one of the code values in Table 13, then an
			// exception condition is raised: CLI-specific condition — invalid
			// handle.
			return set_zero(output_handle, sql_invalid_handle)
		}
	}

	return sql_success
}

fn set_zero(output_handle &SQLInteger, rc i16) i16 {
	if output_handle != unsafe { nil } {
		unsafe {
			*output_handle = 0
		}
	}

	return rc
}
