module vsql

// ISO/IEC 9075-1:2003(E), 8.5, SQL flagger
//
// An SQL Flagger identifies SQL language that isn't Core SQL, so that it can be
// moved to another SQL-implementation. vsql provides "Core SQL Flagging" with
// "Syntax Only" checking (Feature F812, "Basic flagging"), and also "SQL
// Feature Flagging": each statement is flagged with the optional features that
// it uses.
//
// The features are recorded by the grammar actions (see flag) of the language
// that each Conformance Rule of ISO/IEC 9075-2 doesn't allow without a
// feature. An implementation-defined feature (an extension that only vsql has)
// has a Feature ID whose letter is "V" (see ISO/IEC 9075-1:2003(E), 6.3.7,
// Feature ID and Feature Name). It's VXXX-YY, where VXXX is a concept (of the
// standard, such as tables, or one that only vsql has, such as EXPLAIN) and YY
// is each extension of it.

// The implementation-defined features, which are also listed in the SQL
// Flagging docs. They're flagged, which is implementation-defined (ISO/IEC
// 9075-1:2003(E), 8.4.8, Extensions and options).
//
// V001: EXPLAIN.
// V001-01: EXPLAIN before a query (such as SELECT or VALUES).
// V001-02: EXPLAIN before a searched DELETE.
// V001-03: EXPLAIN before a searched UPDATE.
//
// V002: Tables.
// V002-01: DROP TABLE without a <drop behavior> (it's RESTRICT).
// V002-02: DROP COLUMN without a <drop behavior> (it's RESTRICT).
// V002-03: DROP CONSTRAINT without a <drop behavior> (it's RESTRICT).
//
// V003: Sequence generators.
// V003-01: DROP SEQUENCE without a <drop behavior> (it's RESTRICT).
//
// V004: Cursors.
// V004-01: DECLARE CURSOR outside of an SQL-client module.
// V004-02: OPEN outside of an SQL-client module.
// V004-03: FETCH without INTO (the row is returned).
// V004-04: CLOSE outside of an SQL-client module.
// V004-05: DELETE WHERE CURRENT OF outside of an SQL-client module.
// V004-06: UPDATE WHERE CURRENT OF outside of an SQL-client module.
const vsql_explain_query = 'V001-01'
const vsql_explain_delete = 'V001-02'
const vsql_explain_update = 'V001-03'
const vsql_drop_table_behavior = 'V002-01'
const vsql_drop_column_behavior = 'V002-02'
const vsql_drop_constraint_behavior = 'V002-03'
const vsql_drop_sequence_behavior = 'V003-01'
const vsql_declare_cursor = 'V004-01'
const vsql_open_cursor = 'V004-02'
const vsql_fetch_without_into = 'V004-03'
const vsql_close_cursor = 'V004-04'
const vsql_delete_positioned = 'V004-05'
const vsql_update_positioned = 'V004-06'

// flag records that the statement being parsed uses a feature outside of Core
// SQL, such as "F591". It's called by the grammar actions.
fn flag(mut yylex YYLexer, feature string) {
	if mut yylex is Lexer {
		yylex.features << feature
	}
}

// flag_if records a feature if cond is true.
fn flag_if(mut yylex YYLexer, cond bool, feature string) {
	if cond {
		flag(mut yylex, feature)
	}
}

// flag_identifier flags an identifier (a <regular identifier>, or a
// <delimited identifier> that's in quotes) that is too long for Core SQL
// (ISO/IEC 9075-2:2016(E), 5.2, <token> and <separator>, Conformance Rules, 1
// and 2). A regular identifier of 18 characters is also flagged, which is
// #738.
//
// INFORMATION_SCHEMA has 18 characters, so a reference to one of its views is
// flagged with F391. That's what meets these rules (#737):
//
// ISO/IEC 9075-11:2008(E), 5.21, COLUMNS view, Conformance Rules, 1
// ISO/IEC 9075-11:2008(E), 5.32, KEY_COLUMN_USAGE view, Conformance Rules, 2
// ISO/IEC 9075-11:2008(E), 5.37, REFERENTIAL_CONSTRAINTS view, Conformance Rules, 1
// ISO/IEC 9075-11:2008(E), 5.61, TABLES view, Conformance Rules, 1
fn flag_identifier(mut yylex YYLexer, identifier string) {
	if identifier.starts_with('"') {
		body := identifier[1..identifier.len - 1].replace('""', '"')
		flag_if(mut yylex, body.runes().len > 18, 'F391')
	} else {
		flag_if(mut yylex, identifier.runes().len >= 18, 'F391')
	}
}

