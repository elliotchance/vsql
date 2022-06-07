import vsql

fn main() {
	example() or { panic(err) }
}

fn example() ? {
	mut db := vsql.open(':memory:')?

	// All SQL commands use query():
	db.query('CREATE TABLE foo (x DOUBLE PRECISION)')?
	db.query('INSERT INTO foo (x) VALUES (1.23)')?
	db.query('INSERT INTO foo (x) VALUES (4.56)')?

	// Iterate through a result:
	result := db.query('SELECT * FROM foo')?
	println(result.columns)

	for row in result {
		println(row.get_f64('X')?)
	}
}
