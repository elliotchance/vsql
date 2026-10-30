module main

// ISO/IEC 9075-3:2003(E), 6.3, AllocHandle
//
// Allocate a resource and assign a handle to it.
//
// There's no limit on the number of handles, other than they wrap after 2^31
// allocations (General Rules 3.a.i, 3.b.iv, 3.c.v and 3.d.v), which is #746.
// Memory isn't limited (see 4.4.1, "Handles"), and the resources can always be
// allocated, so General Rules 3.a.ii.1, 3.a.ii.2, 3.b.v.1, 3.b.v.2, 3.c.vii,
// 3.c.viii, 3.d.vii.1 and 3.d.vii.2 can't happen, and there's never a skeleton
// SQL-environment. The diagnostics area of the SQL-environment or
// SQL-connection is emptied (General Rules 3.b.iii, 3.c.iii and 3.d.iii).

@[export: 'SQLAllocHandle']
fn sql_alloc_handle(handle_type i16, input_handle SQLInteger, output_handle &SQLInteger) i16 {
	entry := enter(alloc_input_type(handle_type), i64(input_handle))
	defer {
		entry.leave()
	}
	ih := i64(input_handle)

	match handle_type {
		sql_handle_env {
			// - 3.a.ii.3. The SQL-environment is allocated and assigned a unique
			// value that is returned in OutputHandle.
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
			// - 3.b.v.3. The SQL-connection is associated with E.
			h := new_handle()
			dbcs[h] = &Dbc{
				handle: h
				env:    ih
			}
			unsafe {
				*output_handle = SQLInteger(h)
			}
		}
		sql_handle_stmt, sql_handle_desc {
			// - 3.c.i, 3.d.i. If IH does not identify an allocated
			// SQL-connection, then OutputHandle is set to zero and an exception
			// condition is raised: CLI-specific condition — invalid handle.
			mut dbc := dbcs[ih] or { return set_zero(output_handle, sql_invalid_handle) }
			dbc.diag.clear()
			if output_handle == unsafe { nil } {
				return dbc.diag.error(cli_error('HY009', 'invalid use of null pointer'))
			}

			// - 3.c.iv, 3.d.iv. If there is no established SQL-connection associated with
			// C, then OutputHandle is set to zero and an exception condition is
			// raised: connection exception — connection does not exist.
			if dbc.conn == none {
				return set_zero(output_handle, dbc.diag.error(cli_error('08003', 'connection does not exist')))
			}

			// - 3.c.vi, 3.d.vi. If EC is not the current SQL-connection, then
			// the General Rules of Subclause 5.3, "Implicit set connection", are
			// applied to EC as the dormant SQL-connection.
			implicit_set_connection(ih) or {
				return set_zero(output_handle, dbc.diag.error(err))
			}

			// - 3.c.ix, 3.c.x, 3.c.xi. A statement is allocated with its own
			// ARD, APD, IRD and IPD (see new_stmt).
			//
			// - 3.d.vii.3. A descriptor allocated by the application has an
			// ALLOC_TYPE of USER and the default values for an ARD.
			h := if handle_type == sql_handle_desc { new_desc(ih, .ard, 0) } else { new_stmt(ih) }
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
