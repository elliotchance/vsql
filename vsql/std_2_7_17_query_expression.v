module vsql

import math
import time

// ISO/IEC 9075-2:2023, 7.17, <query expression>
//
// Specify a table.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.17.3, Derived tables

struct QueryExpression {
	body   SimpleTable
	fetch  ?FetchFirstClause
	offset ?ValueSpecification
	order  []SortSpecification
	// updatability is the <updatability clause> of a <dynamic select statement>
	// (see cursor_specification), which is only used when it's opened as a
	// cursor (see PreparedStmt.open_cursor). It's always none for any other
	// query, including a subquery.
	updatability ?UpdatabilityClause
	// with_list is the <with list> of the <with clause>, if there is one. Each
	// <query name> that's read is replaced with the query that it names when
	// it's parsed (see table_or_query_name_primary), so this is only used to
	// check them (see WithListElement.check).
	with_list []WithListElement
	// with_recursive is true when the <with clause> contains RECURSIVE.
	with_recursive bool
}

// WithListElement is a <with list element>, which is a query with a name (and
// optionally names for its columns) that the rest of the <query expression> can
// read like a table.
struct WithListElement {
	// name only has a sub_entity_name, like a correlation name.
	name    Identifier
	columns []Identifier
	query   QueryExpression
	// recursive_query is only set for an element of a WITH RECURSIVE, see
	// RecursiveQuery.
	recursive_query &RecursiveQuery = unsafe { nil }
	// with_key identifies an element that isn't of a WITH RECURSIVE, see key.
	with_key &WithKey = unsafe { nil }
}

// WithKey only has an address, which identifies a <with list element> (see
// WithListElement.key).
@[heap]
struct WithKey {
	// V doesn't allocate an empty struct, so each one needs a field to have its
	// own address.
	unused bool
}

// key identifies the <with list element> in Connection.with_results. All of
// its copies have the same key.
fn (e WithListElement) key() voidptr {
	if e.recursive_query != unsafe { nil } {
		return voidptr(e.recursive_query)
	}

	return voidptr(e.with_key)
}

// WithResult is the result of the query of a <with list element>, which is the
// same each time its name is read in the <query expression> that has the
// <with clause>. It's only run the first time its name is read, each time that
// <query expression> is run (for example, for each row of a query that contains
// a subquery with a WITH), see Plan.execute.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 1.b
@[heap]
struct WithResult {
mut:
	done bool
	rows []Row
}

// A RecursiveQuery is a <with list element> of a WITH RECURSIVE. Every name of
// the <with list> is in scope in all of its queries (see start_recursive_with),
// so a query can read itself, or a query that's after it. While the <with list>
// is being parsed, it isn't known which queries are recursive, so each <query
// name> that refers to it in the <with list> is a RecursiveQueryReference, which
// all share this (see table_or_query_name_primary).
@[heap]
struct RecursiveQuery {
mut:
	name    Identifier
	columns []Identifier
	query   QueryExpression
	// parsed is true once its query has been parsed.
	parsed bool
	// reads are the queries of the same <with list> that its query reads (it
	// depends immediately on them).
	reads []&RecursiveQuery
	// stratum is the queries of the <with list> that it's strongly connected
	// with, including itself, and recursive is true when it's in a cycle (it
	// reads itself, maybe through other queries). See finish_recursive_with.
	stratum   []&RecursiveQuery
	recursive bool
}

// A RecursiveQueryReference is a <query name> that refers to a RecursiveQuery.
// from is the RecursiveQuery whose query it's in, if any. When the query it
// refers to is in the same stratum as from, it reads the rows of the previous
// iteration (see RecursiveUnionOperation). Otherwise, it reads the result of
// the RecursiveQuery.
struct RecursiveQueryReference {
	query &RecursiveQuery
	from  &RecursiveQuery = unsafe { nil }
}

// working is true when the reference reads the rows of the previous iteration
// of its query, in a query of the same stratum.
fn (r RecursiveQueryReference) working() bool {
	return r.from != unsafe { nil } && r.from.stratum.any(it == r.query)
}

// add_with_list_element adds element to list, the <with list> that's being
// parsed. Its name is in scope from now on, for the rest of the <with list> and
// the <query expression body> (until with_query_expression).
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.c and 3.i.i
fn add_with_list_element(mut yylex YYLexer, list []WithListElement, element WithListElement) ![]WithListElement {
	for other in list {
		if other.name.sub_entity_name == element.name.sub_entity_name {
			return sqlstate_42601('WITH query ${element.name.sub_entity_name} is specified more than once')
		}
	}

	mut new_element := element
	if new_element.recursive_query == unsafe { nil } {
		new_element = WithListElement{
			...element
			with_key: &WithKey{}
		}
	}

	if mut yylex is Lexer {
		if list.len == 0 {
			yylex.with_scopes << []WithListElement{}
		}
		yylex.with_scopes[yylex.with_scopes.len - 1] << new_element
	}

	mut new_list := list.clone()
	new_list << new_element

	return new_list
}

// with_query_expression is the <query expression> that has a <with clause>. The
// names of its <with list> are no longer in scope.
fn with_query_expression(mut yylex YYLexer, list []WithListElement, query QueryExpression) QueryExpression {
	if mut yylex is Lexer {
		yylex.with_scopes.pop()
	}

	return QueryExpression{
		...query
		with_list:      list
		with_recursive: list.any(it.recursive_query != unsafe { nil })
	}
}

// start_recursive_with starts the <with list> of a WITH RECURSIVE. The scope of
// each of its names is the whole <with list> (and the query after it), so
// they're found before the <with list> is parsed (see recursive_query_names). A
// WITH RECURSIVE can't be in the query of another WITH RECURSIVE. names_after
// is false for a CREATE RECURSIVE VIEW, which only has its own name.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.e, 3.g and
// 3.i.ii
fn start_recursive_with(mut yylex YYLexer, names_after bool) ! {
	if mut yylex is Lexer {
		for scope in yylex.with_scopes {
			for element in scope {
				if element.recursive_query != unsafe { nil } && !element.recursive_query.parsed {
					return sqlstate_42601('WITH RECURSIVE query ${element.name.sub_entity_name} cannot contain a WITH RECURSIVE')
				}
			}
		}
		mut scope := []WithListElement{}
		if names_after {
			for name in yylex.recursive_query_names()! {
				if scope.any(it.name.sub_entity_name == name.sub_entity_name) {
					continue
				}
				scope << WithListElement{
					name:            name
					recursive_query: &RecursiveQuery{
						name: name
					}
				}
			}
		}
		yylex.with_scopes << scope
	}
}

