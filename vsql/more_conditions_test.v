module vsql

// ISO/IEC 9075-2:2023(E), 23.1, <get diagnostics statement>, General Rules, 2.b
fn test_more_conditions() {
	mut db := open(':memory:')!
	two_warnings := "SELECT CAST('abc' AS CHAR(1)) AS a, CAST('xyz' AS CHAR(1)) AS b FROM (VALUES 1) AS t (x)"

	db.query(two_warnings)!
	assert db.warnings.len == 2
	assert !db.more_conditions

	db.clear_warnings()
	db.query('SET TRANSACTION DIAGNOSTICS SIZE 1')!
	db.query(two_warnings)!
	assert db.warnings.len == 1
	assert db.more_conditions

	db.clear_warnings()
	assert db.warnings.len == 0
	assert !db.more_conditions
}
