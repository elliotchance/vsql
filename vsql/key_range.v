// key_range.v uses the PRIMARY KEY to read only the rows of a table that the
// WHERE clause can be true for.

module vsql

// A KeyCondition is a condition of the WHERE clause that compares a column of
// a key (the PRIMARY KEY or an index) with a value that's the same for every
// row, such as "id >= 10" (or "10 <= id"). The conditions only narrow down the
// rows that are read, the whole WHERE clause is still applied to each of them.
struct KeyCondition {
	// column is the position of the column in the key.
	column int
	// op is how the column compares with the value, it's never not_equal.
	op    ComparisonOperator
	value CompileResult
	// text is how the condition is shown by EXPLAIN.
	text string
}

// key_operation reads only the rows of a table that the WHERE clause can be
// true for, using the PRIMARY KEY or an index, whichever has the most leading
// columns compared with = (and then a range on the next column). The PRIMARY
// KEY is used when they're the same, then the index that's first by name. It's
// none when neither can be used, because there is no condition on the first
// column of any of them.
//
// base_table is the stored table and table is how the query names it, which is
// different with a correlation name, such as "t AS x (a, b)".
fn key_operation(body QuerySpecification, base_table Table, table Table, params map[string]Value, mut conn Connection) ?PlanOperation {
	factors := where_factors(body)
	if factors.len == 0 {
		return none
	}

	mut best := ?PlanOperation(none)
	mut best_score := 0
	if base_table.primary_key.len > 0 {
		conditions := key_conditions_of(factors, base_table, table, base_table.primary_key,
			params, mut conn)
		best_score = key_score(conditions)
		if best_score > 0 {
			best = new_primary_key_operation(base_table, conditions, params, conn)
		}
	}

	catalog := conn.catalog_for(base_table.name)
	for index in catalog.storage.table_indexes(base_table.id) {
		conditions := key_conditions_of(factors, base_table, table, index.columns.map(it.name),
			params, mut conn)
		score := key_score(conditions)
		if score > best_score {
			best = new_index_operation(base_table, index, conditions, params, conn)
			best_score = score
		}
	}

	return best
}

// where_factors are the parts of the WHERE clause when it's one or more
// conditions joined by AND. Otherwise, there are none, since any row can be true
// for an OR.
fn where_factors(body QuerySpecification) []BooleanTest {
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

	return factors
}

// key_conditions_of are the conditions (in factors) for the key_columns of
// base_table.
fn key_conditions_of(factors []BooleanTest, base_table Table, table Table, key_columns []string, params map[string]Value, mut conn Connection) []KeyCondition {
	mut conditions := []KeyCondition{}
	for factor in factors {
		conditions << key_conditions(factor, base_table, table, key_columns, params, mut
			conn)
	}

	return conditions
}

// key_score is how good the conditions are for finding rows with a key: two for
// each leading column of the key that's compared with =, and one more if the
// next column has a range. It's 0 when there is no condition for the first
// column, since the key is in the order of the first column, so it can't be
// used.
fn key_score(conditions []KeyCondition) int {
	mut score := 0
	for column := 0; conditions.any(it.column == column); column++ {
		if !conditions.any(it.column == column && it.op == .equal) {
			return score + 1
		}
		score += 2
	}

	return score
}

// key_conditions are the conditions of one part of an AND. BETWEEN is the same
// as two conditions.
fn key_conditions(test BooleanTest, base_table Table, table Table, key_columns []string, params map[string]Value, mut conn Connection) []KeyCondition {
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
					base_table, table, key_columns, params, mut conn)
				{
					conditions << condition
				} else if condition := key_condition(predicate.right, predicate.op.reverse(),
					predicate.left, base_table, table, key_columns, params, mut conn)
				{
					conditions << condition
				}
			}
		}
		BetweenPredicate {
			if !predicate.not && !predicate.symmetric {
				if condition := key_condition(predicate.expr, .greater_than_or_equal,
					predicate.left, base_table, table, key_columns, params, mut conn)
				{
					conditions << condition
				}
				if condition := key_condition(predicate.expr, .less_than_or_equal, predicate.right,
					base_table, table, key_columns, params, mut conn)
				{
					conditions << condition
				}
			}
		}
		else {}
	}

	return conditions
}

