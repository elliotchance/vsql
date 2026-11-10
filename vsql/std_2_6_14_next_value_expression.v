module vsql

// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>
//
// Return the next value of a sequence generator.

// NextValueExpression for "NEXT VALUE FOR <sequence generator name>"
struct NextValueExpression {
	name Identifier
}

fn (e NextValueExpression) pstr(_ map[string]Value) string {
	return 'NEXT VALUE FOR ${e.name}'
}

fn (e NextValueExpression) compile(mut c Compiler) !CompileResult {
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 2
	if c.distinct {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in SELECT DISTINCT')
	}

	name := c.conn.resolve_catalog_identifier(e.name)!
	mut catalog := c.conn.catalog_for(name)

	// The value would depend on how many times (and in which order) a search
	// condition, sort key or aggregate argument is evaluated, so it can only be
	// used where it's evaluated once for each row of the result.
	//
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 2
	if c.next_value_not_allowed != '' {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in ${c.next_value_not_allowed}')
	}
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 1
	if c.conn.next_value_not_allowed != '' {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in ${c.conn.next_value_not_allowed}')
	}
	if c.conn.subquery_scopes.len > 0 {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in a subquery')
	}
	if c.in_aggregate {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in an aggregate function')
	}
	if _ := c.grouping_columns {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in a grouped query')
	}

	c.uses_next_value = true

	// The value has the data type of the sequence.
	//
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 3
	typ := catalog.storage.sequence(name)!.typ

	return CompileResult{
		run:          fn [name, mut catalog, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			// Multiple NEXT VALUE FOR the same sequence in the same row must return
			// the same value.
			key := name.id()
			if value := data.data.get(sequence_value_key(key)) {
				return sequence_value(mut conn, value.as_int(), typ)
			}
			if next := conn.row_sequence_values[key] {
				return sequence_value(mut conn, next, typ)
			}

			if conn.dry_run {
				sequence := catalog.storage.sequence(name)!
				return sequence_value(mut conn, sequence.current_value, typ)
			}

			next := catalog.storage.sequence_next_value(name)!
			conn.row_sequence_values[key] = next

			return sequence_value(mut conn, next, typ)
		}
		typ:          typ
		contains_agg: false
	}
}

// sequence_value is a value of a sequence with the data type typ, which is
// always within the range of the type (see Sequence.min and Sequence.max).
fn sequence_value(mut conn Connection, value i64, typ Type) !Value {
	if typ.typ == .is_bigint {
		return new_bigint_value(value)
	}

	return cast(mut conn, 'for NEXT VALUE FOR', new_bigint_value(value), typ)
}

// sequence_value_key is where SequenceValuesOperation keeps the value of a
// sequence generator in a row.
fn sequence_value_key(sequence string) string {
	return '\x00${sequence}'
}

// A SequenceValuesOperation takes the next values of the sequence generators
// for each row, so that a sort key and the select list see the same value, and
// the sort doesn't change how many values are used. A sort key can only use a
// NEXT VALUE FOR through the name of a column of the result.
//
// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 2
// ISO/IEC 9075-2:2016(E), 4.27.2, Operations involving sequence generators
struct SequenceValuesOperation {
	params  map[string]Value
	exprs   []ValueExpression
	columns Columns
	tables  map[string]&Table
mut:
	conn &Connection
}

fn (o &SequenceValuesOperation) str() string {
	return 'SEQUENCE VALUES (${o.exprs.map(it.pstr(o.params)).join(', ')})'
}

fn (o &SequenceValuesOperation) columns() Columns {
	return o.columns
}

fn (mut o SequenceValuesOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
		tables: o.tables
	}
	mut new_rows := []Row{cap: rows.len}
	// Each expression is compiled on the first row, then kept for the rows
	// after it.
	mut compiled := []CompileResult{cap: o.exprs.len}

	for row in rows {
		o.conn.begin_row()
		if compiled.len == 0 {
			for expr in o.exprs {
				compiled << expr.compile(mut c)!
			}
		}
		for result in compiled {
			result.run(mut o.conn, row, o.params)!
		}

		mut data := row.data.clone()
		for sequence, value in o.conn.row_sequence_values {
			data.set(sequence_value_key(sequence), new_bigint_value(value))
		}
		new_rows << Row{
			...row
			data: data
		}
	}

	return new_rows
}
