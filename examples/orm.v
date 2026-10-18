import os
import vsql

struct Product {
	id    int @[primary; sql: serial]
	name  string
	price f64
}

fn main() {
	os.rm('test.vsql') or {}

	example() or { panic(err) }
}

fn example() ! {
	mut db := vsql.open('test.vsql')!

	sql db {
		create table Product
	}!

	products := [
		Product{
			name:  'Ice Cream'
			price: 5.99
		},
		Product{
			name:  'Ham Sandwhich'
			price: 3.47
		},
		Product{
			name:  'Bagel'
			price: 1.25
		},
	]
	for product in products {
		sql db {
			insert product into Product
		}!
	}

	sql db {
		update Product set price = 1.5 where name == 'Bagel'
	}!

	sql db {
		delete from Product where name == 'Ham Sandwhich'
	}!

	cheap_products := sql db {
		select from Product where price < 3.0 order by name
	}!
	for product in cheap_products {
		println('${product.id} ${product.name} \$${product.price:.2f}')
	}

	count := sql db {
		select count from Product
	}!
	println('${count} products')
}