// recursive_query_names are the <query name>s of the <with list> after the
// WITH RECURSIVE that the parser has just read. They're found by skipping over
// the tokens of each <with list element>: a name, an optional column list in
// parentheses, AS and a query in parentheses, followed by a comma if there's
// another one. If the tokens are anything else, the names stop there, and the
// parser finds the error.
fn (l Lexer) recursive_query_names() ![]Identifier {
	// The parser may have read the token after RECURSIVE already.
	mut i := if l.tokens[l.pos - 1].token == token_recursive { l.pos } else { l.pos - 1 }

	mut names := []Identifier{}
	for i < l.tokens.len {
		name := l.tokens[i].value
		chain := match name {
			IdentifierChain { name }
			string { IdentifierChain{name} }
			Value { break }
		}
		names << new_column_identifier(chain.identifier)!
		i++
		if i < l.tokens.len && l.tokens[i].token == token_operator_left_paren {
			i = l.after_parentheses(i)
		}
		if i >= l.tokens.len || l.tokens[i].token != token_as {
			break
		}
		i++
		if i >= l.tokens.len || l.tokens[i].token != token_operator_left_paren {
			break
		}
		i = l.after_parentheses(i)
		if i >= l.tokens.len || l.tokens[i].token != token_operator_comma {
			break
		}
		i++
	}

	return names
}

// after_parentheses is the position of the token after the right parenthesis
// that matches the left parenthesis at i.
fn (l Lexer) after_parentheses(i int) int {
	mut depth := 0
	mut j := i
	for j < l.tokens.len {
		match l.tokens[j].token {
			token_operator_left_paren, token_operator_left_paren_asterisk { depth++ }
			token_operator_right_paren { depth-- }
			else {}
		}
		j++
		if depth == 0 {
			break
		}
	}

	return j
}

// add_recursive_query_name is the <query name> of a <with list element> of a
// WITH RECURSIVE, which is already in scope (see start_recursive_with). Its
// query is parsed next.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.c and 3.i.ii
fn add_recursive_query_name(mut yylex YYLexer, name Identifier) !&RecursiveQuery {
	if mut yylex is Lexer {
		for element in yylex.with_scopes[yylex.with_scopes.len - 1] {
			if element.name.sub_entity_name == name.sub_entity_name {
				if element.recursive_query.parsed {
					return sqlstate_42601('WITH query ${name.sub_entity_name} is specified more than once')
				}
				yylex.parsing_recursive_query = element.recursive_query

				return element.recursive_query
			}
		}
	}

	// A CREATE RECURSIVE VIEW isn't in scope yet.
	query := &RecursiveQuery{
		name: name
	}
	if mut yylex is Lexer {
		yylex.with_scopes[yylex.with_scopes.len - 1] << WithListElement{
			name:            name
			recursive_query: query
		}
		yylex.parsing_recursive_query = query
	}

	return query
}

// finish_recursive_with is the end of the <with list> of a WITH RECURSIVE. The
// queries that each query reads (the query name dependency graph) are known
// now, so the strata (the strongly connected queries) are found, and which
// queries are recursive.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.j.ii,
// 3.j.ii.1, 3.j.ii.2, 3.j.iii, 3.j.iv, 3.j.v and 3.j.vi
fn finish_recursive_with(list []WithListElement) {
	mut queries := list.map(it.recursive_query)

	// reaches[i][j] is true when query i depends on query j, immediately or
	// through other queries.
	mut reaches := [][]bool{len: queries.len, init: []bool{len: queries.len}}
	for i, query in queries {
		mut stack := query.reads.clone()
		for stack.len > 0 {
			next := stack.pop()
			j := queries.index(next)
			if j < 0 || reaches[i][j] {
				continue
			}
			reaches[i][j] = true
			stack << next.reads
		}
	}

	for i, mut query in queries {
		query.recursive = reaches[i][i]
		query.stratum = [query]
		for j, other in queries {
			if j != i && reaches[i][j] && reaches[j][i] {
				query.stratum << other
			}
		}
	}
}

// recursive_with_list_element finishes a <with list element> of a WITH
// RECURSIVE, which must have a <with column list>.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.j.i
fn recursive_with_list_element(mut yylex YYLexer, mut query RecursiveQuery, columns []Identifier, subquery TablePrimary) !WithListElement {
	if columns.len == 0 {
		return sqlstate_42601('WITH RECURSIVE query ${query.name.sub_entity_name} needs a column list')
	}

	query.columns = columns
	query.query = subquery.body as QueryExpression
	query.parsed = true

	if mut yylex is Lexer {
		yylex.parsing_recursive_query = unsafe { nil }
	}

	element := WithListElement{
		name:            query.name
		columns:         columns
		query:           query.query
		recursive_query: query
	}

	if mut yylex is Lexer {
		mut scope := yylex.with_scopes[yylex.with_scopes.len - 1]
		for i, other in scope {
			if other.recursive_query == query {
				yylex.with_scopes[yylex.with_scopes.len - 1][i] = element
			}
		}
	}

	return element
}

// table_or_query_name_primary is the <table primary> of a <table or query name>.
// An unqualified name that's a <query name> in scope (the innermost one) is the
// query that it names, which is read like a derived table, with the <query
// name> as its correlation name. Otherwise, it's a table.
//
// Every read of the name has the same result, see WithResult.
//
// ISO/IEC 9075-2:2023, 4.17.4, Transient tables
// ISO/IEC 9075-2:2023, 5.4, Names and identifiers, General Rules, 3
// ISO/IEC 9075-2:2023, 7.6, <table reference>, Syntax Rules, 9.a.i and 9.a.iii
// ISO/IEC 9075-2:2023, 7.6, <table reference>, General Rules, 2.a
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 1, 1.b and 1.c
fn table_or_query_name_primary(mut yylex YYLexer, name Identifier, correlation Correlation) TablePrimary {
	if mut yylex is Lexer {
		if name.catalog_name == '' && name.schema_name == '' {
			for i := yylex.with_scopes.len - 1; i >= 0; i-- {
				for element in yylex.with_scopes[i] {
					if element.name.sub_entity_name != name.entity_name {
						continue
					}

					// A query of a WITH RECURSIVE is read by its name in the queries
					// of the <with list>, and after it when it's recursive.
					if element.recursive_query != unsafe { nil } {
						mut query := element.recursive_query
						mut from := yylex.parsing_recursive_query
						if from != unsafe { nil } && !from.reads.any(it == query) {
							from.reads << query
						}
						if from != unsafe { nil } || query.recursive {
							return TablePrimary{
								body:        RecursiveQueryReference{query, from}
								with_query:  voidptr(query)
								correlation: Correlation{
									name:    if correlation.name.sub_entity_name != '' {
										correlation.name
									} else {
										element.name
									}
									columns: correlation.columns
								}
							}
						}
					}

					return TablePrimary{
						body:        element.query
						with_query:  element.key()
						correlation: Correlation{
							name:    if correlation.name.sub_entity_name != '' {
								correlation.name
							} else {
								element.name
							}
							columns: if correlation.columns.len > 0 {
								correlation.columns
							} else {
								element.columns
							}
						}
					}
				}
			}
		}
	}

	return TablePrimary{
		body:        name
		correlation: correlation
	}
}

