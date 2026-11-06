// key_range.v uses the PRIMARY KEY to read only the rows of a table that the
// WHERE clause can be true for.

module vsql

// A KeyCondition is a condition of the WHERE clause that compares a column of
// the PRIMARY KEY with a value that's the same for every row, such as "id >= 10"
// (or "10 <= id"). The conditions only narrow down the rows that are read, the
// whole WHERE clause is still applied to each of them.
struct KeyCondition {
	// column is the position of the column in the PRIMARY KEY.
	column int
	// op is how the column compares with the value, it's never not_equal.
	op    ComparisonOperator
	value CompileResult
	// text is how the condition is shown by EXPLAIN.
	text string
}

// primary_key_conditions are the conditions of the WHERE clause that the
// PRIMARY KEY can be used for. They are only found when the WHERE clause is
// one or more conditions joined by AND, since any row can be true for an OR.
// There are none unless one is for the first column of the PRIMARY KEY, since
// the rows are in the order of that column first.
//
// base_table is the stored table and table is how the query names it, which is
// different with a correlation name, such as "t AS x (a, b)".
fn primary_key_conditions(body QuerySpecification, base_table Table, table Table, params map[string]Value, mut conn Connection) []KeyCondition {
	if base_table.primary_key.len == 0 {
		return []
	}

	where := body.table_expression.where_clause or { return [] }
	if _ := where.expr {
		return []
	}

	// The last part of an AND is first.
	mut factors := []BooleanTest{}
	mut term := where.term
	for {
		factors.prepend(term.factor)
		next := term.term or { break }
		term = *next
	}

	mut conditions := []KeyCondition{}
	for factor in factors {
		conditions << key_conditions(factor, base_table, table, params, mut conn)
	}

	if !conditions.any(it.column == 0) {
		return []
	}

	return conditions
}

// key_conditions are the conditions of one part of an AND. BETWEEN is the same
// as two conditions.
fn key_conditions(test BooleanTest, base_table Table, table Table, params map[string]Value, mut conn Connection) []KeyCondition {
	if _ := test.value {
		return []
	}
	if test.inverse {
		return []
	}

	primary := *test.expr
	predicate := match primary {
		Predicate { primary }
		else { return [] }
	}

	mut conditions := []KeyCondition{}
	match predicate {
		ComparisonPredicate {
			if predicate.op != .not_equal {
				if condition := key_condition(predicate.left, predicate.op, predicate.right,
					base_table, table, params, mut conn)
				{
					conditions << condition
				} else if condition := key_condition(predicate.right, predicate.op.reverse(),
					predicate.left, base_table, table, params, mut conn)
				{
					conditions << condition
				}
			}
		}
		BetweenPredicate {
			if !predicate.not && !predicate.symmetric {
				if condition := key_condition(predicate.expr, .greater_than_or_equal,
					predicate.left, base_table, table, params, mut conn)
				{
					conditions << condition
				}
				if condition := key_condition(predicate.expr, .less_than_or_equal, predicate.right,
					base_table, table, params, mut conn)
				{
					conditions << condition
				}
			}
		}
		else {}
	}

	return conditions
}

// key_condition is "column op value", if column is a column of the PRIMARY KEY
// and value doesn't depend on the row. The value can be any expression that
// doesn't refer to a column (including an outer reference), such as a literal,
// a parameter or "1 + 2". The types must be comparable, otherwise the WHERE
// clause has to raise the error, even if no rows would be read.
fn key_condition(column_side RowValueConstructorPredicand, op ComparisonOperator, value_side RowValueConstructorPredicand, base_table Table, table Table, params map[string]Value, mut conn Connection) ?KeyCondition {
	column := new_column_identifier(column_side.pstr(params)) or { return none }
	if column.custom_id != '' || !column.is_column_of_table(conn, table) {
		return none
	}

	// The columns of table are the columns of base_table, in the same order.
	mut key_column := -1
	mut column_type := Type{}
	for i, name in base_table.primary_key {
		for j, c in base_table.columns {
			if c.name.sub_entity_name == name
				&& table.columns[j].name.sub_entity_name == column.sub_entity_name {
				key_column = i
				column_type = c.typ
			}
		}
	}
	if key_column < 0 {
		return none
	}

	// Without the scopes of the queries that contain this one, a column of
	// another query is an unknown column rather than an outer reference.
	subquery_scopes := conn.subquery_scopes
	subquery_tables := conn.subquery_tables.clone()
	conn.subquery_scopes = []
	defer {
		conn.subquery_scopes = subquery_scopes
		conn.subquery_tables = subquery_tables
	}

	// A table with no columns makes any column an unknown column, rather than
	// one that's only looked up in the row when it's evaluated.
	mut c := Compiler{
		conn:                   conn
		params:                 params
		tables:                 {
			'': Table{}
		}
		next_value_not_allowed: 'WHERE'
	}
	value := value_side.compile(mut c) or { return none }
	if value.contains_agg || !is_key_comparable(column_type.typ, value.typ.typ) {
		return none
	}

	return KeyCondition{key_column, op, value, '${column_side.pstr(params)} ${op} ${value_side.pstr(params)}'}
}

// is_key_comparable is true when a value of type b can be compared with a
// column of type a (see compare).
fn is_key_comparable(a SQLType, b SQLType) bool {
	if a.is_datetime() && b.is_datetime() {
		return datetime_fields(a) == datetime_fields(b)
	}

	return comparable_types(a, b)
}

