module vsql

// ISO/IEC 9075-2:2016(E), 7.16, <query specification>
//
// Specify a table derived from the result of a <table expression>.

struct DerivedColumn {
	expr      ValueExpression
	as_clause Identifier // will be empty if not provided
}

type SelectList = AsteriskExpr | []SelectSublist

type SelectSublist = DerivedColumn | QualifiedAsteriskExpr

type AsteriskExpr = bool

struct QualifiedAsteriskExpr {
	table_name Identifier
}

// table_expression is a reference because it can contain a subquery, which is a
// QuerySpecification, and V stores a sum type's value inline.
struct QuerySpecification {
	exprs            SelectList
	table_expression &TableExpression
	offset           ?ValueExpression
	fetch            ?ValueExpression
	// distinct is true for "SELECT DISTINCT". "SELECT ALL" is the same as no
	// <set quantifier>.
	distinct bool
}

fn (e QuerySpecification) pstr(params map[string]Value) string {
	mut s := if e.distinct { 'SELECT DISTINCT ' } else { 'SELECT ' }

	match e.exprs {
		AsteriskExpr {
			s += '*'
		}
		[]SelectSublist {
			mut items := []string{}
			for item in e.exprs {
				items << match item {
					DerivedColumn {
						if item.as_clause.sub_entity_name != '' {
							'${item.expr.pstr(params)} AS ${item.as_clause}'
						} else {
							item.expr.pstr(params)
						}
					}
					QualifiedAsteriskExpr {
						'${item.table_name}.*'
					}
				}
			}
			s += items.join(', ')
		}
	}

	return '${s} ${e.table_expression.pstr(params)}'
}

// column_reference returns the column if the select list item is only a column
// reference, such as "a" or "t.a".
fn (e DerivedColumn) column_reference() ?Identifier {
	if e.expr is BooleanValueExpression {
		f := e.expr.term.factor.expr
		if f is BooleanPredicand {
			if f is NonparenthesizedValueExpressionPrimary {
				if f is Identifier {
					return f
				}
			}
		}
	}

	return none
}

// A DistinctOperation removes the duplicate rows for "SELECT DISTINCT". Rows
// are duplicates when every value of the select list is equal, where NULLs are
// equal to each other. The first of the duplicate rows is kept, before the
// select list is applied, so that the ORDER BY can still be evaluated.
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, General Rules, 2b
struct DistinctOperation {
	params  map[string]Value
	columns Columns
	tables  map[string]Table
mut:
	conn  &Connection
	exprs []DerivedColumn
}

fn new_distinct_operation(mut conn Connection, params map[string]Value, select_list SelectList, tables map[string]Table, columns Columns) !&DistinctOperation {
	expr_operation := new_expr_operation(mut conn, params, select_list, tables)!

	// The select list is evaluated for each row here, and again for each row
	// that remains, which is only safe because NEXT VALUE FOR isn't allowed.
	//
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 2
	mut c := Compiler{
		conn:     conn
		params:   params
		tables:   tables
		distinct: true
	}
	for expr in expr_operation.exprs {
		expr.expr.compile(mut c)!
	}

	return &DistinctOperation{params, columns, tables, conn, expr_operation.exprs}
}

fn (o &DistinctOperation) str() string {
	return 'DISTINCT'
}

fn (o &DistinctOperation) columns() Columns {
	return o.columns
}

fn (mut o DistinctOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
		tables: o.tables
	}
	mut compiled := []CompileResult{}
	for expr in o.exprs {
		compiled << expr.expr.compile(mut c)!
	}

	mut kept_rows := []Row{}
	mut kept_values := [][]Value{}
	for row in rows {
		o.conn.begin_row()
		mut values := []Value{}
		for expr in compiled {
			values << expr.run(mut o.conn, row, o.params)!
		}

		mut is_duplicate := false
		for existing in kept_values {
			if is_duplicate_row(o.conn, values, existing)! {
				is_duplicate = true
				break
			}
		}

		if !is_duplicate {
			kept_rows << row
			kept_values << values
		}
	}

	return kept_rows
}

// is_duplicate_row is true if each value is equal. Unlike =, two NULLs are
// duplicates (ISO/IEC 9075-2:2016(E), 4.1.5, Properties of distinct).
fn is_duplicate_row(conn &Connection, a []Value, b []Value) !bool {
	for i, value in a {
		if value.is_null || b[i].is_null {
			if value.is_null != b[i].is_null {
				return false
			}
			continue
		}

		if compare(conn, value, b[i])! != .is_equal {
			return false
		}
	}

	return true
}

// set_distinct_columns sets the columns that a sort key can use with SELECT
// DISTINCT, which are the columns of the select list. A sort key that is also
// in the select list (such as "ORDER BY a + b" for "SELECT DISTINCT a + b") is
// replaced by that column, so it can use any column.
//
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 28d
fn (mut c Compiler) set_distinct_columns(body SimpleTable, sort_key ValueExpression) ! {
	c.distinct_columns = none
	if body !is QuerySpecification {
		return
	}

	query := body as QuerySpecification
	if !query.distinct {
		return
	}

	mut columns := []Column{}
	match query.exprs {
		AsteriskExpr {
			// Every column is in the select list.
			return
		}
		[]SelectSublist {
			for item in query.exprs {
				match item {
					DerivedColumn {
						if item.expr.pstr(c.params) == sort_key.pstr(c.params) {
							return
						}
						if column := item.column_reference() {
							columns << group_column(column, c.tables)!
						}
					}
					QualifiedAsteriskExpr {
						columns << qualified_asterisk_table(item, mut c.conn, c.tables)!.columns
					}
				}
			}
		}
	}

	c.distinct_columns = columns
}