// flag_datetime_literal flags the value of a <time literal> (or a <timestamp
// literal> if is_timestamp) that has a <seconds fraction> or <time zone
// interval> that Core SQL doesn't allow (ISO/IEC 9075-2:2016(E), 5.3,
// <literal>, Conformance Rules, 2, 3 and 7).
fn flag_datetime_literal(mut yylex YYLexer, value string, is_timestamp bool) {
	time_part := value.trim_space().all_after_last(' ')
	time_zone := time_part.index_any('+-')
	fraction := if time_zone >= 0 { time_part[..time_zone] } else { time_part }.all_after('.')
	flag_if(mut yylex, time_zone >= 0, 'F411')
	if fraction != time_part {
		flag_if(mut yylex, !is_timestamp || fraction.len > 6, 'F555')
	}
}

// QueryContext is where a <query expression> is, which decides the features
// needed for its ORDER BY, OFFSET and FETCH FIRST.
//
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Conformance Rules, 11-21
enum QueryContext {
	// A <cursor specification>, such as the query of a statement.
	cursor
	// A <subquery> that's contained in another query.
	subquery
	// A parenthesized <query expression> that's a <query primary>.
	query_primary
}

fn flag_query_expression(mut yylex YYLexer, e QueryExpression, context QueryContext) {
	has_offset := e.offset != none
	has_fetch := e.fetch != none
	match context {
		.cursor {
			flag_if(mut yylex, has_offset, 'F861')
			flag_if(mut yylex, has_fetch, 'F857')
		}
		.subquery {
			flag_if(mut yylex, e.order.len > 0, 'F850')
			flag_if(mut yylex, e.order.len > 0, 'F851')
			flag_if(mut yylex, has_offset, 'F861')
			flag_if(mut yylex, has_offset, 'F862')
			flag_if(mut yylex, has_fetch, 'F857')
			flag_if(mut yylex, has_fetch, 'F858')
		}
		.query_primary {
			flag_if(mut yylex, e.order.len > 0, 'F855')
			flag_if(mut yylex, has_offset, 'F863')
			flag_if(mut yylex, has_fetch, 'F856')
		}
	}
}

// flag_updatability_clause flags a FOR UPDATE of a query with an ORDER BY. A
// positioned UPDATE of such a cursor needs the same feature, so it's flagged
// here instead.
//
// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 14.13, <update statement: positioned>, Conformance Rules, 1
fn flag_updatability_clause(mut yylex YYLexer, e QueryExpression, updatability UpdatabilityClause) {
	flag_if(mut yylex, updatability.for_update && e.order.len > 0, 'F831')
}

// flag_row_count flags a <fetch first row count> (F860) or <offset row count>
// (F865) that isn't an <unsigned integer>.
fn flag_row_count(mut yylex YYLexer, count ValueSpecification, feature string) {
	if count is Value {
		if count.typ.typ in [.is_smallint, .is_integer, .is_bigint] && count.int_value() >= 0 {
			return
		}
	}
	flag(mut yylex, feature)
}

// primary_of returns the <nonparenthesized value expression primary> that is
// an entire expression (such as a column reference or a literal), or none if
// it's anything else.
fn primary_of(e RowValueConstructorPredicand) ?NonparenthesizedValueExpressionPrimary {
	return match e {
		BooleanPredicand {
			if e is NonparenthesizedValueExpressionPrimary { e } else { none }
		}
		CommonValueExpression {
			primary := common_primary_of(e)?
			if primary is NonparenthesizedValueExpressionPrimary { primary } else { none }
		}
	}
}

// common_primary_of returns the <value expression primary> that is an entire
// expression, or none if it's anything else.
fn common_primary_of(e CommonValueExpression) ?ValueExpressionPrimary {
	match e {
		CharacterValueExpression {
			character := CharacterValueExpression(e)
			if character is CharacterPrimary {
				primary := CharacterPrimary(character)
				if primary is ValueExpressionPrimary {
					return ValueExpressionPrimary(primary)
				}
			}
		}
		DatetimePrimary {
			datetime := DatetimePrimary(e)
			if datetime is ValueExpressionPrimary {
				return ValueExpressionPrimary(datetime)
			}
		}
		// A <numeric value expression> is always an operation (or a numeric
		// function), since a <value expression primary> on its own is parsed
		// as a <datetime primary> wherever either is allowed (see
		// datetime_primary in grammar.y).
		NumericValueExpression {}
	}

	return none
}

