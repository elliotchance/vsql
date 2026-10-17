module vsql

// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>
//
// Return the next value of a sequence generator.

// NextValueExpression for "NEXT VALUE FOR <sequence generator name>"
struct NextValueExpression {
	name Identifier
}

fn (e NextValueExpression) pstr(params map[string]Value) string {
	return 'NEXT VALUE FOR ${e.name}'
}

fn (e NextValueExpression) compile(mut c Compiler) !CompileResult {
	mut catalog := c.conn.catalog()
	name := c.conn.resolve_identifier(e.name)

	return CompileResult{
		run:          fn [name, mut catalog] (mut conn Connection, data Row, params map[string]Value) !Value {
			// Multiple NEXT VALUE FOR the same sequence in the same row must return
			// the same value.
			key := name.id()
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
		typ:          new_type('INTEGER', 0, 0)
		contains_agg: false
	}
}

fn (e NextValueExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !NextValueExpression {
	return NextValueExpression{conn.resolve_identifier(e.name)}
}
