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
	if c.in_aggregate {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in an aggregate function')
	}
	if _ := c.grouping_columns {
		return sqlstate_42601('NEXT VALUE FOR cannot be used in a grouped query')
	}

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
		typ:          new_type('BIGINT', 0, 0)
		contains_agg: false
	}
}
