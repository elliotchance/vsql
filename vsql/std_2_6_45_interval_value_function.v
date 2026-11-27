module vsql

// ISO/IEC 9075-2:2023, 6.45, <interval value function>
//
// Specify a function yielding a value of type interval.
//
// The <interval absolute value function> is ABS of an interval, which is a
// RoutineInvocation like ABS of a number (see compile_interval_abs).

// compile_interval_abs is ABS(x) for an interval x, which has the type of x.
//
// ISO/IEC 9075-2:2023, 6.45, <interval value function>, Syntax Rules, 1
// ISO/IEC 9075-2:2023, 6.45, <interval value function>, General Rules, 1, 1.a, 1.b and 1.c
// ISO/IEC 9075-2:2023, 6.45, <interval value function>, Conformance Rules, 1
fn (mut c Compiler) compile_interval_abs(x CompileResult) CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	x_ref := &CompileResult{
		...x
	}
	if c.conn.flagging {
		c.conn.flag('F052')
	}

	return CompileResult{
		run:          fn [x_ref] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := x_ref.run(mut conn, data, params)!
			if value.is_null || value.int_value() >= 0 {
				return value
			}

			return new_interval_value(value.typ, -value.int_value())
		}
		typ:          x.typ
		contains_agg: x.contains_agg
		constant:     x.constant
	}.fold()
}
