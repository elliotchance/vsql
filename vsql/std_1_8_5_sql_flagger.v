module vsql

import arrays

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
// feature. The rules that depend on what a name refers to are found by planning
// the statement with the catalog (see Connection.resolved_features). An
// implementation-defined feature (an extension that only vsql has)
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
// V001-04: EXPLAIN before a MERGE.
//
// V002: CREATE INDEX.
// V002-01: CREATE INDEX.
// V002-02: CREATE UNIQUE INDEX.
// V002-03: CREATE INDEX IF NOT EXISTS.
//
// V003: DROP INDEX.
// V003-01: DROP INDEX.
// V003-02: DROP INDEX IF EXISTS.
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
// V117: PREPARE.
// V117-01: PREPARE from a literal, rather than a host parameter.
//
// V118: EXECUTE IMMEDIATE.
// V118-01: EXECUTE IMMEDIATE of a literal, rather than a host parameter.
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
// V203: LIMIT.
// V203-01: LIMIT instead of FETCH FIRST.
// V203-02: OFFSET without ROW or ROWS.
// V203-03: LIMIT offset, count.
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
const vsql_explain_merge = 'V001-04'
const vsql_create_index = 'V002-01'
const vsql_create_unique_index = 'V002-02'
const vsql_create_index_if_not_exists = 'V002-03'
const vsql_drop_index = 'V003-01'
const vsql_drop_index_if_exists = 'V003-02'
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
const vsql_prepare_literal = 'V117-01'
const vsql_execute_immediate_literal = 'V118-01'
const vsql_select_without_from = 'V201-01'
const vsql_derived_table_without_name = 'V201-02'
const vsql_sort_key_without_column = 'V202-01'
const vsql_sort_key_subquery = 'V202-02'
const vsql_sort_key_aggregate = 'V202-03'
const vsql_limit = 'V203-01'
const vsql_offset_without_rows = 'V203-02'
const vsql_limit_offset_count = 'V203-03'
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
// #738. That's also why "INFORMATION_SCHEMA" is flagged with F391, but the views
// that need F391 are flagged by what they are (see
// information_schema_features).
fn flag_identifier(mut yylex YYLexer, identifier string) {
	flag_if(mut yylex, is_long_identifier(identifier), 'F391')
}

// is_long_identifier is true if an identifier (with the quotes of a <delimited
// identifier>) needs F391, see flag_identifier.
fn is_long_identifier(identifier string) bool {
	if identifier.starts_with('"') {
		body := identifier[1..identifier.len - 1].replace('""', '"')
		return body.runes().len > 18
	}

	return identifier.runes().len >= 18
}