// is_parenthesized is true if an expression is in parentheses, such as "(1)".
fn is_parenthesized(e CommonValueExpression) bool {
	primary := common_primary_of(e) or { return false }

	return primary is ParenthesizedValueExpression
}

// is_value_specification is true if an expression is a <value specification>,
// such as a literal or a parameter.
fn is_value_specification(e RowValueConstructorPredicand) bool {
	primary := primary_of(e) or { return false }

	return primary is ValueSpecification
}

// is_character_value_specification is true if a <character value expression>
// is a <value specification>, such as a literal or a parameter.
fn is_character_value_specification(e CharacterValueExpression) bool {
	return is_value_specification(RowValueConstructorPredicand(CommonValueExpression(e)))
}

// is_column_reference is true if an expression is a <column reference>.
fn is_column_reference(e RowValueConstructorPredicand) bool {
	primary := primary_of(e) or { return false }

	return primary is Identifier
}

// flag_exists flags an EXISTS whose query has a <select list> that isn't "*"
// or a single column.
//
// ISO/IEC 9075-2:2016(E), 8.10, <exists predicate>, Conformance Rules, 1
fn flag_exists(mut yylex YYLexer, e QueryExpression) {
	if e.body is QuerySpecification {
		exprs := e.body.exprs
		flag_if(mut yylex, exprs is []SelectSublist && exprs.len != 1, 'T501')
	}
}

// flag_unique_columns flags a UNIQUE constraint (other than a PRIMARY KEY) on
// a column of the table definition that isn't NOT NULL.
//
// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>, Conformance Rules, 2
fn flag_unique_columns(mut yylex YYLexer, elements []TableElement) {
	mut not_null := []string{}
	for element in elements {
		if element is Column && element.not_null {
			not_null << element.name.sub_entity_name
		}
	}
	for element in elements {
		if element is UniqueConstraintDefinition && !element.is_primary_key {
			for column in element.columns {
				flag_if(mut yylex, column.sub_entity_name !in not_null, 'T591')
			}
		}
	}
}

// value_primary_of returns the <nonparenthesized value expression primary>
// that is an entire <value expression>, or none if it's anything else. A value
// on its own (such as a column reference) may be parsed as a <boolean value
// expression>.
fn value_primary_of(e ValueExpression) ?NonparenthesizedValueExpressionPrimary {
	match e {
		BooleanValueExpression {
			if is_boolean_operation(e) {
				return none
			}
			primary := *e.term.factor.expr
			if primary is BooleanPredicand {
				predicand := BooleanPredicand(primary)
				if predicand is NonparenthesizedValueExpressionPrimary {
					return NonparenthesizedValueExpressionPrimary(predicand)
				}
			}
			return none
		}
		CommonValueExpression {
			return primary_of(RowValueConstructorPredicand(e))
		}
	}
}

// is_dynamic_parameter is true if an expression is a <dynamic parameter
// specification> ("?").
fn is_dynamic_parameter(e ValueExpression) bool {
	primary := value_primary_of(e) or { return false }
	if primary is ValueSpecification {
		spec := ValueSpecification(primary)
		if spec is GeneralValueSpecification {
			return GeneralValueSpecification(spec) is DynamicParameterSpecification
		}
	}

	return false
}

// is_boolean_operation is true if a <boolean value expression> is an operation
// (such as a comparison, AND or IS TRUE), so its value is a BOOLEAN. A column
// reference (or other value) is also parsed as a <boolean value expression>
// when it could be one, but its type isn't known until it's resolved. So a
// boolean predicand is only flagged with T031 when it contains an operation.
//
// ISO/IEC 9075-2:2016(E), 7.1, <row value constructor>, Conformance Rules, 5
fn is_boolean_operation(e BooleanValueExpression) bool {
	if e.expr != none || e.term.term != none {
		return true
	}
	test := e.term.factor
	if test.value != none || test.inverse {
		return true
	}
	primary := *test.expr
	if primary is BooleanPredicand {
		predicand := BooleanPredicand(primary)
		if predicand is BooleanValueExpression {
			return is_boolean_operation(predicand)
		}
		return false
	}

	return true
}

