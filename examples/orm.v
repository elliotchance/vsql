import os
import vsql

fn main() {
	os.rm('test.vsql') or {}
	example() or { panic(err) }
}

struct Product {
	id           int    @[primary]
	product_name string @[sql_type: 'varchar(100)']
	price        f64
}

fn (p Product) str() string {
	return '${p.product_name} ($${p.price})'
}

fn example() ! {
	mut db := vsql.open_orm('test.vsql')!

	sql db {
		create table Product
	}!

	products := [
		Product{1, 'Ice Cream', 5.99},
		Product{2, 'Ham Sandwhich', 3.47},
		Product{3, 'Bagel', 1.25},
	]
	for product in products {
		sql db {
			insert product into Product
		}!
	}

	println('Products over $2:')
	for row in sql db {
		select from Product where price > 2
	}! {
		println(row)
	}
}
