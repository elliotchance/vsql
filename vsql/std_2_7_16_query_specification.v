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
	// without_from is true for a query that has no <from clause>, which is a vsql
	// extension (V201-01). Its table_expression isn't used, and it reads a single
	// row that doesn't have any columns (see SingleRowOperation).
	without_from bool
}

fn new_query_specification_without_from(exprs []SelectSublist, distinct bool) QuerySpecification {
	return QuerySpecification{
		exprs:            SelectList(exprs)
		table_expression: &TableExpression{
			from_clause: TablePrimary{
				body: Identifier{}
			}
		}
		distinct:         distinct
		without_from:     true
	}
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

	if e.without_from {
		return s
	}

	return '${s} ${e.table_expression.pstr(params)}'
}

// A SingleRowOperation is the table of a query without a <from clause>. It has
// one row and no columns, so the select list is evaluated once and can't refer
// to a column of this query.
struct SingleRowOperation {}

fn (o &SingleRowOperation) str() string {
	return 'SINGLE ROW'
}

fn (o &SingleRowOperation) columns() Columns {
	return []Column{}
}

fn (mut o SingleRowOperation) execute(_ []Row) ![]Row {
	return [Row{
		data: RowData{}
	}]
}

// column_reference returns the column if the select list item is only a column
// reference, such as "a" or "t.a", so not "a OR b", "a AND b", "NOT a" or
// "a IS TRUE".
fn (e DerivedColumn) column_reference() ?Identifier {
	if e.expr is BooleanValueExpression {
		factor := e.expr.term.factor
		if e.expr.expr != none || e.expr.term.term != none || factor.value != none
			|| factor.inverse {
			return none
		}

		f := factor.expr
		if f is BooleanPredicand {
			if f is NonparenthesizedValueExpressionPrimary {
				if f is &Identifier {
					return *f
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
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, General Rules, 2.b
struct DistinctOperation {
	params  map[string]Value
	columns Columns
	tables  map[string]&Table
mut:
	conn  &Connection
	exprs []DerivedColumn
}

fn new_distinct_operation(mut conn Connection, params map[string]Value, select_list SelectList, tables map[string]&Table, columns Columns) !&DistinctOperation {
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
	mut kept_values := RowSet{}
	for row in rows {
		o.conn.begin_row()
		mut values := []Value{}
		for expr in compiled {
			values << expr.run(mut o.conn, row, o.params)!
		}

		if kept_values.find(o.conn, values)! < 0 {
			kept_rows << row
			kept_values.add(values)
		}
	}

	return kept_rows
}

// A RowSet holds rows of values, and finds the one that's a duplicate of
// another row (see is_duplicate_row) without comparing it with every row. Rows
// that could be duplicates have the same duplicate_key, so only those are
// compared.
struct RowSet {
mut:
	rows    [][]Value
	buckets map[string][]int
}

// add adds a row to the end, even if it's a duplicate of another.
fn (mut s RowSet) add(values []Value) {
	key := duplicate_key(values)
	s.buckets[key] << s.rows.len
	s.rows << values
}

// candidates returns the positions of the rows (in the order they were added)
// that could be duplicates of values. Each one must still be checked with
// is_duplicate_row.
fn (s &RowSet) candidates(values []Value) []int {
	return s.buckets[duplicate_key(values)] or { []int{} }
}

// find returns the position of the first row that's a duplicate of values, or
// -1.
fn (s &RowSet) find(conn &Connection, values []Value) !int {
	for i in s.candidates(values) {
		if is_duplicate_row(conn, s.rows[i], values)! {
			return i
		}
	}

	return -1
}

// duplicate_key is the same for any two rows that are duplicates (see
// is_duplicate_row), although rows that aren't duplicates can have the same
// key too. Numbers of any type are equal when their values are, so they use
// their approximate value. A string is equal to the same string with spaces on
// the end (the PAD SPACE characteristic, see compare_strings). Datetimes are
// compared in UTC, which depends on the session, so they all have the same key.
fn duplicate_key(values []Value) string {
	mut key := []string{cap: values.len}
	for value in values {
		if value.is_null {
			key << 'N'
		} else if value.typ.typ.is_number() {
			n := value.as_f64() or { 0 }
			// 0 and -0 are equal, but aren't the same string.
			key << if n == 0 { '0' } else { n.str() }
		} else if value.typ.typ.is_string() {
			key << unsafe { value.v.string_value }.trim_right(' ')
		} else if value.typ.typ == .is_boolean {
			key << unsafe { value.v.bool_value }.str()
		} else {
			key << ''
		}
	}

	return key.join('\x00')
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
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 28.d
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