// key_condition is "column op value", if column is one of key_columns (a column
// of the PRIMARY KEY or an index) and value doesn't depend on the row. The value can be any expression that
// doesn't refer to a column (including an outer reference), such as a literal,
// a parameter or "1 + 2". The types must be comparable, otherwise the WHERE
// clause has to raise the error, even if no rows would be read.
fn key_condition(column_side RowValueConstructorPredicand, op ComparisonOperator, value_side RowValueConstructorPredicand, base_table Table, table Table, key_columns []string, params map[string]Value, mut conn Connection) ?KeyCondition {
	column := new_column_identifier(column_side.pstr(params)) or { return none }
	if column.custom_id != '' || !column.is_column_of_table(conn, table) {
		return none
	}

	// The columns of table are the columns of base_table, in the same order.
	mut key_column := -1
	mut column_type := Type{}
	for i, name in key_columns {
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
	return 'PRIMARY KEY ${o.table.name} (${key_operation_columns(o.table, true)}) RANGE ${o.conditions.map(it.text).join(' AND ')}'
}

fn (o &PrimaryKeyOperation) columns() Columns {
	return key_operation_columns(o.table, false)
}

fn (mut o PrimaryKeyOperation) execute(_ []Row) ![]Row {
	mut key_columns := []KeyColumn{}
	for name in o.table.primary_key {
		key_columns << KeyColumn{
			typ: o.table.column(name)!.typ
		}
	}
	min, max := key_range(mut o.conn, o.params, row_key_prefix(o.table.id), key_columns,
		o.conditions)

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

// An IndexOperation reads the entries of an index that are in the range that
// the conditions allow, and then the row of each entry.
struct IndexOperation {
	table      Table
	index      Index
	conditions []KeyCondition
	params     map[string]Value
mut:
	conn &Connection
}

fn new_index_operation(table Table, index Index, conditions []KeyCondition, params map[string]Value, conn &Connection) &IndexOperation {
	return &IndexOperation{table, index, conditions, params, conn}
}

fn (o &IndexOperation) str() string {
	return 'INDEX ${o.index.name} ON ${o.table.name} (${key_operation_columns(o.table, true)}) RANGE ${o.conditions.map(it.text).join(' AND ')}'
}

fn (o &IndexOperation) columns() Columns {
	return key_operation_columns(o.table, false)
}

// execute reads the rows in the order of the index. An entry is visible when
// the version of the row that it was written for is, so the row has a visible
// version. Entries that aren't visible are skipped, because the version of the
// row that is visible has a different entry (or none).
fn (mut o IndexOperation) execute(_ []Row) ![]Row {
	mut key_columns := []KeyColumn{}
	for column in o.index.columns {
		key_columns << KeyColumn{
			typ:      o.table.column(column.name)!.typ
			nullable: true
			desc:     column.desc
		}
	}
	min, max := key_range(mut o.conn, o.params, index_entry_prefix(o.index.id), key_columns,
		o.conditions)

	mut catalog := o.conn.catalog_for(o.table.name)
	tid := catalog.storage.transaction_id
	mut transaction_ids := catalog.storage.header.active_transaction_ids

	mut rows := []Row{}
	mut entries := catalog.storage.btree.new_range_iterator(min, max)
	for {
		entry := entries.next() or { break }
		if !object_is_visible(entry.tid, entry.xid, tid, mut transaction_ids) {
			continue
		}

		mut key := row_key_prefix(o.table.id)
		key << o.index.entry_row_id(o.table, entry.key)!
		mut iter := catalog.storage.btree.new_range_iterator(key, key)
		for {
			object := iter.next() or { break }
			if object_is_visible(object.tid, object.xid, tid, mut transaction_ids) {
				rows << new_row_from_bytes(o.table, object.value, object.tid)
			}
		}
		if err := iter.err {
			return err
		}
	}
	if err := entries.err {
		return err
	}

	return rows
}

// key_operation_columns are the columns of a table read by a PrimaryKeyOperation
// or IndexOperation. EXPLAIN only shows (pretty) the names, without the table,
// because the full names would make the output extra verbose.
fn key_operation_columns(table Table, pretty bool) Columns {
	mut columns := []Column{}
	for column in table.columns {
		columns << Column{
			name:     if pretty {
				Identifier{
					sub_entity_name: column.name.sub_entity_name
				}
			} else {
				column.name
			}
			typ:      column.typ
			not_null: column.not_null
		}
	}

	return columns
}

// A KeyColumn is how a column of a key is encoded. The value of a nullable
// column (of an index) starts with a byte that's 1 (0 is NULL), and every byte
// of a desc column is flipped, see Index.entry_key.
struct KeyColumn {
	typ      Type
	nullable bool
	desc     bool
}

// part is the start of the key of the column for a value that's already been
// written with write_key_value (or empty, for the first value that isn't NULL).
fn (c KeyColumn) part(value []u8) []u8 {
	mut part := if c.nullable { [u8(1)] } else { []u8{} }
	part << value
	if c.desc {
		for i in 0 .. part.len {
			part[i] = ~part[i]
		}
	}

	return part
}

// key_range is the first and last keys (inclusive) to read, of the keys that
// start with prefix. Each column of the key that's compared with = adds its
// value to the start of every key in the range, until a column that isn't, which
// can have a lower and upper bound. The range can include rows that the
// conditions aren't true for (such as the row with a value that's equal to the
// bound of "<"), since the WHERE clause is still applied. A column with a lower
// or upper bound never includes NULL, because a comparison with NULL is never
// true.
fn key_range(mut conn Connection, params map[string]Value, prefix []u8, columns []KeyColumn, conditions []KeyCondition) ([]u8, []u8) {
	mut key := prefix.clone()
	for i, column in columns {
		mut equal := []u8{}
		mut lower := []u8{}
		mut upper := []u8{}
		for condition in conditions {
			if condition.column != i {
				continue
			}

			value := condition_key_value(mut conn, params, condition, column.typ) or { continue }
			match condition.op {
				.equal {
					equal = value.clone()
				}
				.greater_than, .greater_than_or_equal {
					if lower.len == 0 || compare_bytes(value, lower) > 0 {
						lower = value.clone()
					}
				}
				else {
					if upper.len == 0 || compare_bytes(value, upper) < 0 {
						upper = value.clone()
					}
				}
			}
		}

		if equal.len > 0 {
			key << column.part(equal)
			continue
		}

		if lower.len == 0 && upper.len == 0 {
			break
		}

		// A DESC column has the largest values first.
		mut min := key.clone()
		min << column.part(if column.desc { upper } else { lower })
		mut max := key.clone()
		max << column.part(if column.desc { lower } else { upper })

		return min, next_key(max)
	}

	return key, next_key(key)
}

// condition_key_value is the value of the condition encoded like the column in the key
// (see write_key_value), if it can be used. A condition is ignored (as if it
// wasn't there) if the value can't be calculated or is NULL, or if the column
// can't hold the value exactly, such as 1.5 for an INTEGER, or a number that's
// too big. The WHERE clause still decides which rows are returned.
fn condition_key_value(mut conn Connection, params map[string]Value, condition KeyCondition, typ Type) ?[]u8 {
	value := condition.value.run(mut conn, Row{}, params) or { return none }
	if value.is_null {
		return none
	}

	stored := exact_cast(mut conn, value, typ) or { return none }
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
