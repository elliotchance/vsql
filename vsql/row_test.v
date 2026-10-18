module vsql

fn row_test_table(column_names ...string) Table {
	mut columns := []Column{}
	for name in column_names {
		columns << Column{Identifier{
			sub_entity_name: name
		}, Type{.is_integer, 0, 0, false}, false}
	}

	return Table{
		name:    Identifier{
			entity_name: 'T'
		}
		columns: columns
	}
}

fn test_row_with_fewer_columns_than_table() {
	old_table := row_test_table('A')
	new_table := row_test_table('A', 'B')

	row := Row{
		id:   [u8(1)]
		data: {
			'A': new_integer_value(123)
		}
	}
	read := new_row_from_bytes(new_table, row.bytes(old_table), 0)

	assert read.id == [u8(1)]
	assert read.get_int('A')! == 123
	assert read.get_null('B')!
}

fn test_row_with_more_columns_than_table() {
	old_table := row_test_table('A', 'B')
	new_table := row_test_table('A')

	row := Row{
		id:   [u8(1)]
		data: {
			'A': new_integer_value(123)
			'B': new_integer_value(456)
		}
	}
	read := new_row_from_bytes(new_table, row.bytes(old_table), 0)

	assert read.get_int('A')! == 123
	assert read.data.len == 1
}