// check checks the query of a <with list element>, even when it's not read.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3 and 3.d
fn (element WithListElement) check(params map[string]Value, mut conn Connection) ! {
	next_value_not_allowed := conn.next_value_not_allowed
	in_derived_table := conn.in_derived_table
	if next_value_not_allowed == '' {
		conn.next_value_not_allowed = 'a WITH query'
	}
	conn.in_derived_table = true
	defer {
		conn.next_value_not_allowed = next_value_not_allowed
		conn.in_derived_table = in_derived_table
	}

	plan := if element.recursive_query != unsafe { nil } && element.recursive_query.recursive {
		recursive_query_plan(element.recursive_query, params, mut conn)!
	} else {
		create_query_expression_plan(element.query, params, mut conn, Correlation{})!
	}
	columns := plan.columns()
	name := element.name.sub_entity_name

	// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.d.ii
	if element.columns.len > 0 {
		if element.columns.len != columns.len {
			return sqlstate_42601('WITH query ${name} has ${element.columns.len} columns, but its query has ${columns.len}')
		}
		for i, column in element.columns {
			if element.columns[..i].any(it.sub_entity_name == column.sub_entity_name) {
				return sqlstate_42601('column ${column.sub_entity_name} is specified more than once')
			}
		}
		return
	}

	// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.d.i
	for i, column in columns {
		if columns[..i].any(it.name.sub_entity_name == column.name.sub_entity_name) {
			return sqlstate_42601('WITH query ${name} has more than one column named ${column.name.sub_entity_name}, so it needs a column list')
		}
	}
}

fn (e QueryExpression) pstr(params map[string]Value) string {
	mut s := e.body.pstr(params)

	if e.order.len > 0 {
		mut specs := []string{}
		for spec in e.order {
			specs << spec.pstr(params)
		}
		s += ' ORDER BY ${specs.join(', ')}'
	}

	if offset := e.offset {
		s += ' OFFSET ${offset.pstr(params)} ROWS'
	}

	if fetch := e.fetch {
		s += ' ${fetch.pstr(params)}'
	}

	return s
}

// FetchFirstClause is a <fetch first clause>, or a LIMIT. count is the <fetch
// first row count>, or the <fetch first percentage> when percent is true.
// with_ties also keeps the rows after the last one that are its peers in the
// ORDER BY.
struct FetchFirstClause {
	count     ValueSpecification
	percent   bool
	with_ties bool
}

fn (e FetchFirstClause) pstr(params map[string]Value) string {
	percent := if e.percent { ' PERCENT' } else { '' }
	ending := if e.with_ties { 'WITH TIES' } else { 'ONLY' }

	return 'FETCH FIRST ${e.count.pstr(params)}${percent} ROWS ${ending}'
}

// QuerySetOperator is the UNION, EXCEPT or INTERSECT of a SetOperation.
struct QuerySetOperator {
	op  string
	all bool
}

// SetOperation is "<left> UNION <right>", "<left> EXCEPT <right>" or
// "<left> INTERSECT <right>". Each side is a reference because it can contain
// another SetOperation, and V stores a sum type's value inline.
struct SetOperation {
	left  &QueryExpression
	op    string // UNION, EXCEPT or INTERSECT
	all   bool   // DISTINCT is the default (Syntax Rule 6).
	right &QueryExpression
}

fn (e SetOperation) pstr(params map[string]Value) string {
	op := if e.all { '${e.op} ALL' } else { e.op }

	// A set operation is left associative, so one on the right must have been in
	// parentheses (or is an INTERSECT, where they don't change anything). A UNION
	// or EXCEPT on the left of an INTERSECT must have been in parentheses, since
	// INTERSECT is evaluated first.
	right := if e.right.body is SetOperation {
		'(${e.right.pstr(params)})'
	} else {
		e.right.pstr(params)
	}

	left_body := e.left.body
	left := if e.op == 'INTERSECT' && left_body is SetOperation && left_body.op != 'INTERSECT' {
		'(${e.left.pstr(params)})'
	} else {
		e.left.pstr(params)
	}

	return '${left} ${op} ${right}'
}

fn new_set_operation(left SimpleTable, op string, all bool, right SimpleTable) SimpleTable {
	return SimpleTable(SetOperation{
		left:  &QueryExpression{
			body: left
		}
		op:    op
		all:   all
		right: &QueryExpression{
			body: right
		}
	})
}

// ParenthesizedQueryExpression is a <query primary> with its own ORDER BY,
// OFFSET or FETCH FIRST, such as "(SELECT ... FETCH FIRST 1 ROW ONLY) UNION
// ...".
struct ParenthesizedQueryExpression {
	expr &QueryExpression
}

fn (e ParenthesizedQueryExpression) pstr(params map[string]Value) string {
	return '(${e.expr.pstr(params)})'
}

// new_parenthesized_query_expression returns the body of a parenthesized
// <query expression>, unless it needs to be evaluated before an outer ORDER BY,
// OFFSET or FETCH FIRST.
fn new_parenthesized_query_expression(expr QueryExpression) SimpleTable {
	if expr.order.len == 0 && expr.offset == none && expr.fetch == none {
		return expr.body
	}

	return SimpleTable(ParenthesizedQueryExpression{&QueryExpression{
		...expr
	}})
}

// writes must be true if the query modifies the database, see
// PreparedStmt.writes.
fn (stmt QueryExpression) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration, writes bool) !Result {
	t := start_timer()

	if writes {
		conn.open_write_connection()!
	} else {
		conn.open_read_connection()!
	}
	defer {
		if writes {
			conn.release_write_connection()
		} else {
			conn.release_read_connection()
		}
	}

	mut plan := create_plan(stmt, params, mut conn)!

	rows := plan.execute([]Row{})!

	return new_result(plan.columns(), rows, elapsed_parse, t.elapsed())
}

