module vsql

// CONCAT and CONCAT_WS (V404-08 and V404-09) join any number of character
// strings, like a chain of || (6.32, <string value expression>), except that a
// NULL argument is left out rather than making the result NULL. They're
// variadic functions (see Func.is_variadic), so they're registered to describe
// them as routines (see register_concat_funcs), but they're compiled by
// compile_concat.
//
// The result is a CHARACTER LARGE OBJECT if any argument is one, otherwise a
// CHARACTER VARYING as long as all of the arguments (and separators) together.
// It's never a CHARACTER, even if every argument is, because the length of a
// result that skips a NULL isn't fixed. A CHARACTER argument keeps its padding,
// like it does with ||.

// register_concat_funcs registers CONCAT(VARIADIC) and
// CONCAT_WS(SEPARATOR, VARIADIC). They're called with a NULL argument, which is
// left out.
fn register_concat_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	for name, features in {
		'CONCAT':    [vsql_concat]
		'CONCAT_WS': [vsql_concat_ws]
	} {
		conn.register_func(Func{
			name:                 name
			arg_types:            if name == 'CONCAT_WS' { [varchar] } else { []Type{} }
			func:                 if name == 'CONCAT_WS' { func_concat_ws } else { func_concat }
			return_type:          varchar
			called_on_null_input: true
			is_deterministic:     true
			features:             features
			arg_names:            if name == 'CONCAT_WS' { ['SEPARATOR'] } else { []string{} }
			is_variadic:          true
		})!
	}
}

fn is_concat_function(name string) bool {
	return name in ['CONCAT', 'CONCAT_WS']
}

fn compile_concat(mut c Compiler, e RoutineInvocation) !CompileResult {
	func_name := e.function_name
	is_ws := func_name == 'CONCAT_WS'
	min_args := if is_ws { 2 } else { 1 }
	if e.args.len < min_args {
		return sqlstate_42883('${func_name} has ${e.args.len} ${pluralize(e.args.len, 'argument')} but needs at least ${min_args} ${pluralize(min_args, 'argument')}')
	}
	if e.distinct || e.filter != none {
		return sqlstate_42601('${func_name} is not an aggregate function')
	}

	// A dynamic parameter argument is a CHARACTER VARYING.
	varchar := Type{.is_varchar, max_character_length, 0, false, false}
	mut args := []CompileResult{}
	for arg in e.args {
		args << c.with_type(arg.compile(mut c)!, varchar)
	}

	if !args.all(it.typ.typ in [.is_character, .is_varchar, .is_clob]) {
		return sqlstate_42883('function does not exist: ${func_name}(${args.map(it.typ.str()).join(', ')})')
	}

	if c.conn.flagging {
		c.conn.flagged_features << if is_ws { vsql_concat_ws } else { vsql_concat }
	}

	typ := concat_type(args, is_ws)

	return CompileResult{
		run:          fn [args, is_ws, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut values := []Value{}
			for arg in args {
				values << arg.run(mut conn, data, params)!
			}
			f := if is_ws { func_concat_ws } else { func_concat }
			joined := f(FunctionContext{ conn: conn }, values)!
			if joined.is_null {
				return new_null_value(typ.typ).with_type(typ)
			}

			s := limit_concatenation(joined.string_value(), typ)!
			if typ.typ == .is_clob {
				return new_clob_value(s).with_type(typ)
			}

			return new_varchar_value(s).with_type(typ)
		}
		typ:          typ
		contains_agg: args.any(it.contains_agg)
	}
}

// concat_type is a CHARACTER LARGE OBJECT if any argument is one. Otherwise,
// it's a CHARACTER VARYING as long as the longest result: every value, and a
// separator between each of them. Like a concatenation, the length is unknown
// if any of them is, and it's no longer than the maximum length.
fn concat_type(args []CompileResult, is_ws bool) Type {
	if args.any(it.typ.typ == .is_clob) {
		return Type{.is_clob, 0, 0, false, false}
	}

	// The copy works around https://github.com/vlang/v/issues/32932 (-autofree).
	values := if is_ws { args[1..] } else { own_array(args) }
	mut size := 0
	for arg in values {
		if arg.typ.size == 0 {
			return Type{.is_varchar, 0, 0, false, false}
		}
		size += arg.typ.size
	}
	if is_ws {
		if args[0].typ.size == 0 {
			return Type{.is_varchar, 0, 0, false, false}
		}
		size += args[0].typ.size * (values.len - 1)
	}

	return Type{.is_varchar, if size > max_character_length {
		max_character_length
	} else {
		size
	}, 0, false, false}
}

// func_concat joins the arguments that aren't NULL.
fn func_concat(_ FunctionContext, args []Value) !Value {
	return new_varchar_value(join_not_null(args, ''))
}

// func_concat_ws joins the arguments after the separator (the first argument)
// that aren't NULL, with the separator between them. Every database returns
// NULL for a NULL separator, there's nothing to put between the values.
fn func_concat_ws(_ FunctionContext, args []Value) !Value {
	if args[0].is_null {
		return new_null_value(.is_varchar)
	}

	return new_varchar_value(join_not_null(args[1..], args[0].string_value()))
}

fn join_not_null(values []Value, separator string) string {
	return values.filter(!it.is_null).map(it.string_value()).join(separator)
}
