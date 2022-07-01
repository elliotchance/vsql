import os
import vsql
import orm
import v.ast

fn main() {
	os.rm('test.vsql') or {}
	example() or { panic(err) }
}

struct Product {
	id int [primary]
	product_name   string    [sql: 'varchar(100)']
	price f32
}

fn example() ? {
	mut db := vsql.open('test.vsql') ?

	// sql db {
	// 	create table Product
	// }
	db.create("PRODUCT", [
		orm.TableField{
			name: "id"
			typ: ast.int_type_idx
		}
		orm.TableField{
			name: "product_name"
			typ: ast.string_type_idx,
			attrs: [StructAttribute{
				name: "sql"
				arg: "varchar(100)"
			}]
		}
		orm.TableField{
			name: "price"
			typ: ast.f32_type_idx
		}
	]) ?

	products := [
		Product{
			id: 1
			product_name: 'Ice Cream'
			price: 5.99
		}
		Product{
			id: 2
			product_name: 'Ham Sandwhich'
			price: 3.47
		}
		Product{
			id: 3
			product_name: 'Bagel'
			price: 1.25
		}
	]

	for product in products {
		// sql db {
		// 	insert product into Product
		// }
		db.insert("PRODUCT", orm.QueryData{
			fields: ["id", "product_name", "price"]
			data: [
				orm.int_to_primitive(product.id)
				orm.string_to_primitive(product.product_name)
				orm.f32_to_primitive(product.price)
			]
			types: [ast.int_type_idx, ast.string_type_idx, ast.f32_type_idx]
			kinds: [.eq, .eq, .eq]
			is_and: [false, false, false]
		}) ?
	}

	// result := sql db {
	// 	select from Product where price > 2
	// }
	result := db.@select(orm.SelectConfig{
		table: 'PRODUCT'
		has_where: true
		// primary    string = 'id' // should be set if primary is different than 'id' and 'has_limit' is false
		fields:     ["ID", "PRODUCT_NAME", "PRICE"]
		types:     [ast.int_type_idx, ast.string_type_idx, ast.f32_type_idx]
	}, orm.QueryData{

	}, orm.QueryData{
		fields: ['PRICE']
		data: [orm.int_to_primitive(2)]
		types:  [ast.int_type_idx]
		kinds:  [.gt]
		is_and: [false]
	}) ?

	for row in result {
		// I guess internally the []Primitive would be mapped back to a Product
		// object? For now, we can show all the individual fields.
		println(row)
	}
}