fn (stmt QueryExpression) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut plan := create_plan(stmt, params, mut conn)!

	return plan.explain(elapsed_parse)
}

struct OrderOperation {
	order   []SortSpecification
	params  map[string]Value
	columns Columns
	tables  map[string]&Table
	// result_columns is what a name in a sort key can be, see set_result_columns.
	result_columns map[string][]ValueExpression
mut:
	conn &Connection
}

fn new_order_operation(order []SortSpecification, params map[string]Value, conn &Connection, columns Columns, tables map[string]&Table, result_columns map[string][]ValueExpression) &OrderOperation {
	return &OrderOperation{order, params, columns, tables, result_columns, conn}
}

// set_result_columns sets the columns of the result that a name in an ORDER BY
// can refer to, with the expression of each one. A sort key is evaluated before
// the select list, on the row that it's calculated from, so the name is evaluated
// as that expression. More than one column can have the same name, then the name
// is ambiguous if it's used. The name of an unnamed column is
// implementation-dependent, so it doesn't hide a column of a table.
//
// Without a query specification, the sort keys are only compiled against the
// columns of the result, so the expression is just the name.
//
// ISO/IEC 9075-2:2023, 6.6, <identifier chain>, Syntax Rules, 9.a.i and 9.c
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 26
fn (mut c Compiler) set_result_columns(body SimpleTable, columns Columns) ! {
	mut exprs := columns.map(column_derived_column(Column{
		name: Identifier{
			sub_entity_name: it.name.sub_entity_name
		}
	}))
	if body is QuerySpecification {
		exprs = new_expr_operation(mut c.conn, c.params, body.exprs, c.tables)!.exprs
	}

	c.result_columns = map[string][]ValueExpression{}
	for i, column in columns {
		if !column.unnamed {
			c.result_columns[column.name.sub_entity_name] << exprs[i].expr
		}
	}
}

fn (o &OrderOperation) str() string {
	mut specs := []string{}
	for spec in o.order {
		specs << spec.pstr(o.params)
	}

	return 'ORDER BY ${specs.join(', ')}'
}

fn (o &OrderOperation) columns() Columns {
	// Ordering doesn't change the columns so just pass through from the last
	// operation.
	return o.columns
}

fn (mut o OrderOperation) execute(rows []Row) ![]Row {
	// A single row doesn't need to be sorted, so its sort keys aren't evaluated.
	if rows.len < 2 {
		return rows
	}

	// Each sort key is compiled once, and evaluated once for each row, rather
	// than for each comparison.
	mut c := Compiler{
		conn:           o.conn
		params:         o.params
		tables:         o.tables
		result_columns: o.result_columns
	}
	mut compiled := []CompileResult{cap: o.order.len}
	for spec in o.order {
		compiled << spec.expr.compile(mut c)!
	}

	mut keys := [][]Value{cap: rows.len}
	for row in rows {
		mut key := []Value{cap: compiled.len}
		for e in compiled {
			key << e.run(mut o.conn, row, o.params)!
		}
		keys << key
	}

	// A merge sort is O(n log n) and stable, so rows that are equal for every
	// sort key (peers) stay in the order they were read in. It sorts the
	// positions of the rows, so an error from a comparison is returned as soon
	// as it happens.
	mut positions := []int{len: rows.len, init: index}
	mut buffer := []int{len: rows.len}
	mut width := 1
	for width < rows.len {
		for lo := 0; lo < rows.len - width; lo += 2 * width {
			mid := lo + width
			hi := if mid + width < rows.len { mid + width } else { rows.len }
			mut i := lo
			mut j := mid
			mut k := lo
			for i < mid && j < hi {
				// Only a row that's strictly less is taken from the right half.
				if sort_keys_cmp(o.conn, keys[positions[j]], keys[positions[i]], o.order)! < 0 {
					buffer[k] = positions[j]
					j++
				} else {
					buffer[k] = positions[i]
					i++
				}
				k++
			}
			for i < mid {
				buffer[k] = positions[i]
				i++
				k++
			}
			for j < hi {
				buffer[k] = positions[j]
				j++
				k++
			}
			for x in lo .. hi {
				positions[x] = buffer[x]
			}
		}
		width *= 2
	}

	return positions.map(rows[it])
}

// sort_keys_cmp compares the values of the sort keys of two rows.
fn sort_keys_cmp(conn &Connection, left []Value, right []Value, specs []SortSpecification) !int {
	// Each sort key is compared in turn, and the first one that isn't equal
	// decides the order of the two rows. The values are compared like a
	// <comparison predicate> with < (or > for DESC). Two null values are equal,
	// and a null value is before every other value for NULLS FIRST, or after
	// them for NULLS LAST, whichever the direction is. The implementation-defined
	// default <null ordering> is NULLS FIRST for ASC and NULLS LAST for DESC
	// (see new_sort_specification). Rows that are equal for every sort key
	// (peers) are in an implementation-dependent order, which is the order they
	// were read in since the merge sort in OrderOperation.execute is stable.
	//
	// ISO/IEC 9075-2:2023, 10.10, <sort specification list>, Syntax Rules, 2 and 3
	// ISO/IEC 9075-2:2023, 10.10, <sort specification list>, General Rules, 1
	for i, spec in specs {
		if left[i].is_null && right[i].is_null {
			continue
		}

		if left[i].is_null && !right[i].is_null {
			return if spec.nulls_first { -1 } else { 1 }
		}

		if !left[i].is_null && right[i].is_null {
			return if spec.nulls_first { 1 } else { -1 }
		}

		cmp := compare(conn, left[i], right[i])!
		if cmp == .is_equal {
			continue
		}

		if cmp == .is_less {
			return if spec.is_asc { -1 } else { 1 }
		}

		return if spec.is_asc { 1 } else { -1 }
	}

	return 0
}

// A LimitOperation stops after a specified number of rows have been received.
// It is also used for OFFSET clauses.
struct LimitOperation {
	fetch   ?FetchFirstClause
	offset  ?ValueSpecification
	params  map[string]Value
	columns Columns
mut:
	conn &Connection
	// order, tables and result_columns are what's needed to evaluate the sort
	// keys of a row (see OrderOperation), to find the peers for WITH TIES.
	order          []SortSpecification
	tables         map[string]&Table
	result_columns map[string][]ValueExpression
}

