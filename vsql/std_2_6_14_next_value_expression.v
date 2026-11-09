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

	return CompileResult{
		run:          fn [name, mut catalog] (mut conn Connection, data Row, params map[string]Value) !Value {
			// Multiple NEXT VALUE FOR the same sequence in the same row must return
			// the same value.
			key := name.id()
			if value := data.data[sequence_value_key(key)] {
				return value
			}
			if next := conn.row_sequence_values[key] {
				return new_bigint_value(next)
			}

			if conn.dry_run {
				sequence := catalog.storage.sequence(name)!
				return new_bigint_value(sequence.current_value)
			}

			next := catalog.storage.sequence_next_value(name)!
			conn.row_sequence_values[key] = next

			return new_bigint_value(next)
		}
		typ:          new_type('BIGINT', 0, 0)
		contains_agg: false
	}
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
			data[sequence_value_key(sequence)] = new_bigint_value(value)
		}
		new_rows << Row{
			...row
			data: data
		}
	}

	return new_rows
}
