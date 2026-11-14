module vsql

// ISO/IEC 9075-2:2016(E), 6.12, <case expression>
//
// Specify a conditional value.

type CaseExpression = CaseExpressionCoalesce
	| CaseExpressionNullIf
	| CaseExpressionSearched
	| CaseExpressionSimple

// CaseResult is the THEN or ELSE of a CASE, which may be an untyped NULL.
type CaseResult = NullSpecification | ValueExpression

fn (e CaseResult) pstr(params map[string]Value) string {
	return match e {
		NullSpecification, ValueExpression {
			e.pstr(params)
		}
	}
}

fn (e CaseExpression) pstr(params map[string]Value) string {
	return match e {
		CaseExpressionNullIf {
			'NULLIF(${e.a.pstr(params)}, ${e.b.pstr(params)})'
		}
		CaseExpressionCoalesce {
			'COALESCE(${e.exprs.map(it.pstr(params)).join(', ')})'
		}
		CaseExpressionSimple {
			whens := e.whens.map('WHEN ${it.operands.map(it.pstr(params)).join(', ')} THEN ${it.result.pstr(params)}')
			'CASE ${e.operand.pstr(params)} ${whens.join(' ')} ELSE ${e.else_result.pstr(params)} END'
		}
		CaseExpressionSearched {
			whens := e.whens.map('WHEN ${it.condition.pstr(params)} THEN ${it.result.pstr(params)}')
			'CASE ${whens.join(' ')} ELSE ${e.else_result.pstr(params)} END'
		}
	}
}

fn (e CaseExpression) compile(mut c Compiler) !CompileResult {
	// NEXT VALUE FOR can't be used anywhere in a CASE (including NULLIF and
	// COALESCE), since whether it's evaluated depends on the other values.
	//
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 2
	next_value_not_allowed := c.next_value_not_allowed
	if next_value_not_allowed == '' {
		c.next_value_not_allowed = match e {
			CaseExpressionNullIf { 'NULLIF' }
			CaseExpressionCoalesce { 'COALESCE' }
			CaseExpressionSimple, CaseExpressionSearched { 'CASE' }
		}
	}
	defer {
		c.next_value_not_allowed = next_value_not_allowed
	}

	match e {
		CaseExpressionNullIf {
			// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 5.a.xvi
			compiled_a, compiled_b := c.with_pair_types(e.a.compile(mut c)!, e.b.compile(mut c)!,
				same_type)

			// NULLIF(V1, V2) is CASE WHEN V1 = V2 THEN NULL ELSE V1 END, so the
			// values only need to be comparable, such as an INTEGER and a SMALLINT.
			//
			// ISO/IEC 9075-2:2016(E), 6.12, <case expression>, Syntax Rules, 1.c
			if !comparable_types(compiled_a.typ.typ, compiled_b.typ.typ) {
				return sqlstate_42804('in NULLIF', compiled_a.typ.str(), compiled_b.typ.str())
			}
			c.check_time_zone_comparison(compiled_a.typ, compiled_b.typ)!

			return CompileResult{
				run:          fn [compiled_a, compiled_b] (mut conn Connection, data Row, params map[string]Value) !Value {
					a := compiled_a.run(mut conn, data, params)!
					b := compiled_b.run(mut conn, data, params)!

					cmp := compare(conn, a, b)!
					if cmp == .is_equal {
						return new_null_value(a.typ.typ)
					}

					return a
				}
				typ:          compiled_a.typ
				contains_agg: compiled_a.contains_agg || compiled_b.contains_agg
			}
		}
		CaseExpressionCoalesce {
			// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 5.a.xvi
			compiled_exprs := c.with_types(e.exprs.map(it.compile(mut c)!), same_type)

			// ISO/IEC 9075-2:2016(E), 6.12, <case expression>, Syntax Rules, 5: the
			// result has the combined type of all the arguments (9.5).
			mut typ := Type{compiled_exprs[0].typ.typ, compiled_exprs[0].typ.size, compiled_exprs[0].typ.scale, false}
			mut contains_agg := compiled_exprs[0].contains_agg
			for i, compiled_expr in compiled_exprs[1..] {
				typ = combine_types(typ, compiled_expr.typ) or {
					return sqlstate_42804('in argument ${i + 2} of COALESCE', typ.str(),
						compiled_expr.typ.str())
				}
				contains_agg = contains_agg || compiled_expr.contains_agg
			}

			return CompileResult{
				run:          fn [compiled_exprs, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
					for compiled_expr in compiled_exprs {
						value := compiled_expr.run(mut conn, data, params)!

						if !value.is_null {
							return convert_to_combined_type(mut conn, 'in COALESCE', value,
								typ)!
						}
					}

					return new_null_value(typ.typ)
				}
				typ:          typ
				contains_agg: contains_agg
			}
		}
		CaseExpressionSimple {
			// The case operand is compiled (and evaluated) once, rather than once
			// for each <when operand> of the equivalent searched CASE (Syntax
			// Rules, 2.i). That's the same, since it must be deterministic and
			// can't modify SQL-data (Syntax Rules, 2.a and 2.b).
			compiled_operand := e.operand.compile_fields(mut c)!
			mut operand := &CaseOperandValues{}
			mut fields := []CompileResult{}
			for i, compiled_field in compiled_operand {
				fields << operand.field(compiled_field, i)
			}
			c.case_operands << fields
			defer {
				c.case_operands.pop()
			}

			mut contains_agg := compiled_operand.any(it.contains_agg)
			mut compiled_whens := [][]CompileResult{}
			for when in e.whens {
				mut compiled_when := []CompileResult{}
				for when_operand in when.operands {
					compiled := when_operand.predicate.compile(mut c)!
					compiled_when << compiled
					contains_agg = contains_agg || compiled.contains_agg
				}
				compiled_whens << compiled_when
			}

			compiled_results, results_contain_agg := compile_case_results(mut c,
				e.whens.map(it.result), e.else_result)!

			return CompileResult{
				run:          fn [compiled_operand, mut operand, compiled_whens, compiled_results] (mut conn Connection, data Row, params map[string]Value) !Value {
					operand.values = run_fields(mut conn, compiled_operand, data, params)!

					// A WHEN matches if any of its <when operand>s is TRUE.
					for i, compiled_when in compiled_whens {
						for compiled in compiled_when {
							value := compiled.run(mut conn, data, params)!
							if !value.is_null && value.bool_value() == .is_true {
								return compiled_results[i].run(mut conn, data, params)!
							}
						}
					}

					return compiled_results.last().run(mut conn, data, params)!
				}
				typ:          compiled_results[0].typ
				contains_agg: contains_agg || results_contain_agg
			}
		}
		CaseExpressionSearched {
			mut contains_agg := false
			mut compiled_conditions := []CompileResult{}
			for when in e.whens {
				compiled_condition := c.with_boolean_type(when.condition.compile(mut c)!)
				if compiled_condition.typ.typ != .is_boolean {
					return sqlstate_42804('in CASE WHEN', 'BOOLEAN', compiled_condition.typ.str())
				}

				compiled_conditions << compiled_condition
				contains_agg = contains_agg || compiled_condition.contains_agg
			}

			compiled_results, results_contain_agg := compile_case_results(mut c,
				e.whens.map(it.result), e.else_result)!

			return CompileResult{
				run:          fn [compiled_conditions, compiled_results] (mut conn Connection, data Row, params map[string]Value) !Value {
					// The result is from the first WHEN that is TRUE. FALSE and UNKNOWN
					// (NULL) are both skipped.
					for i, compiled_condition in compiled_conditions {
						value := compiled_condition.run(mut conn, data, params)!
						if !value.is_null && value.bool_value() == .is_true {
							return compiled_results[i].run(mut conn, data, params)!
						}
					}

					return compiled_results.last().run(mut conn, data, params)!
				}
				typ:          compiled_results[0].typ
				contains_agg: contains_agg || results_contain_agg
			}
		}
	}
}

