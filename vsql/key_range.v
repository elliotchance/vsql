// key_range.v uses the PRIMARY KEY to read only the rows of a table that the
// WHERE clause can be true for.

module vsql

// A KeyCondition is a condition of the WHERE clause that compares a column of
// a key (the PRIMARY KEY or an index) with a value that's the same for every
// row, such as "id >= 10" (or "10 <= id"). The conditions narrow down the rows
// that are read. The WHERE clause is still applied to each of them, except for
// the parts that the range is known to cover exactly (see covered_factors).
struct KeyCondition {
	// column is the position of the column in the key.
	column int
	// op is how the column compares with the value, it's never not_equal.
	op    ComparisonOperator
	value CompileResult
	// text is how the condition is shown by EXPLAIN.
	text string
	// factor is the position of the part of the AND that it's from.
	factor int
	// exact is true when the value is known (before any rows are read) to be
	// usable in the key exactly, see is_exact_key_value.
	exact bool
}

// key_operation reads only the rows of a table that the WHERE clause can be
// true for (see best_key_operation), and knows which parts of it are covered
// (see covered_factors).
//
// base_table is the stored table and table is how the query names it, which is
// different with a correlation name, such as "t AS x (a, b)".
fn key_operation(body QuerySpecification, base_table Table, table Table, params map[string]Value, mut conn Connection) ?&KeyOperation {
	where := body.table_expression.where_clause or { return none }
	factors := and_factors(where)
	mut operation := best_key_operation(factors, base_table, table, map[string]&Table{},
		params, mut conn) or { return none }
	operation.covered = operation.covered_factors(factors)

	return operation
}

// best_key_operation reads only the rows of a table that the conditions in
// factors can be true for, using the PRIMARY KEY or an index, whichever has the
// most leading columns compared with = (and then a range on the next column).
// The PRIMARY KEY is used when they're the same, then the index that's first by
// name. It's none when neither can be used, because there is no condition on the
// first column of any of them.
//
// A value that a column is compared with can only use the columns of
// value_tables, which are the other tables of a join (see JoinOperation). They
// come from the row that's passed to KeyOperation.read.
fn best_key_operation(factors []BooleanTest, base_table Table, table Table, value_tables map[string]&Table, params map[string]Value, mut conn Connection) ?&KeyOperation {
	if factors.len == 0 {
		return none
	}

	mut best := ?&KeyOperation(none)
	mut best_score := 0
	if base_table.primary_key.len > 0 {
		conditions := key_conditions_of(factors, base_table, table, base_table.primary_key,
			value_tables, params, mut conn)
		best_score = key_score(conditions)
		if best_score > 0 {
			best = new_primary_key_operation(base_table, conditions, params, conn)
		}
	}

	catalog := conn.catalog_for(base_table.name)
	for index in catalog.storage.table_indexes(base_table.id) {
		conditions := key_conditions_of(factors, base_table, table, index.columns.map(it.name),
			value_tables, params, mut conn)
		score := key_score(conditions)
		if score > best_score {
			best = new_index_operation(base_table, index, conditions, params, conn)
			best_score = score
		}
	}

	return best
}

// and_factors are the parts of a condition when it's one or more conditions
// joined by AND. Otherwise, there are none, since any row can be true for an OR.
fn and_factors(condition BooleanValueExpression) []BooleanTest {
	if _ := condition.expr {
		return []
	}

	// The last part of an AND is first.
	mut factors := []BooleanTest{}
	mut term := condition.term
	for {
		factors.prepend(term.factor)
		next := term.term or { break }
		term = *next
	}

	return factors
}