fn new_limit_operation(fetch ?FetchFirstClause, offset ?ValueSpecification, params map[string]Value, mut conn Connection, columns Columns) &LimitOperation {
	return &LimitOperation{
		fetch:   fetch
		offset:  offset
		params:  params
		columns: columns
		conn:    conn
	}
}

fn (o &LimitOperation) str() string {
	mut s := ''

	if offset := o.offset {
		s = 'OFFSET ${offset.pstr(o.params)} ROWS'
	}

	if fetch := o.fetch {
		s += ' ${fetch.pstr(o.params)}'
	}

	return s.trim_space()
}

fn (o &LimitOperation) columns() Columns {
	// Limit doesn't change the columns so just pass through from the last
	// operation.
	return o.columns
}

fn (mut o LimitOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
	}
	mut offset := i64(0)
	if off := o.offset {
		offset = row_count('OFFSET', off.compile(mut c)!.run(mut o.conn, Row{}, o.params)!)!

		// General Rule 6b: The offset must not be negative.
		if offset < 0 {
			return sqlstate_2201x()
		}

		if offset >= rows.len {
			return []Row{}
		}
	}

	// The percentage is of all the rows, before any are skipped by OFFSET
	// (General Rules, 7.b.ii).
	mut fetch := i64(rows.len)
	if f := o.fetch {
		value := f.count.compile(mut c)!.run(mut o.conn, Row{}, o.params)!
		fetch = if f.percent {
			fetch_percentage(value, rows.len)!
		} else {
			row_count('FETCH FIRST', value)!
		}

		// General Rule 7c: At least one row must be fetched.
		if fetch < 1 {
			return sqlstate_2201w()
		}
	}

	if fetch >= rows.len - offset {
		fetch = rows.len - offset
	}

	mut end := int(offset + fetch)
	if f := o.fetch {
		if f.with_ties && end < rows.len {
			end = o.end_of_peers(rows, end)!
		}
	}

	return rows[offset..end]
}

// end_of_peers returns where the rows that are peers of the last fetched row
// (the one before end) end. The rows are already in the order of the ORDER BY,
// so the peers are the rows straight after it that have the same value for
// every sort key.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 7.d.i
fn (mut o LimitOperation) end_of_peers(rows []Row, end int) !int {
	mut c := Compiler{
		conn:           o.conn
		params:         o.params
		tables:         o.tables
		result_columns: o.result_columns
	}
	mut compiled := []CompileResult{cap: o.order.len}
	for spec in o.order {
		compiled << spec.expr.compile(mut c)!
	}

	last := o.sort_key(compiled, rows[end - 1])!
	mut i := end
	for i < rows.len {
		if sort_keys_cmp(o.conn, o.sort_key(compiled, rows[i])!, last, o.order)! != 0 {
			break
		}
		i++
	}

	return i
}

fn (mut o LimitOperation) sort_key(compiled []CompileResult, row Row) ![]Value {
	mut key := []Value{cap: compiled.len}
	for e in compiled {
		key << e.run(mut o.conn, row, o.params)!
	}

	return key
}

// row_count returns the value of an <offset row count> or <fetch first row
// count>. Syntax Rules 29 and 30 require both to be an exact numeric with scale
// 0.
fn row_count(clause string, value Value) !i64 {
	return exact_integer('${clause} row count', value)
}

// fetch_percentage returns the number of rows for a <fetch first percentage>,
// which is the percentage of total rows, rounded up. It's at most total, so
// that a percentage over 100 doesn't overflow, and it's 0 (an exception for the
// caller) when it's less than 1, including when there are no rows at all.
//
// The product of an exact numeric percentage and the number of rows is exact,
// so that a percentage like 0.07 of 10000 rows is 7 rows, not 8.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 29
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 7.b.ii
fn fetch_percentage(value Value, total int) !i64 {
	product := match value.typ.typ {
		.is_smallint, .is_integer, .is_bigint, .is_numeric, .is_decimal {
			value.as_numeric()!.multiply(new_numeric_from_string(total.str())).f64()
		}
		.is_real, .is_double_precision {
			value.as_f64()! * total
		}
		else {
			return sqlstate_42601('FETCH FIRST percentage must be numeric, got ${value.typ}')
		}
	}

	return i64(math.min(math.max(math.ceil(product / 100.0), 0), total))
}

// exact_integer returns the value, which must be an exact numeric with scale 0
// (what is the name of the value for the error).
fn exact_integer(what string, value Value) !i64 {
	is_valid := match value.typ.typ {
		.is_smallint, .is_integer, .is_bigint {
			true
		}
		.is_numeric, .is_decimal {
			value.typ.scale == 0
		}
		else {
			false
		}
	}

	if !is_valid {
		return sqlstate_42601('${what} must be an exact numeric with scale 0, got ${value.typ}')
	}

	return value.as_int()
}

// A SetOperationOperation combines the rows of two queries for UNION, EXCEPT or
// INTERSECT. Each column has the combined type of that column in both queries
// (9.5), and the name of that column in the left query.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 16.b, 18 and 19.b
struct SetOperationOperation {
	op      string
	all     bool
	columns Columns
mut:
	conn  &Connection
	left  Plan
	right Plan
}

fn new_set_operation_operation(op SetOperation, left Plan, right Plan, mut conn Connection) !&SetOperationOperation {
	left_columns := left.columns()
	right_columns := right.columns()
	if left_columns.len != right_columns.len {
		return sqlstate_42601('each ${op.op} query must have the same number of columns')
	}

	mut columns := []Column{}
	for i, column in left_columns {
		typ := combine_types(column.typ, right_columns[i].typ) or {
			return sqlstate_42804('in column ${i + 1} of ${op.op}', column.typ.str(),
				right_columns[i].typ.str())
		}
		// UNION ALL keeps every row, but any other set operation is a grouping
		// operation (9.12, Syntax Rules, 1.e-1.g).
		if op.op != 'UNION' || !op.all {
			check_grouping_operand(typ, 'column ${i + 1} of ${op.op}')!
		}
		// A column of "SELECT *" is named by the column it refers to, such as
		// T.A, but the result only has the column name (and the key of a
		// duplicate name, see new_expr_operation), which is what each row of the
		// result is read with (#716). The name is always the name of the left
		// column, so it's unnamed when that is.
		columns << Column{
			name:      Identifier{
				custom_id:       column.name.custom_id
				sub_entity_name: column.name.sub_entity_name
			}
			typ:       typ
			unnamed:   column.unnamed
			recursive: column.recursive || right_columns[i].recursive
		}
	}

	return &SetOperationOperation{op.op, op.all, columns, conn, left, right}
}