// compile_case_results compiles each THEN and the ELSE (last) of a CASE. They
// are all converted to the combined type of the results that are not NULL.
//
// ISO/IEC 9075-2:2016(E), 6.12, <case expression>, Syntax Rules, 3 and 5
fn compile_case_results(mut c Compiler, thens []CaseResult, else_result CaseResult) !([]CompileResult, bool) {
	mut results := thens.clone()
	results << else_result

	mut compiled := []CompileResult{}
	for result in results {
		if result is ValueExpression {
			compiled << result.compile(mut c)!
		}
	}

	// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 5.a.xvii
	compiled = c.with_types(compiled, same_type)

	mut typ := ?Type(none)
	mut contains_agg := false
	for compiled_result in compiled {
		contains_agg = contains_agg || compiled_result.contains_agg

		if t := typ {
			typ = combine_types(t, compiled_result.typ) or {
				return sqlstate_42804('in CASE', t.str(), compiled_result.typ.str())
			}
		} else {
			typ = Type{compiled_result.typ.typ, compiled_result.typ.size, compiled_result.typ.scale, false}
		}
	}

	// ISO/IEC 9075-2:2016(E), 6.12, <case expression>, Syntax Rules, 3: at least
	// one result must not be NULL so that the CASE has a type.
	combined_type := typ or { return sqlstate_42601('CASE needs at least one result that is not NULL') }

	mut i := 0
	mut converted := []CompileResult{}
	for result in results {
		if result is NullSpecification {
			converted << CompileResult{
				run:          fn [combined_type] (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_null_value(combined_type.typ)
				}
				typ:          combined_type
				contains_agg: false
			}
			continue
		}

		compiled_result := compiled[i]
		i++
		converted << CompileResult{
			run:          fn [compiled_result, combined_type] (mut conn Connection, data Row, params map[string]Value) !Value {
				value := compiled_result.run(mut conn, data, params)!
				if value.is_null {
					return new_null_value(combined_type.typ)
				}

				return convert_to_combined_type(mut conn, 'in CASE', value, combined_type)!
			}
			typ:          combined_type
			contains_agg: compiled_result.contains_agg
		}
	}

	return converted, contains_agg
}