// name_features returns F391 if any of the names (each as it's written, with the
// quotes of a <delimited identifier>) is too long for Core SQL. It's for the
// names in a module that are only read by ModuleTokens, rather than the
// grammar: the <SQL-client module name>, <schema name> and <module
// authorization identifier>, a <procedure name>, a <host parameter name>, and in
// a statement, a <statement name>, a <descriptor name> or a <cursor name>. An
// <identifier> that's in a <character string literal> (such as a descriptor
// name) isn't flagged, since it's not a token of the SQL language.
//
// ISO/IEC 9075-2:2016(E), 5.2, <token> and <separator>, Conformance Rules, 1 and 2
fn name_features(names []string) []string {
	return if names.any(is_long_identifier(it)) { ['F391'] } else { []string{} }
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

// flag_updatability_clause flags a FOR UPDATE of a query with an ORDER BY, or
// of a cursor with a <cursor scrollability> (even NO SCROLL). A positioned
// UPDATE of such a cursor needs the same feature, so it's flagged here instead.
//
// ISO/IEC 9075-2:2016(E), 14.1, <declare cursor>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 14.13, <update statement: positioned>, Conformance Rules, 1
fn flag_updatability_clause(mut yylex YYLexer, e QueryExpression, properties CursorProperties, updatability UpdatabilityClause) {
	flag_if(mut yylex, updatability.for_update && (e.order.len > 0 || properties.scrollability),
		'F831')
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
		ExplicitRowValueConstructor {
			none
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

	return primary is &Identifier
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
	flag_if(mut yylex, primary !is &Identifier, 'F561')
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

// parse_module_sql parses a statement of an SQL-client module whose host
// parameters have been replaced by a "?", and returns the features that it
// uses. A module can't contain a "?" of its own, so that's not a <dynamic
// parameter specification> (B031), and a cursor is meant to be in a module.
fn parse_module_sql(text_sql string) !(Stmt, []string) {
	mut stack := []YYSymType{}
	stmt, _, _, features := parse_sql(text_sql, mut stack)!

	return stmt, features.filter(it !in ['B031', vsql_declare_cursor, vsql_delete_positioned,
		vsql_update_positioned])
}

// module_statement_features returns the features of the <SQL procedure
// statement> of a procedure, which has been compiled so it's known to be valid.
// A connection statement or an <SQL dynamic statement> isn't parsed by the
// grammar, so the rules for them are here. The name of a statement, dynamic
// cursor or descriptor is only in one of the statements that need B031. So is a
// <dynamic single row select statement>, which can only be in a PREPARE.
//
// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Conformance Rules, 8 and 18 to 20
// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 18.2, <set connection statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 18.3, <disconnect statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, Conformance Rules, 1 and 2
// ISO/IEC 9075-2:2016(E), 20.3, <deallocate descriptor statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, Conformance Rules, 1 and 2
// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.9, <deallocate prepared statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, Conformance Rules, 2
// ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, Conformance Rules, 1 and 2
// ISO/IEC 9075-2:2016(E), 20.14, <execute immediate statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.19, <dynamic open statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.20, <dynamic fetch statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.21, <dynamic single row select statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.22, <dynamic close statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.23, <dynamic delete statement: positioned>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 20.24, <dynamic update statement: positioned>, Conformance Rules, 1
fn module_statement_features(text string, p ExternallyInvokedProcedure, cursors []ModuleCursor) ![]string {
	mut t := new_module_tokens(text)!
	mut features := t.dynamic_features()
	match t.next_word() {
		'CONNECT', 'DISCONNECT' {
			return ['F771']
		}
		'SET' {
			if t.accept('CONNECTION') {
				return ['F771']
			}
			if t.accept_descriptor_keyword()! {
				return features
			}
		}
		'GET' {
			if t.accept('DIAGNOSTICS') {
				return t.diagnostics_features(p)
			}
			for i, tok in t.tokens[1..] {
				if tok.text == '=' && t.tokens[i + 2].text.to_upper() == 'KEY_MEMBER' {
					features << 'T301'
				}
			}
			return features
		}
		'ALLOCATE' {
			if t.tokens.any(it.is_colon()) {
				features << 'B032'
			}
			return features
		}
		'DEALLOCATE' {
			if t.accept('PREPARE') {
				features << 'B032'
			}
			return features
		}
		'DESCRIBE' {
			return features
		}
		'PREPARE' {
			if t.tokens.any(it.kind == .literal) {
				features << vsql_prepare_literal
			}
			return features
		}
		'EXECUTE' {
			if t.accept('IMMEDIATE') {
				if t.tokens.any(it.kind == .literal) {
					features << vsql_execute_immediate_literal
				}
				return features
			}
			t.identifier('statement name')!
			if t.accept('INTO') {
				features << 'B032'
			}
			return features
		}
		'OPEN', 'CLOSE' {
			cursor := t.module_cursor(p, cursors)!
			return if cursor.statement == '' { []string{} } else { features }
		}
		'FETCH' {
			mut fetch := if t.accept('NEXT') { ['F431'] } else { []string{} }
			t.accept('FROM')
			if t.module_cursor(p, cursors)!.statement != '' {
				fetch << features
			}
			return fetch
		}
		else {}
	}

	query, targets := split_select_into(text)!
	text_sql, _ := rewrite_host_parameters(if targets == '' { text } else { query }, p)!
	stmt, mut statement_features := parse_module_sql(text_sql)!
	if stmt is DeleteStatementPositioned {
		statement_features << dynamic_cursor_features(stmt.cursor_name, p, cursors)!
	}
	if stmt is UpdateStatementPositioned {
		statement_features << dynamic_cursor_features(stmt.cursor_name, p, cursors)!
	}

	return statement_features
}

// dynamic_cursor_features returns B031 for a positioned DELETE or UPDATE of a
// dynamic cursor.
fn dynamic_cursor_features(name string, p ExternallyInvokedProcedure, cursors []ModuleCursor) ![]string {
	return if find_module_cursor(cursors, name, p)!.statement == '' {
		[]string{}
	} else {
		['B031']
	}
}

// is_colon is true for the ":" of a host parameter, not a literal of ":".
fn (t ModuleToken) is_colon() bool {
	return t.kind == .other && t.text == ':'
}

// dynamic_features returns the features of an <SQL dynamic statement>: B031,
// and B035 for a <non-extended descriptor name>, which is an identifier without
// GLOBAL or LOCAL (these are the keywords that can be before DESCRIPTOR in a
// statement, where it isn't a name itself).
//
// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Conformance Rules, 24
fn (t ModuleTokens) dynamic_features() []string {
	mut features := ['B031']
	for i in 1 .. t.tokens.len - 1 {
		if t.tokens[i].text.to_upper() == 'DESCRIPTOR'
			&& t.tokens[i - 1].text.to_upper() in ['ALLOCATE', 'DEALLOCATE', 'GET', 'SET', 'SQL',
				'USING', 'INTO'] {
			name := t.tokens[i + 1]
			if name.kind == .delimited
				|| (name.kind == .word && name.text.to_upper() !in ['GLOBAL', 'LOCAL']) {
				features << 'B035'
			}
		}
	}

	return features
}

// diagnostics_features returns the features of a <get diagnostics statement>.
// A target of a character string item must be a CHARACTER VARYING to have the
// same declared type. A number is an exact numeric with a scale of 0, and the
// standard doesn't say which, so that's every target that's allowed for one.
//
// ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, Conformance Rules, 1 to 3
fn (t ModuleTokens) diagnostics_features(p ExternallyInvokedProcedure) ![]string {
	mut features := ['F121']
	for i, tok in t.tokens {
		if tok.is_colon() && t.tokens[i + 2].text == '=' {
			item := t.tokens[i + 3].text.to_upper()
			if item in ['TRANSACTIONS_COMMITTED', 'TRANSACTIONS_ROLLED_BACK', 'TRANSACTION_ACTIVE'] {
				features << 'T511'
			}
			typ := p.reference(t.tokens[i + 1].text)!.typ or { HostParameterType{} }
			if item !in exact_numeric_diagnostics_items && typ.typ == .is_character {
				features << 'F122'
			}
		}
	}

	return features
}

// indicator_types returns the data type of each <indicator parameter> in a
// statement of the procedure, which is a host parameter straight after another
// one (with an optional INDICATOR between them).
fn indicator_types(text string, p ExternallyInvokedProcedure) ![]string {
	t := new_module_tokens(text)!
	mut types := []string{}
	for i, tok in t.tokens {
		if tok.is_colon() && ((i >= 2 && t.tokens[i - 2].is_colon())
			|| (i >= 3 && t.tokens[i - 3].is_colon() && t.tokens[i - 1].text.to_upper() == 'INDICATOR')) {
			typ := p.reference(t.tokens[i + 1].text)!.typ or { HostParameterType{} }
			types << typ.sql()
		}
	}

	return types
}

// parameter_features returns the features of the data type of each host
// parameter of a procedure, even if the statement doesn't use it.
fn (p ExternallyInvokedProcedure) parameter_features() ![]string {
	mut features := []string{}
	for parameter in p.parameters {
		if typ := parameter.typ {
			_, type_features := parse_module_sql('SELECT CAST(NULL AS ${typ.sql()}) FROM t')!
			features << type_features
		}
	}

	return features
}

// unique_features returns the features (and the other ones) sorted and without
// duplicates.
fn unique_features(all []string, others ...string) []string {
	mut features := []string{}
	for feature in arrays.append(all, others) {
		if feature !in features {
			features << feature
		}
	}
	features.sort()

	return features
}

// resolved_features returns the features of the rules that depend on what a
// name refers to. Nothing can be flagged falsely, because the names are resolved
// by the planner, as they are when the statement is executed, but nothing is
// executed. A statement that can't be planned (such as for a table that doesn't
// exist, or a dynamic parameter that doesn't have a value) only has the features
// that were found up to that point.
fn (mut conn Connection) resolved_features(stmt Stmt, params map[string]Value) []string {
	conn.open_read_connection() or { return [] }
	defer {
		conn.release_read_connection()
	}

	conn.flagging = true
	conn.flagged_features = []
	conn.flagged_tables = []
	defer {
		conn.flagging = false
	}

	match stmt {
		AlterTableStatement {
			conn.flag_alter_table(stmt)
		}
		DeclareCursor {
			create_statement_query_plan(stmt.query, params, mut conn) or {}
		}
		DeleteStatementSearched {
			create_plan(stmt, params, mut conn) or {}
			conn.flag_self_reference(stmt.table_name)
		}
		InsertStatement {
			// Only a <from subquery> can't read the table, not a subquery in
			// the VALUES of a <from constructor>.
			if query := stmt.query {
				conn.flag_query_tables = true
				create_query_expression_plan(query, params, mut conn, Correlation{}) or {}
				conn.flag_query_tables = false
				conn.flag_self_reference(stmt.table_name)
			}
		}
		MergeStatement {
			// The target can only be read by the source when the source is
			// itself the table, not a query.
			if stmt.source.body is QueryExpression {
				conn.flag_query_tables = true
				create_plan(stmt.source.body, params, mut conn) or {}
				conn.flag_query_tables = false
			}
			stmt.plan(params, mut conn) or {}
			for clause in stmt.clauses {
				conn.flag_set_clauses(stmt.table_name, clause.set, params)
			}
			conn.flag_self_reference(stmt.table_name)
		}
		QueryExpression {
			create_plan(stmt, params, mut conn) or {}
		}
		TableDefinition {
			conn.flag_foreign_keys(stmt, conn.resolve_identifier(stmt.table_name), 0)
		}
		UpdateStatementPositioned {
			conn.flag_set_clauses(stmt.table_name, stmt.set, params)
		}
		UpdateStatementSearched {
			create_plan(stmt, params, mut conn) or {}
			conn.flag_set_clauses(stmt.table_name, stmt.set, params)
		}
		else {}
	}

	return conn.flagged_features
}

// flag_subquery_table records a base table that's read by a subquery (or by
// the query of an INSERT).
fn (mut conn Connection) flag_subquery_table(table_name Identifier) {
	if conn.flagging && (conn.subquery_scopes.len > 0 || conn.flag_query_tables) {
		conn.flagged_tables << table_name.id()
	}
}

// information_schema_features are the features that a reference to a view of
// the INFORMATION_SCHEMA ("VIEW"), or to one of its columns ("VIEW.COLUMN"),
// needs. A view is referenced when it's read (with or without
// "INFORMATION_SCHEMA." in front of it), and a column when a column reference or
// an asterisk resolves to it (see Column.features). A view that isn't here can
// be referenced in Core SQL.
//
// ISO/IEC 9075-11:2008(E), 5.21, COLUMNS view, Conformance Rules, 1, 2, 3 and 4
// ISO/IEC 9075-11:2008(E), 5.32, KEY_COLUMN_USAGE view, Conformance Rules, 1 and 2
// ISO/IEC 9075-11:2008(E), 5.37, REFERENTIAL_CONSTRAINTS view, Conformance Rules, 1
// ISO/IEC 9075-11:2008(E), 5.61, TABLES view, Conformance Rules, 1
const information_schema_features = {
	'COLUMNS':                       ['F391']
	'COLUMNS.IS_GENERATED':          ['T175']
	'COLUMNS.GENERATION_EXPRESSION': ['T175']
	'COLUMNS.IS_UPDATABLE':          ['T111']
	'KEY_COLUMN_USAGE':              ['F341', 'F391']
	'REFERENTIAL_CONSTRAINTS':       ['F391']
	'TABLES':                        ['F391']
}

// information_schema_column_features are the features that a reference to a
// column of a table needs, if it's a view of the INFORMATION_SCHEMA (see
// information_schema_features).
fn information_schema_column_features(table_name Identifier, column_name string) []string {
	if table_name.schema_name != information_schema_name {
		return []
	}

	return information_schema_features['${table_name.entity_name}.${column_name}'] or { [] }
}

// flag_information_schema_view flags a view of the INFORMATION_SCHEMA that's
// read (see information_schema_features).
fn (mut conn Connection) flag_information_schema_view(table_name Identifier) {
	if conn.flagging && table_name.schema_name == information_schema_name {
		conn.flagged_features << information_schema_features[table_name.entity_name] or { [] }
	}
}

// flag_asterisk flags the columns of a table that an asterisk (such as "SELECT
// *" or "SELECT t.*") expands to, since each of them is referenced.
fn (mut conn Connection) flag_asterisk(table Table) {
	if conn.flagging {
		for column in table.columns {
			conn.flagged_features << column.features
		}
	}
}

// flag_self_reference flags a DELETE or UPDATE with a subquery that reads the
// table being changed, or an INSERT with a query that reads it anywhere. There
// are no views, so the leaf generally underlying tables are the base tables
// that are read. A table name that's only the qualifier of a column reference
// isn't read.
//
// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>, Conformance Rules, 1.a
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Conformance Rules, 1.a
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Conformance Rules, 1.a and 2.a
// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, Conformance Rules, 1.a
// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>, Conformance Rules, 1.a
fn (mut conn Connection) flag_self_reference(table_name Identifier) {
	if conn.resolve_identifier(table_name).id() in conn.flagged_tables {
		conn.flagged_features << 'F781'
	}
}

// flag_set_clauses compiles the value of each <set clause>, which isn't part of
// the plan of an UPDATE.
fn (mut conn Connection) flag_set_clauses(table_name Identifier, set []SetClause, params map[string]Value) {
	mut c := Compiler{
		conn:    conn
		params:  params
		context: conn.resolve_identifier(table_name)
	}
	for clause in set {
		clause.source.compile(mut c) or {}
	}
	conn.flag_self_reference(table_name)
}

// flag_alter_table flags a FOREIGN KEY that an ALTER TABLE adds, either as a
// constraint or on a new column. The existing ones aren't part of the statement.
fn (mut conn Connection) flag_alter_table(stmt AlterTableStatement) {
	table_name := conn.resolve_table_identifier(stmt.table_name, false) or { return }
	table := conn.catalog_for(table_name).storage.table(table_name.storage_id())
	mut elements := table.elements()
	match stmt.action {
		AddColumnDefinition { elements << stmt.action.column_definition }
		AddTableConstraintDefinition { elements << stmt.action.constraint }
		else { return }
	}
	conn.flag_foreign_keys(TableDefinition{table.name, elements, false}, table.name, table.foreign_keys.len)
}

// flag_foreign_keys flags each FOREIGN KEY of a definition, other than the
// existing ones that are first, with a referencing column that doesn't have the
// same data type as its referenced column. The referenced table must already
// exist to be checked.
//
// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>, Conformance Rules, 5
fn (mut conn Connection) flag_foreign_keys(definition TableDefinition, table_name Identifier, existing int) {
	mut table := definition.table(table_name, 0) or { return }
	resolve_foreign_keys(mut conn, mut table) or { return }
	for key in table.foreign_keys[existing..] {
		referenced := if key.referenced_table.storage_id() == table_name.storage_id() {
			table
		} else {
			conn.catalog_for(key.referenced_table).storage.table(key.referenced_table.storage_id())
		}
		for i, name in key.referenced_columns {
			a := (referenced.column(name) or { Column{} }).typ
			b := (table.column(key.columns[i]) or { Column{} }).typ
			if a.typ != b.typ || a.size != b.size || a.scale != b.scale {
				conn.flagged_features << 'T201'
			}
		}
	}
}

// flag_set_function flags an aggregate function with an argument that contains
// an outer reference, unless it's only that column reference. The aggregation
// query is the innermost query of its column references, so a column that isn't
// of the table being aggregated (10.9, Conformance Rules, 5) can only be one of
// several, which is also covered by this. An expression may be compiled more
// than once, so the same column is only counted once.
//
// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 6
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 5, 7 and 18
fn (mut c Compiler) flag_set_function(e RoutineInvocation) {
	if !c.conn.flagging || !c.aggregated_columns.any(it.scope >= 0) {
		return
	}

	mut is_column := false
	if primary := value_primary_of(e.args[0]) {
		is_column = primary is &Identifier
	}
	if !is_column {
		c.conn.flagged_features << 'F441'
	}

	mut columns := map[string]bool{}
	for column in c.aggregated_columns {
		columns['${column.scope} ${column.name}'] = true
	}
	if columns.len > 1 {
		c.conn.flagged_features << 'F442'
	}
}

// flag_column_reference flags a column reference that's derived from an
// aggregate function when it's in a WHERE clause or an aggregate function, and
// a column that needs a feature to be referenced (see Column.features). It's
// only called once the reference has been compiled, so it's known to be valid.
//
// ISO/IEC 9075-2:2016(E), 7.12, <where clause>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 9
fn (mut c Compiler) flag_column_reference(e Identifier) {
	if !c.conn.flagging || e.custom_id != '' {
		return
	}

	// The same order that Identifier.compile_column finds the column.
	mut tables := c.tables.clone()
	if !e.is_column_of(c.conn, tables, c.context) {
		for i := c.conn.subquery_scopes.len - 1; i >= 0; i-- {
			scope := c.conn.subquery_scopes[i]
			if e.is_column_of(c.conn, scope.tables, scope.context) {
				tables = scope.tables.clone()
				break
			}
		}
	}

	in_where_or_aggregate := c.in_aggregate || c.next_value_not_allowed == 'WHERE'
	for _, table in tables {
		if e.is_column_of_table(c.conn, table) {
			column := table.column(e.sub_entity_name) or { Column{} }
			if column.from_aggregate && in_where_or_aggregate {
				c.conn.flagged_features << 'F441'
			}
			c.conn.flagged_features << column.features
		}
	}
}

// features returns the Feature IDs outside of Core SQL that the statement uses
// (see the SQL Compliance docs), sorted and without duplicates. A statement
// that only uses Core SQL returns an empty array.
//
// The rules that depend on what a name refers to use the catalog as it is when
// this is called. The statement isn't executed.
//
// IDs that start with "V" are features that only vsql has, such as "V001-01"
// for EXPLAIN.
pub fn (p PreparedStmt) features() []string {
	mut conn := unsafe { p.c }

	return unique_features(p.features, ...conn.resolved_features(p.stmt, p.params))
}