// reverse is the operator when the sides are swapped, so that "10 < id" is
// "id > 10".
fn (op ComparisonOperator) reverse() ComparisonOperator {
	return match op {
		.less_than { .greater_than }
		.greater_than { .less_than }
		.less_than_or_equal { .greater_than_or_equal }
		.greater_than_or_equal { .less_than_or_equal }
		else { op }
	}
}

// A PrimaryKeyOperation reads the rows of a table that are in the range of the
// PRIMARY KEY that the conditions allow.
struct PrimaryKeyOperation {
	table      Table
	conditions []KeyCondition
	params     map[string]Value
mut:
	conn &Connection
}

fn new_primary_key_operation(table Table, conditions []KeyCondition, params map[string]Value, conn &Connection) &PrimaryKeyOperation {
	return &PrimaryKeyOperation{table, conditions, params, conn}
}

fn (o &PrimaryKeyOperation) str() string {
	return 'PRIMARY KEY ${o.table.name} (${o.pretty_columns()}) RANGE ${o.conditions.map(it.text).join(' AND ')}'
}

// We could just render columns(), however, it makes the output extra verbose,
// so we only show the column names.
fn (o &PrimaryKeyOperation) pretty_columns() Columns {
	mut cols := []Column{}
	for c in o.table.columns {
		cols << Column{
			name:     Identifier{
				sub_entity_name: c.name.sub_entity_name
			}
			typ:      c.typ
			not_null: c.not_null
		}
	}

	return cols
}

fn (o &PrimaryKeyOperation) columns() Columns {
	mut columns := []Column{}

	for column in o.table.columns {
		columns << Column{
			name:     column.name
			typ:      column.typ
			not_null: column.not_null
		}
	}

	return columns
}

fn (mut o PrimaryKeyOperation) execute(_ []Row) ![]Row {
	min, max := o.key_range()!

	mut catalog := o.conn.catalog_for(o.table.name)
	tid := catalog.storage.transaction_id
	mut transaction_ids := catalog.storage.header.active_transaction_ids

	mut rows := []Row{}
	ids := o.table.column_ids()
	mut iter := catalog.storage.btree.new_range_iterator(min, max)
	for {
		object := iter.next() or { break }
		if object_is_visible(object.tid, object.xid, tid, mut transaction_ids) {
			rows << new_row_from_bytes_with_ids(o.table, ids, object.value, object.tid)
		}
	}
	if err := iter.err {
		return err
	}

	return rows
}

// key_range is the first and last keys (inclusive) to read. Each column of the
// PRIMARY KEY that's compared with = adds its value to the start of every key in
// the range, until a column that isn't, which can have a lower and upper bound.
// The range can include rows that the conditions aren't true for (such as the
// row with a value that's equal to the bound of "<"), since the WHERE clause is
// still applied.
fn (mut o PrimaryKeyOperation) key_range() !([]u8, []u8) {
	mut prefix := row_key_prefix(o.table.id)
	for i, name in o.table.primary_key {
		typ := o.table.column(name)!.typ
		mut equal := []u8{}
		mut lower := []u8{}
		mut upper := []u8{}
		for condition in o.conditions {
			if condition.column != i {
				continue
			}

			key := o.key_value(condition, typ) or { continue }
			match condition.op {
				.equal {
					equal = key.clone()
				}
				.greater_than, .greater_than_or_equal {
					if lower.len == 0 || compare_bytes(key, lower) > 0 {
						lower = key.clone()
					}
				}
				else {
					if upper.len == 0 || compare_bytes(key, upper) < 0 {
						upper = key.clone()
					}
				}
			}
		}

		if equal.len > 0 {
			prefix << equal
			continue
		}

		mut min := prefix.clone()
		min << lower
		mut max := prefix.clone()
		max << upper

		return min, next_key(max)
	}

	return prefix, next_key(prefix)
}

// key_value is the value of the condition encoded like the column in the key,
// if it can be used. A condition is ignored (as if it wasn't there) if the
// value can't be calculated or is NULL, or if the column can't hold the value
// exactly, such as 1.5 for an INTEGER, or a number that's too big. The WHERE
// clause still decides which rows are returned.
fn (mut o PrimaryKeyOperation) key_value(condition KeyCondition, typ Type) ?[]u8 {
	value := condition.value.run(mut o.conn, Row{}, o.params) or { return none }
	if value.is_null {
		return none
	}

	stored := exact_cast(mut o.conn, value, typ) or { return none }
	mut buf := new_empty_bytes()
	write_key_value(mut buf, stored, typ.typ)

	return buf.bytes()
}

// exact_cast is the value as the type of the column, or an error if the column
// can't hold the value exactly.
fn exact_cast(mut conn Connection, value Value, typ Type) !Value {
	stored := cast(mut conn, '', value, typ)!
	if compare(conn, stored, value)! != .is_equal {
		return error('${value.str()} is not exactly a ${typ}')
	}

	return stored
}

// next_key is the first key after every key that starts with key. Every key
// starts with the prefix of its type of object (such as "R"), so it's never all
// 0xff bytes.
fn next_key(key []u8) []u8 {
	mut end := key.len - 1
	for key[end] == 255 {
		end--
	}

	mut next := key[..end + 1].clone()
	next[end]++

	return next
}
