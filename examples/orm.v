import os
import vsql
import time

fn main() {
	os.rm('test.vsql') or {}
	
	example() or { panic(err) }
}

// NOTE for some reason if we declare a @[primary] on a struct field, we can not do delete queries on the tables...
// so id is not a primary key in this example
struct Product {
	id           int //@[primary]
	product_name string @[sql_type: 'varchar(100)']
	price        f64
}

fn example() ! {
	timer := time.new_stopwatch()
	mut db := vsql.open('test.vsql')!

	sql db {
		create table Product
	}!

	products := [
		Product{1, 'Ice Cream', 5.99},
		Product{2, 'Ham Sandwhich', 3.47},
		Product{3, 'Bagel', 1.25},
	]

	// product := Product{1, 'Ice Cream', 5.99}
	for product in products {
		sql db {
			insert product into Product
		} or { panic(err) }
	}
	sql db {
		update Product set product_name = 'Cereal' where id == 1
	} or { panic(err) }

	prod_one := sql db {
		select from Product where id == 1
	}!

	assert prod_one.len == 1

	sql db {
		delete from Product where product_name == 'Cereal'
	} or { panic(err) }

	all := sql db {
		select from Product
	}!

	assert all.len == 2

	println(timer.elapsed())
	// println(typeof[?int]().idx)
	// println(typeof[int]().idx)
}