// key_conditions_of are the conditions (in factors) for the key_columns of
// base_table.
fn key_conditions_of(factors []BooleanTest, base_table Table, table Table, key_columns []string, value_tables map[string]&Table, params map[string]Value, mut conn Connection) []KeyCondition {
	mut conditions := []KeyCondition{}
	for i, factor in factors {
		for condition in key_conditions(factor, base_table, table, key_columns, value_tables,
			params, mut conn) {
			conditions << KeyCondition{
				...condition
				factor: i
			}
		}
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
fn key_conditions(test BooleanTest, base_table Table, table Table, key_columns []string, value_tables map[string]&Table, params map[string]Value, mut conn Connection) []KeyCondition {
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
					base_table, table, key_columns, value_tables, params, mut conn)
				{
					conditions << condition
				} else if condition := key_condition(predicate.right, predicate.op.reverse(),
					predicate.left, base_table, table, key_columns, value_tables, params, mut conn)
				{
					conditions << condition
				}
			}
		}
		BetweenPredicate {
			if !predicate.not && !predicate.symmetric {
				if condition := key_condition(predicate.expr, .greater_than_or_equal,
					predicate.left, base_table, table, key_columns, value_tables, params, mut conn)
				{
					conditions << condition
				}
				if condition := key_condition(predicate.expr, .less_than_or_equal, predicate.right,
					base_table, table, key_columns, value_tables, params, mut conn)
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
// of the PRIMARY KEY or an index) and value doesn't depend on the row. The value
// can be any expression that doesn't refer to a column (including an outer
// reference), such as a literal, a parameter or "1 + 2", except a column of
// value_tables. The types must be comparable, otherwise the WHERE clause (or
// join condition) has to raise the error, even if no rows would be read.
fn key_condition(column_side RowValueConstructorPredicand, op ComparisonOperator, value_side RowValueConstructorPredicand, base_table Table, table Table, key_columns []string, value_tables map[string]&Table, params map[string]Value, mut conn Connection) ?KeyCondition {
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
		tables:                 if value_tables.len > 0 {
			value_tables
		} else {
			{
				'': &Table{}
			}
		}
		next_value_not_allowed: 'WHERE'
	}
	value := value_side.compile(mut c) or { return none }
	if value.contains_agg || !is_key_comparable(column_type.typ, value.typ.typ) {
		return none
	}

	return KeyCondition{
		column: key_column
		op:     op
		value:  value
		text:   '${column_side.pstr(params)} ${op} ${value_side.pstr(params)}'
		exact:  is_exact_key_value(mut conn, value, column_type, params)
	}
}

// is_exact_key_value is true when the value is always used by key_range, and
// comparing its key with the key of the column gives the same result as
// comparing the values. That's only when it's a constant integer (so it has the
// same value when the rows are read, and doesn't raise an error) that the
// column, also an integer, can hold. Integers are compared exactly as 64-bit
// integers, whereas other types can be rounded (such as a BIGINT compared with
// a DOUBLE PRECISION), or compared differently than their keys (such as with
// trailing spaces).
fn is_exact_key_value(mut conn Connection, value CompileResult, typ Type, params map[string]Value) bool {
	integers := [SQLType.is_smallint, .is_integer, .is_bigint]
	if !value.constant || typ.typ !in integers || value.typ.typ !in integers {
		return false
	}

	// NULL isn't exact either, since it's not equal to itself.
	v := value.run(mut conn, Row{}, params) or { return false }
	exact_cast(mut conn, v, typ) or { return false }

	return true
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

// A KeyOperation reads the rows of a table that are in the range of its
// PRIMARY KEY, or an index, that the conditions allow.
struct KeyOperation {
	table Table
	// index is none for the PRIMARY KEY.
	index      ?Index
	conditions []KeyCondition
	params     map[string]Value
mut:
	conn &Connection
	// covered is set by key_operation, see covered_factors.
	covered []bool
}

fn new_primary_key_operation(table Table, conditions []KeyCondition, params map[string]Value, conn &Connection) &KeyOperation {
	return &KeyOperation{table, none, conditions, params, conn, []}
}

fn new_index_operation(table Table, index Index, conditions []KeyCondition, params map[string]Value, conn &Connection) &KeyOperation {
	return &KeyOperation{table, index, conditions, params, conn, []}
}

fn (o &KeyOperation) str() string {
	key := if index := o.index { 'INDEX ${index.name} ON' } else { 'PRIMARY KEY' }

	columns := '${key} ${o.table.name} (${key_operation_columns(o.table, true)})'
	if o.conditions.len == 0 {
		return columns
	}

	return '${columns} RANGE ${o.conditions.map(it.text).join(' AND ')}'
}

// covered_factors are true for each of the factors (the parts of the AND that
// the conditions came from) that every row read is known to be true for, so
// they don't need to be checked again. That's when each condition of the factor
// (BETWEEN has two) is exact, and is used for the range in the same way by
// key_range: every column before it in the key is compared with = (the last =
// of the column, which is the one that's used), and it's the last = of its
// column, or a >= or <= of the first column that isn't compared with =. A
// condition with > or < can't be covered, because the bound is part of the
// range.
fn (o &KeyOperation) covered_factors(factors []BooleanTest) []bool {
	key_len := if index := o.index { index.columns.len } else { o.table.primary_key.len }
	mut used := []bool{len: o.conditions.len}
	for column in 0 .. key_len {
		mut equal := -1
		for i, condition in o.conditions {
			if condition.column == column && condition.op == .equal {
				equal = i
			}
		}

		if equal >= 0 {
			if !o.conditions[equal].exact {
				break
			}
			used[equal] = true
			continue
		}

		for i, condition in o.conditions {
			used[i] = used[i] || (condition.column == column && condition.exact
				&& condition.op in [.greater_than_or_equal, .less_than_or_equal])
		}
		break
	}

	mut covered := []bool{len: factors.len}
	for i, factor in factors {
		mut count := 0
		mut all_used := true
		for j, condition in o.conditions {
			if condition.factor == i {
				count++
				all_used = all_used && used[j]
			}
		}
		covered[i] = all_used && count == key_conditions_len(factor)
	}

	return covered
}

// key_conditions_len is how many conditions key_conditions has for a factor when
// all of it is a condition of the key: two for BETWEEN, otherwise one.
fn key_conditions_len(test BooleanTest) int {
	primary := *test.expr
	predicate := match primary {
		Predicate { primary }
		else { return 1 }
	}

	return if predicate is BetweenPredicate { 2 } else { 1 }
}

fn (o &KeyOperation) columns() Columns {
	return key_operation_columns(o.table, false)
}

fn (mut o KeyOperation) execute(_ []Row) ![]Row {
	return o.read(Row{})
}

// read is the same as execute, except that the values of the conditions can use
// the columns of row (see best_key_operation).
//
// With an index, the rows are in the order of the index. An entry is visible
// when the version of the row that it was written for is, so the row has a
// visible version. Entries that aren't visible are skipped, because the version
// of the row that is visible has a different entry (or none).
fn (mut o KeyOperation) read(row Row) ![]Row {
	mut key_columns := []KeyColumn{}
	mut prefix := row_key_prefix(o.table.id)
	if index := o.index {
		prefix = index_entry_prefix(index.id)
		for column in index.columns {
			key_columns << KeyColumn{
				typ:      o.table.column(column.name)!.typ
				nullable: true
				desc:     column.desc
			}
		}
	} else {
		for name in o.table.primary_key {
			key_columns << KeyColumn{
				typ: o.table.column(name)!.typ
			}
		}
	}
	min, max := key_range(mut o.conn, o.params, row, prefix, key_columns, o.conditions) or {
		return []
	}

	mut catalog := o.conn.catalog_for(o.table.name)
	index := o.index or { return o.read_rows(mut catalog, min, max, false) }

	mut rows := []Row{}
	mut entries := catalog.storage.btree.new_range_iterator(min, max)
	for {
		entry := entries.next() or { break }
		if !catalog.storage.is_visible(entry.tid, entry.xid) {
			continue
		}

		mut key := row_key_prefix(o.table.id)
		key << index.entry_row_id(o.table, entry.key)!
		rows << o.read_rows(mut catalog, key, key, true)!
	}
	if err := entries.err {
		return err
	}

	return rows
}

// read_rows are the visible rows from min to max, which only includes max when
// include_max is true.
fn (o &KeyOperation) read_rows(mut catalog CatalogConnection, min []u8, max []u8, include_max bool) ![]Row {
	mut rows := []Row{}
	ids := o.table.column_ids()
	mut iter := catalog.storage.btree.new_range_iterator(min, max)
	for {
		object := iter.next() or { break }
		if !include_max && object.key == max {
			break
		}
		if catalog.storage.is_visible(object.tid, object.xid) {
			rows << new_row_from_bytes_with_ids(o.table, ids, object.value, object.tid)
		}
	}
	if err := iter.err {
		return err
	}

	return rows
}

// key_operation_columns are the columns of a table read by a KeyOperation. EXPLAIN only shows (pretty) the names, without the table,
// because the full names would make the output extra verbose.
fn key_operation_columns(table Table, pretty bool) Columns {
	mut columns := []Column{}
	for column in table.result_columns() {
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

// key_range is the first key to read and the key after the last one, of the
// keys that start with prefix. The key after (from next_key) can be the key of
// a row, such as the next INTEGER of a PRIMARY KEY, so it isn't read (an index
// entry is always longer, since it ends with the row ID). Each column of the
// key that's compared with = adds its value to the start of every key in the
// range, until a column that isn't, which can have a lower and upper bound. The
// range can include rows that the conditions aren't true for (such as the row
// with a value that's equal to the bound of "<"), so the WHERE clause is still
// applied, except for what covered_factors says the range covers. A column with
// a lower or upper bound never includes NULL, because a comparison with NULL is
// never true.
//
// The values of the conditions can use the columns of row. It's none when one
// of them is NULL, since no row can be true for that condition, so none need to
// be read.
fn key_range(mut conn Connection, params map[string]Value, row Row, prefix []u8, columns []KeyColumn, conditions []KeyCondition) ?([]u8, []u8) {
	mut key := prefix.clone()
	mut min := []u8{}
	mut max := []u8{}
	for i, column in columns {
		mut equal := []u8{}
		mut lower := []u8{}
		mut upper := []u8{}
		for condition in conditions {
			if condition.column != i {
				continue
			}

			value := condition.value.run(mut conn, row, params) or { continue }
			if value.is_null {
				return none
			}
			encoded := key_value_bytes(mut conn, value, column.typ) or { continue }
			match condition.op {
				.equal {
					equal = encoded.clone()
				}
				.greater_than, .greater_than_or_equal {
					if lower.len == 0 || compare_bytes(encoded, lower) > 0 {
						lower = encoded.clone()
					}
				}
				else {
					if upper.len == 0 || compare_bytes(encoded, upper) < 0 {
						upper = encoded.clone()
					}
				}
			}
		}

		if min.len > 0 {
			continue
		}

		if equal.len > 0 {
			key << column.part(equal)
			continue
		}

		if lower.len == 0 && upper.len == 0 {
			min = key.clone()
			max = next_key(key)
			continue
		}

		// A DESC column has the largest values first.
		min = key.clone()
		min << column.part(if column.desc { upper } else { lower })
		max = key.clone()
		max << column.part(if column.desc { lower } else { upper })
		max = next_key(max)
	}

	if min.len > 0 {
		return min, max
	}

	return key, next_key(key)
}

// key_value_bytes is the value encoded like the column in the key (see
// write_key_value), if it can be used. A condition is ignored (as if it wasn't
// there) if the column can't hold the value exactly, such as 1.5 for an
// INTEGER, or a number that's too big. The WHERE clause still decides which rows
// are returned.
fn key_value_bytes(mut conn Connection, value Value, typ Type) ?[]u8 {
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