fn (o &SetOperationOperation) str() string {
	quantifier := if o.all { 'ALL' } else { 'DISTINCT' }

	return '${o.op} ${quantifier} (${o.columns})'
}

fn (o &SetOperationOperation) columns() Columns {
	return o.columns
}

// execute combines the rows of both sides. A row R that appears m times on the
// left and n times on the right appears in the result:
//
//   UNION ALL:       m + n times
//   UNION DISTINCT:  once, if m > 0 or n > 0
//   EXCEPT ALL:      max(m - n, 0) times
//   EXCEPT DISTINCT: once, if m > 0 and n = 0
//   INTERSECT ALL:      min(m, n) times
//   INTERSECT DISTINCT: once, if m > 0 and n > 0
//
// Rows are duplicates when every value is equal, where NULLs are equal to each
// other (4.1.5).
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 3.b
fn (mut o SetOperationOperation) execute(_ []Row) ![]Row {
	left := o.values(o.left.execute([]Row{})!, o.left.columns())!
	right := o.values(o.right.execute([]Row{})!, o.right.columns())!

	mut kept := RowSet{}
	if o.op == 'UNION' {
		for values in left {
			if o.all || kept.find(o.conn, values)! < 0 {
				kept.add(values)
			}
		}
		for values in right {
			if o.all || kept.find(o.conn, values)! < 0 {
				kept.add(values)
			}
		}
	} else {
		// Each left row is matched with a duplicate on the right. For ALL, each
		// row on the right can only be matched once, so it removes one duplicate
		// from the left for EXCEPT, or keeps one for INTERSECT. Otherwise, it
		// removes (or keeps) every duplicate, and only the first one is kept.
		mut right_rows := RowSet{}
		for values in right {
			right_rows.add(values)
		}
		mut matched := []bool{len: right.len}
		for values in left {
			if !o.all && kept.find(o.conn, values)! >= 0 {
				continue
			}

			mut is_matched := false
			for j in right_rows.candidates(values) {
				if !matched[j] && is_duplicate_row(o.conn, values, right[j])! {
					matched[j] = o.all
					is_matched = true
					break
				}
			}

			if is_matched == (o.op == 'INTERSECT') {
				kept.add(values)
			}
		}
	}

	mut rows := []Row{}
	for values in kept.rows {
		mut data := map[string]Value{}
		for i, column in o.columns {
			data[column.name.id()] = values[i]
		}
		rows << new_row(data)
	}

	return rows
}

// values returns the values of each row, cast to the type of each column of the
// result.
fn (mut o SetOperationOperation) values(rows []Row, columns Columns) ![][]Value {
	mut all_values := [][]Value{}
	for row in rows {
		mut values := []Value{}
		for i, column in columns {
			values << convert_to_combined_type(mut o.conn, 'in ${o.op}', row.get_column(column)!,
				o.columns[i].typ)!
		}
		all_values << values
	}

	return all_values
}

// RecursiveQueryState is a RecursiveQuery whose own query is being planned or
// run. Its query must be a UNION, and only one side (the recursive query) can
// read it. While the other side (the anchor) is planned, anchor is true, and
// anchor_read is set if it reads it. depth is how many subqueries the query is
// in, so that a subquery inside it can't read it either.
struct RecursiveQueryState {
mut:
	anchor      bool
	anchor_read bool
	depth       int
	columns     Columns
	// rows are the rows of the previous iteration (see RecursiveUnionOperation).
	rows []Row
}

// recursive_query_plan is the plan of a RecursiveQuery that reads itself. The
// reads in its own query don't count as reads of the query that reads it (see
// Connection.recursive_reads).
fn recursive_query_plan(query &RecursiveQuery, params map[string]Value, mut conn Connection) !Plan {
	recursive_reads := conn.recursive_reads
	conn.recursive_query = query
	defer {
		conn.recursive_query = unsafe { nil }
		conn.recursive_reads = recursive_reads
	}

	// The query of the stratum is planned by create_recursive_union_plan. When it
	// isn't a UNION, the result isn't a query specification either, which would
	// have its select list applied again.
	mut stmt := query.query
	if stmt.body is QuerySpecification {
		stmt = QueryExpression{
			...stmt
			body: ParenthesizedQueryExpression{&QueryExpression{
				body: stmt.body
			}}
		}
	}

	return create_query_expression_plan(stmt, params, mut conn, Correlation{})
}

// working_table_plan reads the rows of the previous iteration of a
// RecursiveQuery, in its own query. A subquery can only read it in FROM.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.j.ix.5.A and
// 3.j.ix.5.B
fn working_table_plan(query &RecursiveQuery, mut conn Connection) !Plan {
	name := query.name.sub_entity_name
	mut state := conn.recursive_queries[voidptr(query)] or {
		return sqlstate_xx000('WITH RECURSIVE query ${name} is not being planned')
	}
	if state.anchor {
		state.anchor_read = true
		conn.recursive_queries[voidptr(query)] = state
	}
	if conn.subquery_scopes.len > state.depth {
		return sqlstate_42601('WITH RECURSIVE query ${name} cannot be read in a subquery of its own query, other than in FROM')
	}
	conn.recursive_reads++

	return Plan{
		operations: [&WorkingTableOperation{voidptr(query), state.columns, conn}]
	}
}

