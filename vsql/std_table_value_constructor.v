// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>

module vsql

// Format
//~
//~ <table value constructor> /* SimpleTable */ ::=
//~     VALUES <row value expression list>   -> table_value_constructor
//~
//~ <row value expression list> /* []RowValueConstructor */ ::=
//~     <table row value expression>           -> row_value_expression_list_1
//~   | <row value expression list>
//~     <comma> <table row value expression>   -> row_value_expression_list_2
//~
//~ <contextually typed table value constructor> /* []ContextuallyTypedRowValueConstructor */ ::=
//~     VALUES <contextually typed row value expression list>   -> contextually_typed_table_value_constructor
//~
//~ <contextually typed row value expression list> /* []ContextuallyTypedRowValueConstructor */ ::=
//~     <contextually typed row value expression>                -> contextually_typed_row_value_expression_list_1
//~   | <contextually typed row value expression list> <comma>
//~     <contextually typed row value expression>                -> contextually_typed_row_value_expression_list_2

type SimpleTable = QuerySpecification | []RowValueConstructor

fn (e SimpleTable) pstr(params map[string]Value) string {
	match e {
		QuerySpecification {
			return '<subquery>'
		}
		[]RowValueConstructor {
			mut elements := []string{}
			for element in e {
				elements << element.pstr(params)
			}

			return 'VALUES ${elements.join(', ')}'
		}
	}
}

fn parse_table_value_constructor(exprs []RowValueConstructor) !SimpleTable {
	return exprs
}

fn parse_row_value_expression_list_1(expr RowValueConstructor) ![]RowValueConstructor {
	return [expr]
}

fn parse_row_value_expression_list_2(element_list []RowValueConstructor, element RowValueConstructor) ![]RowValueConstructor {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}

fn parse_contextually_typed_row_value_expression_list_1(element ContextuallyTypedRowValueConstructor) ![]ContextuallyTypedRowValueConstructor {
	return [element]
}

fn parse_contextually_typed_row_value_expression_list_2(list []ContextuallyTypedRowValueConstructor, element ContextuallyTypedRowValueConstructor) ![]ContextuallyTypedRowValueConstructor {
	mut new_list := list.clone()
	new_list << element

	return new_list
}

fn parse_contextually_typed_table_value_constructor(e []ContextuallyTypedRowValueConstructor) ![]ContextuallyTypedRowValueConstructor {
	return e
}
