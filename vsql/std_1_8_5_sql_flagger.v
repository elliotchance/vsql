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
// Feature ID and Feature Name). It's VXXX-YY, where VXXX is what's extended and
// YY is each extension of it. The first digit of VXXX is the kind of thing that's
// extended: 0 for a statement that isn't in the standard, 1 for a statement of the
// standard (with its aliases), 2 for a query, 3 for an operator or predicate, and
// 4 for a function, by its category in the Functions docs.

// The implementation-defined features, which are also listed in the SQL
// Flagging docs. They're flagged, which is implementation-defined (ISO/IEC
// 9075-1:2003(E), 8.4.8, Extensions and options).
//
// V001: EXPLAIN.
// V001-01: EXPLAIN before a query (such as SELECT or VALUES).
// V001-02: EXPLAIN before a searched DELETE.
// V001-03: EXPLAIN before a searched UPDATE.
//
// V101: CREATE SCHEMA.
// V101-01: CREATE SCHEMA IF NOT EXISTS.
//
// V102: DROP SCHEMA.
// V102-01: DROP SCHEMA IF EXISTS.
//
// V103: CREATE TABLE.
// V103-01: CREATE TABLE IF NOT EXISTS.
//
// V104: DROP TABLE.
// V104-01: DROP TABLE without a <drop behavior> (it's RESTRICT).
// V104-02: DROP TABLE IF EXISTS.
//
// V105: ALTER TABLE.
// V105-01: DROP COLUMN without a <drop behavior> (it's RESTRICT).
// V105-02: DROP CONSTRAINT without a <drop behavior> (it's RESTRICT).
//
// V106: CREATE SEQUENCE.
// V106-01: CREATE SEQUENCE IF NOT EXISTS.
//
// V107: DROP SEQUENCE.
// V107-01: DROP SEQUENCE without a <drop behavior> (it's RESTRICT).
// V107-02: DROP SEQUENCE IF EXISTS.
//
// V108: DECLARE CURSOR.
// V108-01: DECLARE CURSOR outside of an SQL-client module.
//
// V109: OPEN.
// V109-01: OPEN outside of an SQL-client module.
//
// V110: FETCH.
// V110-01: FETCH without INTO (the row is returned).
//
// V111: CLOSE.
// V111-01: CLOSE outside of an SQL-client module.
//
// V112: DELETE.
// V112-01: DELETE WHERE CURRENT OF outside of an SQL-client module.
//
// V113: UPDATE.
// V113-01: UPDATE WHERE CURRENT OF outside of an SQL-client module.
//
// V114: START TRANSACTION.
// V114-01: BEGIN instead of START TRANSACTION.
//
// V115: COMMIT.
// V115-01: COMMIT TRANSACTION instead of COMMIT.
// V115-02: END instead of COMMIT.
//
// V116: ROLLBACK.
// V116-01: ROLLBACK TRANSACTION instead of ROLLBACK.
// V116-02: ABORT instead of ROLLBACK.
//
// V201: FROM.
// V201-01: SELECT without a FROM clause.
// V201-02: A derived table without a correlation name.
//
// V202: ORDER BY.
// V202-01: A sort key without a column reference.
// V202-02: A sort key that contains a subquery.
// V202-03: A sort key that contains an aggregate function.
//
// V301: Comparison operators.
// V301-01: != as an alias for <>.
//
// V302: ILIKE.
// V302-01: ILIKE and NOT ILIKE (a case-insensitive LIKE).
//
// V402: Date and time functions.
// V402-01: NOW() instead of CURRENT_TIMESTAMP.
//
// V403: Mathematical functions.
// V403-01: MOD with an argument that has a scale or is approximate.
//
// V404: String functions.
// V404-01: TRIM with only FROM.
const vsql_explain_query = 'V001-01'
const vsql_explain_delete = 'V001-02'
const vsql_explain_update = 'V001-03'
const vsql_create_schema_if_not_exists = 'V101-01'
const vsql_drop_schema_if_exists = 'V102-01'
const vsql_create_table_if_not_exists = 'V103-01'
const vsql_drop_table_behavior = 'V104-01'
const vsql_drop_table_if_exists = 'V104-02'
const vsql_drop_column_behavior = 'V105-01'
const vsql_drop_constraint_behavior = 'V105-02'
const vsql_create_sequence_if_not_exists = 'V106-01'
const vsql_drop_sequence_behavior = 'V107-01'
const vsql_drop_sequence_if_exists = 'V107-02'
const vsql_declare_cursor = 'V108-01'
const vsql_open_cursor = 'V109-01'
const vsql_fetch_without_into = 'V110-01'
const vsql_close_cursor = 'V111-01'
const vsql_delete_positioned = 'V112-01'
const vsql_update_positioned = 'V113-01'
const vsql_begin = 'V114-01'
const vsql_commit_transaction = 'V115-01'
const vsql_end = 'V115-02'
const vsql_rollback_transaction = 'V116-01'
const vsql_abort = 'V116-02'
const vsql_select_without_from = 'V201-01'
const vsql_derived_table_without_name = 'V201-02'
const vsql_sort_key_without_column = 'V202-01'
const vsql_sort_key_subquery = 'V202-02'
const vsql_sort_key_aggregate = 'V202-03'
const vsql_bang_equals = 'V301-01'
const vsql_ilike = 'V302-01'
const vsql_now = 'V402-01'
const vsql_mod_not_integer = 'V403-01'
const vsql_trim_only_from = 'V404-01'

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
	// The <query expression> of a <from subquery>, which isn't a <cursor
	// specification> and isn't contained in another <query expression>.
	from_subquery
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
		.from_subquery {
			flag_if(mut yylex, e.order.len > 0, 'F850')
			flag_if(mut yylex, has_offset, 'F861')
			flag_if(mut yylex, has_fetch, 'F857')
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

// SortKeyPart is what a <sort key> must, or can't, contain.
//
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 28.b
enum SortKeyPart {
	column_reference
	query_expression
	set_function
}

// parsed_sort_key_part records a part that has been parsed, wherever it is,
// since the actions for it don't know if they're in a sort key.
fn parsed_sort_key_part(mut yylex YYLexer, part SortKeyPart) {
	if mut yylex is Lexer {
		yylex.sort_key_parts << part
	}
}

// start_sort_key is called before a <sort key> is parsed. It can contain a
// subquery that has its own sort keys, so they're a stack.
fn start_sort_key(mut yylex YYLexer) {
	if mut yylex is Lexer {
		yylex.sort_key_starts << yylex.sort_key_parts.len
	}
}

// flag_sort_key flags a <sort key> that has just been parsed from the parts
// since it started.
fn flag_sort_key(mut yylex YYLexer) {
	if mut yylex is Lexer {
		parts := yylex.sort_key_parts[yylex.sort_key_starts.pop()..]
		flag_if(mut yylex, SortKeyPart.column_reference !in parts, vsql_sort_key_without_column)
		flag_if(mut yylex, SortKeyPart.query_expression in parts, vsql_sort_key_subquery)
		flag_if(mut yylex, SortKeyPart.set_function in parts, vsql_sort_key_aggregate)
	}
}

// flag_mod_argument flags an argument of MOD that contains a literal with a
// scale or an approximate literal. It's only flagged from the syntax, so an
// argument of a type like that for any other reason (such as a column) isn't.
//
// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>, Syntax Rules, 12
fn flag_mod_argument(mut yylex YYLexer, e NumericValueExpression) {
	flag_if(mut yylex, numeric_has_non_integer_literal(e), vsql_mod_not_integer)
}

fn numeric_has_non_integer_literal(e NumericValueExpression) bool {
	if n := e.n {
		if numeric_has_non_integer_literal(n) {
			return true
		}
	}

	return term_has_non_integer_literal(e.term)
}

fn term_has_non_integer_literal(e Term) bool {
	if term := e.term {
		if term_has_non_integer_literal(term) {
			return true
		}
	}

	return primary_has_non_integer_literal(e.factor)
}

fn primary_has_non_integer_literal(e NumericPrimary) bool {
	if e is SignedValueExpressionPrimary {
		return primary_has_non_integer_literal(*e.e)
	}
	if e is ValueExpressionPrimary && e is ParenthesizedValueExpression {
		inner := *e.e
		if inner is CommonValueExpression && inner is NumericValueExpression {
			return numeric_has_non_integer_literal(inner)
		}
		primary := value_primary_of(inner) or { return false }

		return primary is ValueSpecification && primary is Value
			&& is_non_integer_literal(primary)
	}
	value := e.value() or { return false }

	return is_non_integer_literal(value)
}

fn is_non_integer_literal(v Value) bool {
	return v.typ.typ in [.is_real, .is_double_precision] || v.typ.scale > 0
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
		// function), since a <value expression primary> on its own is only a
		// common_value_expression when it's in parentheses, and then it's a
		// <datetime primary> (see common_value_expression).
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
	dynamic_parameter_of(e) or { return false }

	return true
}

// dynamic_parameter_of returns the <dynamic parameter specification> that is an
// entire expression, or none if it's anything else.
fn dynamic_parameter_of(e ValueExpression) ?DynamicParameterSpecification {
	primary := value_primary_of(e)?
	if primary is ValueSpecification {
		spec := ValueSpecification(primary)
		if spec is GeneralValueSpecification {
			general := GeneralValueSpecification(spec)
			if general is DynamicParameterSpecification {
				return general
			}
		}
	}

	return none
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