// create_recursive_union_plan is the plan of a RecursiveQuery that reads
// itself, which is planned with the other queries of its stratum (the queries
// that it reads, which read it). Each cycle of the stratum must have a query
// that's a UNION of a query (the anchor) that doesn't read the stratum and one
// that does. The other queries of the stratum don't need to be a UNION. A
// recursively derived column has the type of the anchor, and any other column
// has the type of both sides combined.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 3.j.vii,
// 3.j.vii.1, 3.j.vii.1.A, 3.j.vii.1.B, 3.j.vii.2 and 3.j.viii
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 19.b.ii.2,
// 19.b.ii.2.B, 19.b.ii.2.C.I, 19.b.ii.2.C.II.1 and 19.b.ii.2.C.II.2
fn create_recursive_union_plan(query &RecursiveQuery, params map[string]Value, mut conn Connection) !Plan {
	stratum := query.stratum
	defer {
		for member in stratum {
			conn.recursive_queries.delete(voidptr(member))
		}
	}

	// The anchor of each query that's a UNION is the side that doesn't read the
	// stratum, which is usually the left. Until the anchor is planned, the
	// columns aren't known, so planning the other side may fail.
	mut members := []RecursiveMember{}
	mut recursive_sides := []QueryExpression{}
	for member in stratum {
		body := member.query.body
		mut recursive_side := member.query
		mut anchor := Plan{}
		mut has_anchor := false
		mut all := match body {
			SetOperation { body.all }
			QuerySpecification { !body.distinct }
			else { true }
		}
		if body is SetOperation && body.op == 'UNION' {
			anchor, has_anchor = plan_recursive_anchor(stratum, *body.left, params, mut
				conn)!
			if has_anchor {
				recursive_side = *body.right
			} else {
				anchor, has_anchor = plan_recursive_anchor(stratum, *body.right, params, mut
					conn)!
				if has_anchor {
					recursive_side = *body.left
				}
			}
		}
		members << RecursiveMember{
			key:        voidptr(member)
			all:        all
			has_anchor: has_anchor
			anchor:     anchor
		}
		recursive_sides << recursive_side
	}

	// Every cycle has an anchor when the queries that aren't anchors don't make
	// a cycle by themselves. They're planned in the order that they read each
	// other, after the anchors.
	mut order := []int{}
	mut visiting := []bool{len: stratum.len}
	for i in 0 .. stratum.len {
		if !members[i].has_anchor {
			if !recursive_order(stratum, members, i, mut visiting, mut order) {
				return recursive_anchor_error(stratum)
			}
		}
	}

	// The columns of the working tables are recursive (see Column.recursive).
	for i, mut member in members {
		if member.has_anchor {
			member.columns = working_columns(stratum[i], member.anchor.columns())!
		}
	}
	for i in order {
		members[i].recursive = plan_recursive_member(members, recursive_sides[i], params, mut
			conn)!
		members[i].columns = working_columns(stratum[i], members[i].recursive.columns())!
	}
	changed := plan_recursive_sides(stratum, mut members, recursive_sides, params, mut
		conn)!
	if changed {
		for i in order {
			members[i].recursive = plan_recursive_member(members, recursive_sides[i], params, mut
				conn)!
			members[i].columns = working_columns(stratum[i], members[i].recursive.columns())!
		}
		plan_recursive_sides(stratum, mut members, recursive_sides, params, mut conn)!
	}

	// The result isn't recursive outside of its own query.
	for mut member in members {
		member.columns = member.columns.map(Column{
			...it
			recursive: false
		})
	}

	mut plan := Plan{}
	mut n := 1
	for member in members {
		if member.has_anchor {
			plan.subplans['\$${n}'] = member.anchor
			n++
		}
		plan.subplans['\$${n}'] = member.recursive
		n++
	}
	plan.operations << &RecursiveUnionOperation{members, 0, conn}

	return plan
}

// RecursiveMember is a query of a recursive stratum (by its key). When it's an
// anchor expression (has_anchor), anchor is the side of its UNION that doesn't
// read the stratum, and recursive is the other side. Otherwise, recursive is
// its whole query. all is false when the rows that are already in its result
// aren't added again. columns are the columns of its result.
struct RecursiveMember {
	key        voidptr
	all        bool
	has_anchor bool
mut:
	columns   Columns
	anchor    Plan
	recursive Plan
}

// recursive_order adds query i of stratum, which isn't an anchor expression, to
// order, after the other queries that aren't anchor expressions that it reads.
// It returns false if they read each other in a cycle.
fn recursive_order(stratum []&RecursiveQuery, members []RecursiveMember, i int, mut visiting []bool, mut order []int) bool {
	if i in order {
		return true
	}
	if visiting[i] {
		return false
	}
	visiting[i] = true
	for read in stratum[i].reads {
		j := stratum.index(read)
		if j >= 0 && !members[j].has_anchor
			&& !recursive_order(stratum, members, j, mut visiting, mut order) {
			return false
		}
	}
	visiting[i] = false
	order << i

	return true
}

fn recursive_anchor_error(stratum []&RecursiveQuery) IError {
	if stratum.len == 1 {
		name := stratum[0].name.sub_entity_name
		return sqlstate_42601('WITH RECURSIVE query ${name} must be a UNION of a query that does not read ${name} and one that does')
	}
	names := stratum.map(it.name.sub_entity_name).join(', ')

	return sqlstate_42601('WITH RECURSIVE queries ${names} read each other, so one of them must be a UNION of a query that does not read them and one that does')
}

// working_columns are the columns of the working table of query, which has
// the types of columns.
fn working_columns(query &RecursiveQuery, columns Columns) !Columns {
	if columns.len != query.columns.len {
		return sqlstate_42601('WITH query ${query.name.sub_entity_name} has ${query.columns.len} columns, but its query has ${columns.len}')
	}

	mut working := []Column{}
	for i, column in columns {
		working << Column{
			name:      Identifier{
				sub_entity_name: query.columns[i].sub_entity_name
			}
			typ:       column.typ
			recursive: true
		}
	}

	return working
}

// plan_recursive_sides plans the side of each UNION of the stratum that reads
// it, and gives each column of the anchor expression that isn't recursively
// derived the type of both sides combined. It returns true if that changed the
// type of a column of a working table, so it must be planned again.
fn plan_recursive_sides(stratum []&RecursiveQuery, mut members []RecursiveMember, recursive_sides []QueryExpression, params map[string]Value, mut conn Connection) !bool {
	mut changed := false
	for i in 0 .. members.len {
		if !members[i].has_anchor {
			continue
		}
		before := conn.recursive_reads
		recursive := plan_recursive_member(members, recursive_sides[i], params, mut
			conn)!
		if conn.recursive_reads == before {
			return recursive_anchor_error(stratum)
		}
		recursive_columns := recursive.columns()
		mut columns := members[i].columns.clone()
		if recursive_columns.len != columns.len {
			return sqlstate_42601('each UNION query must have the same number of columns')
		}

		// The type of a column that isn't recursively derived doesn't depend on
		// the types of the working tables, so it's known now.
		anchor_columns := members[i].anchor.columns()
		for j, column in columns {
			typ := combine_types(column.typ, recursive_columns[j].typ) or {
				return sqlstate_42804('in column ${j + 1} of UNION', column.typ.str(),
					recursive_columns[j].typ.str())
			}
			if !recursive_columns[j].recursive {
				not_null := anchor_columns[j].not_null || recursive_columns[j].not_null
				changed = changed || typ != column.typ || not_null != column.not_null
				columns[j] = Column{
					...column
					typ:      typ
					not_null: not_null
				}
			}
			if !members[i].all {
				check_grouping_operand(columns[j].typ, 'column ${j + 1} of UNION')!
			}
		}
		members[i].recursive = recursive
		members[i].columns = columns
	}

	return changed
}

