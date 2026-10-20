module vsql

// A catalog that is added during a transaction joins it, so a ROLLBACK also
// undoes the changes made to it.
fn test_catalog_added_during_transaction() ! {
	mut db := open(':memory:')!
	db.query('START TRANSACTION')!
	db.add_catalog('FOO', ':memory:', default_connection_options())!
	db.query('CREATE TABLE foo.public.bar (baz INTEGER)')!
	db.query('ROLLBACK')!

	db.query('SELECT * FROM foo.public.bar') or {
		assert err.msg() == 'no such table: FOO.PUBLIC.BAR'
		return
	}
	assert false
}
