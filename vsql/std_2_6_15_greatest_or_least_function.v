module vsql

// ISO/IEC 9075-2:2023, 6.15, <greatest or least function>
//
// Specify functions yielding the greatest or least value of its arguments.

// GreatestOrLeastFunction is GREATEST(...) or LEAST(...), with at least two
// arguments.
struct GreatestOrLeastFunction {
	greatest bool
	exprs    []ValueExpression
}

fn (e GreatestOrLeastFunction) name() string {
	return if e.greatest { 'GREATEST' } else { 'LEAST' }
}

fn (e GreatestOrLeastFunction) pstr(params map[string]Value) string {
	return '${e.name()}(${e.exprs.map(it.pstr(params)).join(', ')})'
}

// compile gives the result the combined type of the arguments (9.5), and each
// argument is cast to it. The arguments must be comparable with each other, and
// each one is an operand of an ordering operation. The result is the NULL value
// if any of them is NULL.
//
// Two values can be equal without being the same, such as 'a' and 'a ' (the
// collation has PAD SPACE), or the same time in two different time zones, so
// the result is possibly non-deterministic when an argument is a character
// string or a datetime with a time zone. The first one of the equal greatest
// (or least) values is the result.
//
// ISO/IEC 9075-2:2023, 6.15, <greatest or least function>, Syntax Rules, 1 to 7
// ISO/IEC 9075-2:2023, 6.15, <greatest or least function>, General Rules, 1 to 4
// ISO/IEC 9075-2:2023, 9.16, Potential sources of non-determinism, Syntax Rules, 1.f
// ISO/IEC 9075-2:2023, 9.14, Ordering operations, Syntax Rules, 2.i
fn (e GreatestOrLeastFunction) compile(mut c Compiler) !CompileResult {
	name := e.name()

	// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xvi
	compiled := c.with_types(e.exprs.map(it.compile(mut c)!), same_type)

	mut typ := Type{compiled[0].typ.typ, compiled[0].typ.size, compiled[0].typ.scale, false, false}
	mut contains_agg := false
	for i, a in compiled {
		for b in compiled[i + 1..] {
			if !comparable_types(a.typ.typ, b.typ.typ) || (a.typ.typ.is_datetime()
				&& b.typ.typ.is_datetime() && datetime_fields(a.typ.typ) != datetime_fields(b.typ.typ)) {
				return sqlstate_42883('cannot compare ${a.typ} and ${b.typ} in ${name}')
			}
		}
		if a.typ.typ in [.is_character, .is_varchar] || a.typ.has_time_zone() {
			c.check_deterministic('${name} of ${a.typ}')!
		}
		if i > 0 {
			typ = combine_types(typ, a.typ) or {
				return sqlstate_42804('in argument ${i + 1} of ${name}', typ.str(), a.typ.str())
			}
		}
		contains_agg = contains_agg || a.contains_agg
	}

	greatest := e.greatest
	return CompileResult{
		run:          fn [compiled, typ, greatest, name] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut values := []Value{cap: compiled.len}
			for a in compiled {
				value := a.run(mut conn, data, params)!
				if value.is_null {
					return new_null_value(typ.typ)
				}
				values << convert_to_combined_type(mut conn, 'in ${name}', value, typ)!
			}

			mut result := values[0]
			for value in values[1..] {
				cmp := compare(conn, value, result)!
				if (greatest && cmp == .is_greater) || (!greatest && cmp == .is_less) {
					result = value
				}
			}

			return result
		}
		typ:          typ
		contains_agg: contains_agg
	}
}
