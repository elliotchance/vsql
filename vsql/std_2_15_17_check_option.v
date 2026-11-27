module vsql

// ISO/IEC 9075-2:2023, 15.17, Checking of views that specify CHECK OPTION
//
// After an INSERT or UPDATE through a view, each row that was inserted or
// changed in the base table must be seen through every view with CHECK OPTION
// that it was changed through (the view, or a view that the view reads), or
// it's a with check option violation (44000) and the statement fails.
//
// ISO/IEC 9075-2:2023, 15.13, Effect of inserting a table into a viewed table, General Rules, 3.b.i
// ISO/IEC 9075-2:2023, 15.16, Effect of replacing some rows in a viewed table, General Rules, 3.b.i
//
// A view with CASCADED CHECK OPTION is checked with the WHERE of every view
// that it reads, so it covers every view with CHECK OPTION that it reads too.
// A view with LOCAL CHECK OPTION is checked without the WHERE of the views that
// it reads (including in a subquery), so the next view with CHECK OPTION that
// it reads is checked in its own right. There are no subviews (S081).
//
// ISO/IEC 9075-2:2023, 15.17, Checking of views that specify CHECK OPTION, General Rules, 4.b.iii.5
//
// The rows are checked by reading the view, and finding each new row by its
// id, which a row read through the view keeps (see ExprOperation.execute). This
// is the same as comparing the number of rows of the view that are new rows
// with the number of new rows.
//
// ISO/IEC 9075-2:2023, 15.17, Checking of views that specify CHECK OPTION, General Rules, 4, 4.c, 4.d, 4.e.i, 4.e.ii and 4.f
//
// Only the rows that the INSERT or UPDATE itself made are checked, not the rows
// changed by a referential action (such as ON UPDATE CASCADE) because of them.
//
// ISO/IEC 9075-2:2023, 9.17, Executing an <SQL procedure statement>, General Rules, 18

// check_view_option returns a with check option violation (44000) if a row
// (of the base table of target, after it was inserted or changed) isn't seen
// through the views with CHECK OPTION of target.
fn (mut conn Connection) check_view_option(target UpdatableView, rows []Row) ! {
	if target.checked_views.len == 0 || rows.len == 0 {
		return
	}

	mut seen := []map[string]bool{}
	for name in target.checked_views {
		view, _ := conn.find_view(name) or { break }
		seen << conn.view_row_ids(name, view)!
		if view.check_option == 'CASCADED' {
			break
		}
	}

	table := conn.catalog_for(target.table).storage.table(target.table.storage_id())
	for row in rows {
		// The id of a row of a table with a PRIMARY KEY is its key, which may
		// have been changed.
		mut new_row := row
		new_row.object_key(table)!
		for i, ids in seen {
			if new_row.id.hex() !in ids {
				return sqlstate_44000(target.checked_views[i])
			}
		}
	}
}

// view_row_ids are the ids of the rows of the view called name, see
// check_view_option.
fn (mut conn Connection) view_row_ids(name Identifier, view View) !map[string]bool {
	without_view_where := conn.without_view_where
	conn.without_view_where = view.check_option == 'LOCAL'
	defer {
		conn.without_view_where = without_view_where
	}

	mut plan := view_query_plan(mut conn, name, view.query_expression()!)!
	mut ids := map[string]bool{}
	for row in plan.execute([]Row{})! {
		ids[row.id.hex()] = true
	}

	return ids
}