// a and b are references because a ValueExpression can contain a CaseExpression,
// and V stores a sum type's value inline.
struct CaseExpressionNullIf {
	a &ValueExpression
	b &ValueExpression
}

fn new_case_expression_null_if(a ValueExpression, b ValueExpression) CaseExpressionNullIf {
	return CaseExpressionNullIf{&a, &b}
}

struct CaseExpressionCoalesce {
	exprs []ValueExpression
}

// CaseExpressionSimple is "CASE operand WHEN value THEN result ... END". When
// there is no ELSE the else_result is NULL (6.12, Syntax Rules, 4).
struct CaseExpressionSimple {
	operand     &RowValueConstructorPredicand
	whens       []CaseExpressionSimpleWhen
	else_result &CaseResult
}

struct CaseExpressionSimpleWhen {
	operands []CaseWhenOperand
	result   CaseResult
}

// CaseWhenOperand is a <when operand> as the predicate that it's equivalent to,
// which has the case operand (CaseOperand) on the left. is_value is true if it's
// a <row value predicand> (WO), so the predicate is "CO = WO".
//
// ISO/IEC 9075-2:2016(E), 6.12, <case expression>, Syntax Rules, 2.f
struct CaseWhenOperand {
	predicate Predicate
	is_value  bool
}

fn (e CaseWhenOperand) pstr(params map[string]Value) string {
	if e.is_value {
		return (e.predicate as ComparisonPredicate).right.pstr(params)
	}

	// The case operand isn't shown, so this is just the <predicate part 2>.
	return e.predicate.pstr(params).trim_space()
}

// CaseOperand is the case operand of a simple CASE, where it's used in each
// <when operand>. It's evaluated by the CASE (see CaseOperandValues).
struct CaseOperand {}

// case_operand is a CaseOperand as the left of a predicate.
fn case_operand() RowValueConstructorPredicand {
	return RowValueConstructorPredicand(BooleanPredicand(NonparenthesizedValueExpressionPrimary(CaseOperand{})))
}

fn (e CaseOperand) pstr(params map[string]Value) string {
	return ''
}

// compile is for a predicate that needs a single value. The fields are in
// Compiler.case_operands, see compile_fields.
fn (e CaseOperand) compile(mut c Compiler) !CompileResult {
	fields := c.case_operands.last()
	if fields.len != 1 {
		return sqlstate_42601('a row value cannot be used here')
	}

	return fields[0]
}

// is_case_operand is true for a CaseOperand.
fn (e RowValueConstructorPredicand) is_case_operand() bool {
	return e is BooleanPredicand && e is NonparenthesizedValueExpressionPrimary
		&& e is CaseOperand
}

// CaseOperandValues is the value of each field of the case operand, for the
// row that the CASE is being evaluated for.
@[heap]
struct CaseOperandValues {
mut:
	values []Value
}

// field returns the value of the field (at index) of the case operand, that's
// compiled as compiled_field.
fn (operand &CaseOperandValues) field(compiled_field CompileResult, index int) CompileResult {
	return CompileResult{
		run:            fn [operand, index] (mut conn Connection, data Row, params map[string]Value) !Value {
			return operand.values[index]
		}
		typ:            compiled_field.typ
		contains_agg:   false
		null_parameter: compiled_field.null_parameter
	}
}

fn new_case_expression_simple(operand RowValueConstructorPredicand, whens []CaseExpressionSimpleWhen, else_result CaseResult) CaseExpressionSimple {
	return CaseExpressionSimple{&operand, whens, &else_result}
}

// CaseExpressionSearched is "CASE WHEN condition THEN result ... END". When
// there is no ELSE the else_result is NULL (6.12, Syntax Rules, 4).
struct CaseExpressionSearched {
	whens       []CaseExpressionSearchedWhen
	else_result &CaseResult
}

struct CaseExpressionSearchedWhen {
	condition BooleanValueExpression
	result    CaseResult
}

fn new_case_expression_searched(whens []CaseExpressionSearchedWhen, else_result CaseResult) CaseExpressionSearched {
	return CaseExpressionSearched{whens, &else_result}
}

// comparable_types is true when values of the types can be compared, such as
// two numbers or two character strings (4.2 to 4.7).
fn comparable_types(t1 SQLType, t2 SQLType) bool {
	return (t1.is_number() && t2.is_number()) || (t1.is_string() && t2.is_string())
		|| (t1 == .is_boolean && t2 == .is_boolean) || (t1.is_datetime() && t2.is_datetime())
}