// plan_recursive_member plans side, the query of a member (or the side of its
// UNION) that reads the working tables, which have the columns of members (when
// they're known).
fn plan_recursive_member(members []RecursiveMember, side QueryExpression, params map[string]Value, mut conn Connection) !Plan {
	for member in members {
		if member.columns.len > 0 {
			conn.recursive_queries[member.key] = RecursiveQueryState{
				depth:   conn.subquery_scopes.len
				columns: member.columns
			}
		} else {
			conn.recursive_queries.delete(member.key)
		}
	}

	return create_query_expression_plan(side, params, mut conn, Correlation{})
}

// plan_recursive_anchor plans side of a UNION of a query of stratum as its
// anchor. It returns false if side reads the stratum, so it's not the anchor.
fn plan_recursive_anchor(stratum []&RecursiveQuery, side QueryExpression, params map[string]Value, mut conn Connection) !(Plan, bool) {
	for member in stratum {
		conn.recursive_queries[voidptr(member)] = RecursiveQueryState{
			anchor: true
			depth:  conn.subquery_scopes.len
		}
	}
	plan := create_query_expression_plan(side, params, mut conn, Correlation{}) or {
		if stratum_anchor_read(stratum, conn) {
			return Plan{}, false
		}
		return err
	}

	return plan, !stratum_anchor_read(stratum, conn)
}

// stratum_anchor_read is true if a query of stratum was read while the side of
// a UNION was planned as an anchor (see plan_recursive_anchor).
fn stratum_anchor_read(stratum []&RecursiveQuery, conn &Connection) bool {
	for member in stratum {
		if (conn.recursive_queries[voidptr(member)] or { RecursiveQueryState{} }).anchor_read {
			return true
		}
	}

	return false
}

// A WorkingTableOperation reads the rows of the previous iteration of a
// RecursiveQuery (see RecursiveUnionOperation), in its own query.
struct WorkingTableOperation {
	key     voidptr
	columns Columns
mut:
	conn &Connection
}

fn (o &WorkingTableOperation) str() string {
	return 'WORKING TABLE (${o.columns})'
}

fn (o &WorkingTableOperation) columns() Columns {
	return o.columns
}

fn (mut o WorkingTableOperation) execute(_ []Row) ![]Row {
	state := o.conn.recursive_queries[o.key] or { return []Row{} }

	return state.rows
}

// A RecursiveUnionOperation is the result of a RecursiveQuery that reads
// itself, which is query target of the members of its stratum. The rows of each
// anchor are the first iteration of its query. Each iteration after that is the
// rows of the side of each query that reads the working tables, when they're the
// rows of the iteration before it, without the rows that are already in its
// result for UNION DISTINCT (or a query that's DISTINCT). It stops when an
// iteration has no rows. The result is the rows of every iteration.
//
// The standard reads the whole result in each iteration until it stops
// growing, but since each query must be linearly recursive and can't remove
// any rows that it reads, both give the same result.
//
// ISO/IEC 9075-2:2023, 4.17.4, Transient tables
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 2, 2.a, 2.b,
// 2.c, 2.c.i, 2.c.ii, 2.c.ii.1, 2.c.ii.2, 2.c.ii.3, 2.c.ii.4, 2.c.ii.4.A,
// 2.c.ii.4.B and 2.c.ii.5
struct RecursiveUnionOperation {
mut:
	members []RecursiveMember
	target  int
	conn    &Connection
}

fn (o &RecursiveUnionOperation) str() string {
	member := o.members[o.target]
	quantifier := if member.all { 'ALL' } else { 'DISTINCT' }

	return 'RECURSIVE UNION ${quantifier} (${member.columns})'
}

fn (o &RecursiveUnionOperation) columns() Columns {
	return o.members[o.target].columns
}

fn (mut o RecursiveUnionOperation) execute(_ []Row) ![]Row {
	mut previous := map[voidptr]RecursiveQueryState{}
	for member in o.members {
		if state := o.conn.recursive_queries[member.key] {
			previous[member.key] = state
		}
	}
	defer {
		for member in o.members {
			if state := previous[member.key] {
				o.conn.recursive_queries[member.key] = state
			} else {
				o.conn.recursive_queries.delete(member.key)
			}
		}
	}

	mut kept := []RowSet{len: o.members.len}
	mut iterations := [][]Row{len: o.members.len}
	for i, mut member in o.members {
		if member.has_anchor {
			iterations[i] = o.add_rows(i, mut kept[i], member.anchor.execute([]Row{})!,
				member.anchor.columns())!
		}
	}
	for iterations.any(it.len > 0) {
		for i, member in o.members {
			o.conn.recursive_queries[member.key] = RecursiveQueryState{
				depth:   o.conn.subquery_scopes.len
				columns: member.columns
				rows:    iterations[i]
			}
		}
		for i, mut member in o.members {
			iterations[i] = o.add_rows(i, mut kept[i], member.recursive.execute([]Row{})!,
				member.recursive.columns())!
		}
	}

	return o.rows(o.target, kept[o.target].rows)
}

// add_rows adds each of rows (which have columns) to kept, the result of member
// i, unless it's already there for UNION DISTINCT. It returns the rows that were
// added.
fn (mut o RecursiveUnionOperation) add_rows(i int, mut kept RowSet, rows []Row, columns Columns) ![]Row {
	member := o.members[i]
	mut added := [][]Value{}
	for row in rows {
		mut values := []Value{}
		for j, column in columns {
			values << convert_to_combined_type(mut o.conn, 'in UNION', row.get_column(column)!,
				member.columns[j].typ)!
		}
		if member.all || kept.find(o.conn, values)! < 0 {
			kept.add(values)
			added << values
		}
	}

	return o.rows(i, added)
}

fn (o &RecursiveUnionOperation) rows(i int, all_values [][]Value) []Row {
	mut rows := []Row{}
	for values in all_values {
		mut data := map[string]Value{}
		for j, column in o.members[i].columns {
			data[column.name.id()] = values[j]
		}
		rows << new_row(data)
	}

	return rows
}