// is_parenthesized_boolean is true if a <boolean value expression> is in
// parentheses, such as "(x = 1)" or "(1)".
fn is_parenthesized_boolean(e BooleanValueExpression) bool {
	if e.expr != none || e.term.term != none {
		return false
	}
	test := e.term.factor
	if test.value != none || test.inverse {
		return false
	}
	primary := *test.expr
	if primary is BooleanPredicand {
		return BooleanPredicand(primary) is BooleanValueExpression
	}

	return false
}

// flag_set_quantifier flags a <general set function> with a <set quantifier>:
// COUNT(ALL ...) needs F441, and DISTINCT of anything other than a column
// reference needs F561.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 3 and 4
fn flag_set_quantifier(mut yylex YYLexer, function string, distinct bool, e ValueExpression) {
	if !distinct {
		flag_if(mut yylex, function == 'COUNT', 'F441')
		return
	}
	primary := value_primary_of(e) or {
		flag(mut yylex, 'F561')
		return
	}
	flag_if(mut yylex, primary !is Identifier, 'F561')
}

// token_features flags the language that's only allowed without a feature
// when it's not contained in another construct, which is easier to find in
// the tokens of a statement that has been parsed:
//
// - F671: A <check constraint definition> that contains a <query expression>.
// - F672: A <check constraint definition> that contains CURRENT_DATE,
// CURRENT_TIMESTAMP or LOCALTIMESTAMP.
// - F801: A <query specification> that contains more than one DISTINCT, other
// than in a query that it contains.
//
// ISO/IEC 9075-2:2016(E), 11.9, <check constraint definition>, Conformance Rules, 1 and 2
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Conformance Rules, 1
fn token_features(tokens []Token) []string {
	mut features := []string{}
	for i, token in tokens {
		if token.token == token_check && i + 1 < tokens.len
			&& tokens[i + 1].token == token_operator_left_paren {
			for t in tokens[i + 1..closing_paren(tokens, i + 1)] {
				if t.token in [token_select, token_values] {
					features << 'F671'
				}
				if t.token in [token_current_date, token_current_timestamp, token_localtimestamp] {
					features << 'F672'
				}
			}
		}
		if token.token == token_select && distinct_count(tokens, i + 1) > 1 {
			features << 'F801'
		}
	}

	return features
}

// closing_paren returns the position of the ")" that closes the "(" at
// tokens[start]. The statement has been parsed, so there is one.
fn closing_paren(tokens []Token, start int) int {
	mut depth := 0
	mut i := start
	for {
		match tokens[i].token {
			token_operator_left_paren, token_operator_left_paren_asterisk { depth++ }
			token_operator_right_paren { depth-- }
			else {}
		}
		if depth == 0 {
			return i
		}
		i++
	}
}

// distinct_count returns the number of DISTINCTs in the <query specification>
// that starts at tokens[start] (after its SELECT), not counting the queries
// that it contains.
fn distinct_count(tokens []Token, start int) int {
	mut count := 0
	mut depth := 0
	mut i := start
	for i < tokens.len {
		match tokens[i].token {
			token_operator_left_paren, token_operator_left_paren_asterisk {
				if i + 1 < tokens.len && tokens[i + 1].token in [token_select, token_values] {
					i = closing_paren(tokens, i)
				} else {
					depth++
				}
			}
			token_operator_right_paren {
				depth--
				if depth < 0 {
					break
				}
			}
			token_union, token_except, token_intersect, token_order, token_offset, token_fetch {
				if depth == 0 {
					break
				}
			}
			token_distinct {
				count++
			}
			else {}
		}
		i++
	}

	return count
}

// features returns the Feature IDs outside of Core SQL that the statement uses
// (see the SQL Compliance docs), sorted and without duplicates. A statement
// that only uses Core SQL returns an empty array.
//
// IDs that start with "V" are features that only vsql has, such as "V001-01"
// for EXPLAIN.
pub fn (p PreparedStmt) features() []string {
	mut features := []string{}
	for feature in p.features {
		if feature !in features {
			features << feature
		}
	}
	features.sort()

	return features
}
