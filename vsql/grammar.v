// grammar.v is generated. DO NOT EDIT.
// It can be regenerated from the grammar.bnf with:
//   python generate-grammar.py

module vsql

type EarleyValue = AggregateFunction
	| AlterSequenceGeneratorStatement
	| BetweenPredicate
	| BooleanPredicand
	| BooleanPrimary
	| BooleanTerm
	| BooleanTest
	| BooleanValueExpression
	| CaseExpression
	| CastOperand
	| CastSpecification
	| CharacterLikePredicate
	| CharacterPrimary
	| CharacterSubstringFunction
	| CharacterValueExpression
	| CharacterValueFunction
	| CommonValueExpression
	| ComparisonPredicate
	| ComparisonPredicatePart2
	| Concatenation
	| ContextuallyTypedRowValueConstructor
	| ContextuallyTypedRowValueConstructorElement
	| Correlation
	| DatetimePrimary
	| DatetimeValueFunction
	| DerivedColumn
	| ExplicitRowValueConstructor
	| GeneralValueSpecification
	| Identifier
	| IdentifierChain
	| InsertStatement
	| NextValueExpression
	| NonparenthesizedValueExpressionPrimary
	| NullPredicate
	| NullSpecification
	| NumericPrimary
	| NumericValueExpression
	| ParenthesizedValueExpression
	| Predicate
	| QualifiedAsteriskExpr
	| QualifiedJoin
	| QueryExpression
	| RoutineInvocation
	| RowValueConstructor
	| RowValueConstructorPredicand
	| SelectList
	| SequenceGeneratorIncrementByOption
	| SequenceGeneratorMaxvalueOption
	| SequenceGeneratorMinvalueOption
	| SequenceGeneratorOption
	| SequenceGeneratorRestartOption
	| SequenceGeneratorStartWithOption
	| SimilarPredicate
	| SimpleTable
	| SortSpecification
	| Stmt
	| TableDefinition
	| TableElement
	| TableExpression
	| TablePrimary
	| TablePrimaryBody
	| TableReference
	| Term
	| TrimFunction
	| Type
	| UpdateSource
	| Value
	| ValueExpression
	| ValueExpressionPrimary
	| ValueSpecification
	| []ContextuallyTypedRowValueConstructor
	| []ContextuallyTypedRowValueConstructorElement
	| []Identifier
	| []RowValueConstructor
	| []SequenceGeneratorOption
	| []SortSpecification
	| []TableElement
	| []ValueExpression
	| bool
	| map[string]UpdateSource
	| string

fn get_grammar() map[string]EarleyRule {
	mut rules := map[string]EarleyRule{}

	mut rule_absolute_value_expression__1_ := &EarleyRule{
		name: '<absolute value expression: #1>'
	}
	mut rule_absolute_value_expression_ := &EarleyRule{
		name: '<absolute value expression>'
	}
	mut rule_actual_identifier_ := &EarleyRule{
		name: '<actual identifier>'
	}
	mut rule_aggregate_function__1_ := &EarleyRule{
		name: '<aggregate function: #1>'
	}
	mut rule_aggregate_function_ := &EarleyRule{
		name: '<aggregate function>'
	}
	mut rule_alter_sequence_generator_option__1_ := &EarleyRule{
		name: '<alter sequence generator option: #1>'
	}
	mut rule_alter_sequence_generator_option_ := &EarleyRule{
		name: '<alter sequence generator option>'
	}
	mut rule_alter_sequence_generator_options__1_ := &EarleyRule{
		name: '<alter sequence generator options: #1>'
	}
	mut rule_alter_sequence_generator_options__2_ := &EarleyRule{
		name: '<alter sequence generator options: #2>'
	}
	mut rule_alter_sequence_generator_options_ := &EarleyRule{
		name: '<alter sequence generator options>'
	}
	mut rule_alter_sequence_generator_restart_option__1_ := &EarleyRule{
		name: '<alter sequence generator restart option: #1>'
	}
	mut rule_alter_sequence_generator_restart_option__2_ := &EarleyRule{
		name: '<alter sequence generator restart option: #2>'
	}
	mut rule_alter_sequence_generator_restart_option_ := &EarleyRule{
		name: '<alter sequence generator restart option>'
	}
	mut rule_alter_sequence_generator_statement__1_ := &EarleyRule{
		name: '<alter sequence generator statement: #1>'
	}
	mut rule_alter_sequence_generator_statement_ := &EarleyRule{
		name: '<alter sequence generator statement>'
	}
	mut rule_approximate_numeric_type__1_ := &EarleyRule{
		name: '<approximate numeric type: #1>'
	}
	mut rule_approximate_numeric_type__2_ := &EarleyRule{
		name: '<approximate numeric type: #2>'
	}
	mut rule_approximate_numeric_type__3_ := &EarleyRule{
		name: '<approximate numeric type: #3>'
	}
	mut rule_approximate_numeric_type__4_ := &EarleyRule{
		name: '<approximate numeric type: #4>'
	}
	mut rule_approximate_numeric_type_ := &EarleyRule{
		name: '<approximate numeric type>'
	}
	mut rule_as_clause__1_ := &EarleyRule{
		name: '<as clause: #1>'
	}
	mut rule_as_clause_ := &EarleyRule{
		name: '<as clause>'
	}
	mut rule_asterisk_ := &EarleyRule{
		name: '<asterisk>'
	}
	mut rule_asterisked_identifier_chain_ := &EarleyRule{
		name: '<asterisked identifier chain>'
	}
	mut rule_asterisked_identifier_ := &EarleyRule{
		name: '<asterisked identifier>'
	}
	mut rule_basic_identifier_chain_ := &EarleyRule{
		name: '<basic identifier chain>'
	}
	mut rule_basic_sequence_generator_option__1_ := &EarleyRule{
		name: '<basic sequence generator option: #1>'
	}
	mut rule_basic_sequence_generator_option__2_ := &EarleyRule{
		name: '<basic sequence generator option: #2>'
	}
	mut rule_basic_sequence_generator_option__3_ := &EarleyRule{
		name: '<basic sequence generator option: #3>'
	}
	mut rule_basic_sequence_generator_option__4_ := &EarleyRule{
		name: '<basic sequence generator option: #4>'
	}
	mut rule_basic_sequence_generator_option_ := &EarleyRule{
		name: '<basic sequence generator option>'
	}
	mut rule_between_predicate_part_1__1_ := &EarleyRule{
		name: '<between predicate part 1: #1>'
	}
	mut rule_between_predicate_part_1__2_ := &EarleyRule{
		name: '<between predicate part 1: #2>'
	}
	mut rule_between_predicate_part_1_ := &EarleyRule{
		name: '<between predicate part 1>'
	}
	mut rule_between_predicate_part_2__1_ := &EarleyRule{
		name: '<between predicate part 2: #1>'
	}
	mut rule_between_predicate_part_2__2_ := &EarleyRule{
		name: '<between predicate part 2: #2>'
	}
	mut rule_between_predicate_part_2_ := &EarleyRule{
		name: '<between predicate part 2>'
	}
	mut rule_between_predicate__1_ := &EarleyRule{
		name: '<between predicate: #1>'
	}
	mut rule_between_predicate_ := &EarleyRule{
		name: '<between predicate>'
	}
	mut rule_boolean_factor__2_ := &EarleyRule{
		name: '<boolean factor: #2>'
	}
	mut rule_boolean_factor_ := &EarleyRule{
		name: '<boolean factor>'
	}
	mut rule_boolean_literal__1_ := &EarleyRule{
		name: '<boolean literal: #1>'
	}
	mut rule_boolean_literal__2_ := &EarleyRule{
		name: '<boolean literal: #2>'
	}
	mut rule_boolean_literal__3_ := &EarleyRule{
		name: '<boolean literal: #3>'
	}
	mut rule_boolean_literal_ := &EarleyRule{
		name: '<boolean literal>'
	}
	mut rule_boolean_predicand__1_ := &EarleyRule{
		name: '<boolean predicand: #1>'
	}
	mut rule_boolean_predicand__2_ := &EarleyRule{
		name: '<boolean predicand: #2>'
	}
	mut rule_boolean_predicand_ := &EarleyRule{
		name: '<boolean predicand>'
	}
	mut rule_boolean_primary__1_ := &EarleyRule{
		name: '<boolean primary: #1>'
	}
	mut rule_boolean_primary__2_ := &EarleyRule{
		name: '<boolean primary: #2>'
	}
	mut rule_boolean_primary_ := &EarleyRule{
		name: '<boolean primary>'
	}
	mut rule_boolean_term__1_ := &EarleyRule{
		name: '<boolean term: #1>'
	}
	mut rule_boolean_term__2_ := &EarleyRule{
		name: '<boolean term: #2>'
	}
	mut rule_boolean_term_ := &EarleyRule{
		name: '<boolean term>'
	}
	mut rule_boolean_test__1_ := &EarleyRule{
		name: '<boolean test: #1>'
	}
	mut rule_boolean_test__2_ := &EarleyRule{
		name: '<boolean test: #2>'
	}
	mut rule_boolean_test__3_ := &EarleyRule{
		name: '<boolean test: #3>'
	}
	mut rule_boolean_test_ := &EarleyRule{
		name: '<boolean test>'
	}
	mut rule_boolean_type__1_ := &EarleyRule{
		name: '<boolean type: #1>'
	}
	mut rule_boolean_type_ := &EarleyRule{
		name: '<boolean type>'
	}
	mut rule_boolean_value_expression__1_ := &EarleyRule{
		name: '<boolean value expression: #1>'
	}
	mut rule_boolean_value_expression__2_ := &EarleyRule{
		name: '<boolean value expression: #2>'
	}
	mut rule_boolean_value_expression_ := &EarleyRule{
		name: '<boolean value expression>'
	}
	mut rule_case_abbreviation__1_ := &EarleyRule{
		name: '<case abbreviation: #1>'
	}
	mut rule_case_abbreviation__2_ := &EarleyRule{
		name: '<case abbreviation: #2>'
	}
	mut rule_case_abbreviation_ := &EarleyRule{
		name: '<case abbreviation>'
	}
	mut rule_case_expression_ := &EarleyRule{
		name: '<case expression>'
	}
	mut rule_cast_operand__1_ := &EarleyRule{
		name: '<cast operand: #1>'
	}
	mut rule_cast_operand__2_ := &EarleyRule{
		name: '<cast operand: #2>'
	}
	mut rule_cast_operand_ := &EarleyRule{
		name: '<cast operand>'
	}
	mut rule_cast_specification__1_ := &EarleyRule{
		name: '<cast specification: #1>'
	}
	mut rule_cast_specification_ := &EarleyRule{
		name: '<cast specification>'
	}
	mut rule_cast_target_ := &EarleyRule{
		name: '<cast target>'
	}
	mut rule_catalog_name_characteristic__1_ := &EarleyRule{
		name: '<catalog name characteristic: #1>'
	}
	mut rule_catalog_name_characteristic_ := &EarleyRule{
		name: '<catalog name characteristic>'
	}
	mut rule_catalog_name_ := &EarleyRule{
		name: '<catalog name>'
	}
	mut rule_ceiling_function__1_ := &EarleyRule{
		name: '<ceiling function: #1>'
	}
	mut rule_ceiling_function__2_ := &EarleyRule{
		name: '<ceiling function: #2>'
	}
	mut rule_ceiling_function_ := &EarleyRule{
		name: '<ceiling function>'
	}
	mut rule_char_length_expression__1_ := &EarleyRule{
		name: '<char length expression: #1>'
	}
	mut rule_char_length_expression__2_ := &EarleyRule{
		name: '<char length expression: #2>'
	}
	mut rule_char_length_expression_ := &EarleyRule{
		name: '<char length expression>'
	}
	mut rule_char_length_units_ := &EarleyRule{
		name: '<char length units>'
	}
	mut rule_character_factor_ := &EarleyRule{
		name: '<character factor>'
	}
	mut rule_character_length_ := &EarleyRule{
		name: '<character length>'
	}
	mut rule_character_like_predicate_part_2__1_ := &EarleyRule{
		name: '<character like predicate part 2: #1>'
	}
	mut rule_character_like_predicate_part_2__2_ := &EarleyRule{
		name: '<character like predicate part 2: #2>'
	}
	mut rule_character_like_predicate_part_2_ := &EarleyRule{
		name: '<character like predicate part 2>'
	}
	mut rule_character_like_predicate__1_ := &EarleyRule{
		name: '<character like predicate: #1>'
	}
	mut rule_character_like_predicate_ := &EarleyRule{
		name: '<character like predicate>'
	}
	mut rule_character_pattern_ := &EarleyRule{
		name: '<character pattern>'
	}
	mut rule_character_position_expression__1_ := &EarleyRule{
		name: '<character position expression: #1>'
	}
	mut rule_character_position_expression_ := &EarleyRule{
		name: '<character position expression>'
	}
	mut rule_character_primary__1_ := &EarleyRule{
		name: '<character primary: #1>'
	}
	mut rule_character_primary__2_ := &EarleyRule{
		name: '<character primary: #2>'
	}
	mut rule_character_primary_ := &EarleyRule{
		name: '<character primary>'
	}
	mut rule_character_string_literal_ := &EarleyRule{
		name: '<character string literal>'
	}
	mut rule_character_string_type__1_ := &EarleyRule{
		name: '<character string type: #1>'
	}
	mut rule_character_string_type__2_ := &EarleyRule{
		name: '<character string type: #2>'
	}
	mut rule_character_string_type__3_ := &EarleyRule{
		name: '<character string type: #3>'
	}
	mut rule_character_string_type__4_ := &EarleyRule{
		name: '<character string type: #4>'
	}
	mut rule_character_string_type__5_ := &EarleyRule{
		name: '<character string type: #5>'
	}
	mut rule_character_string_type__6_ := &EarleyRule{
		name: '<character string type: #6>'
	}
	mut rule_character_string_type__7_ := &EarleyRule{
		name: '<character string type: #7>'
	}
	mut rule_character_string_type_ := &EarleyRule{
		name: '<character string type>'
	}
	mut rule_character_substring_function__1_ := &EarleyRule{
		name: '<character substring function: #1>'
	}
	mut rule_character_substring_function__2_ := &EarleyRule{
		name: '<character substring function: #2>'
	}
	mut rule_character_substring_function__3_ := &EarleyRule{
		name: '<character substring function: #3>'
	}
	mut rule_character_substring_function__4_ := &EarleyRule{
		name: '<character substring function: #4>'
	}
	mut rule_character_substring_function_ := &EarleyRule{
		name: '<character substring function>'
	}
	mut rule_character_value_expression_1_ := &EarleyRule{
		name: '<character value expression 1>'
	}
	mut rule_character_value_expression_2_ := &EarleyRule{
		name: '<character value expression 2>'
	}
	mut rule_character_value_expression__1_ := &EarleyRule{
		name: '<character value expression: #1>'
	}
	mut rule_character_value_expression__2_ := &EarleyRule{
		name: '<character value expression: #2>'
	}
	mut rule_character_value_expression_ := &EarleyRule{
		name: '<character value expression>'
	}
	mut rule_character_value_function__1_ := &EarleyRule{
		name: '<character value function: #1>'
	}
	mut rule_character_value_function__2_ := &EarleyRule{
		name: '<character value function: #2>'
	}
	mut rule_character_value_function__3_ := &EarleyRule{
		name: '<character value function: #3>'
	}
	mut rule_character_value_function_ := &EarleyRule{
		name: '<character value function>'
	}
	mut rule_colon_ := &EarleyRule{
		name: '<colon>'
	}
	mut rule_column_constraint_definition_ := &EarleyRule{
		name: '<column constraint definition>'
	}
	mut rule_column_constraint__1_ := &EarleyRule{
		name: '<column constraint: #1>'
	}
	mut rule_column_constraint_ := &EarleyRule{
		name: '<column constraint>'
	}
	mut rule_column_definition__1_ := &EarleyRule{
		name: '<column definition: #1>'
	}
	mut rule_column_definition__2_ := &EarleyRule{
		name: '<column definition: #2>'
	}
	mut rule_column_definition_ := &EarleyRule{
		name: '<column definition>'
	}
	mut rule_column_name_list__1_ := &EarleyRule{
		name: '<column name list: #1>'
	}
	mut rule_column_name_list__2_ := &EarleyRule{
		name: '<column name list: #2>'
	}
	mut rule_column_name_list_ := &EarleyRule{
		name: '<column name list>'
	}
	mut rule_column_name__1_ := &EarleyRule{
		name: '<column name: #1>'
	}
	mut rule_column_name_ := &EarleyRule{
		name: '<column name>'
	}
	mut rule_column_reference__1_ := &EarleyRule{
		name: '<column reference: #1>'
	}
	mut rule_column_reference_ := &EarleyRule{
		name: '<column reference>'
	}
	mut rule_comma_ := &EarleyRule{
		name: '<comma>'
	}
	mut rule_commit_statement__1_ := &EarleyRule{
		name: '<commit statement: #1>'
	}
	mut rule_commit_statement__2_ := &EarleyRule{
		name: '<commit statement: #2>'
	}
	mut rule_commit_statement_ := &EarleyRule{
		name: '<commit statement>'
	}
	mut rule_common_logarithm__1_ := &EarleyRule{
		name: '<common logarithm: #1>'
	}
	mut rule_common_logarithm_ := &EarleyRule{
		name: '<common logarithm>'
	}
	mut rule_common_sequence_generator_option__1_ := &EarleyRule{
		name: '<common sequence generator option: #1>'
	}
	mut rule_common_sequence_generator_option_ := &EarleyRule{
		name: '<common sequence generator option>'
	}
	mut rule_common_sequence_generator_options__1_ := &EarleyRule{
		name: '<common sequence generator options: #1>'
	}
	mut rule_common_sequence_generator_options__2_ := &EarleyRule{
		name: '<common sequence generator options: #2>'
	}
	mut rule_common_sequence_generator_options_ := &EarleyRule{
		name: '<common sequence generator options>'
	}
	mut rule_common_value_expression__1_ := &EarleyRule{
		name: '<common value expression: #1>'
	}
	mut rule_common_value_expression__2_ := &EarleyRule{
		name: '<common value expression: #2>'
	}
	mut rule_common_value_expression__3_ := &EarleyRule{
		name: '<common value expression: #3>'
	}
	mut rule_common_value_expression_ := &EarleyRule{
		name: '<common value expression>'
	}
	mut rule_comp_op_ := &EarleyRule{
		name: '<comp op>'
	}
	mut rule_comparison_predicate_part_2__1_ := &EarleyRule{
		name: '<comparison predicate part 2: #1>'
	}
	mut rule_comparison_predicate_part_2_ := &EarleyRule{
		name: '<comparison predicate part 2>'
	}
	mut rule_comparison_predicate__1_ := &EarleyRule{
		name: '<comparison predicate: #1>'
	}
	mut rule_comparison_predicate_ := &EarleyRule{
		name: '<comparison predicate>'
	}
	mut rule_computational_operation_ := &EarleyRule{
		name: '<computational operation>'
	}
	mut rule_concatenation_operator_ := &EarleyRule{
		name: '<concatenation operator>'
	}
	mut rule_concatenation__1_ := &EarleyRule{
		name: '<concatenation: #1>'
	}
	mut rule_concatenation_ := &EarleyRule{
		name: '<concatenation>'
	}
	mut rule_contextually_typed_row_value_constructor_element_list__1_ := &EarleyRule{
		name: '<contextually typed row value constructor element list: #1>'
	}
	mut rule_contextually_typed_row_value_constructor_element_list__2_ := &EarleyRule{
		name: '<contextually typed row value constructor element list: #2>'
	}
	mut rule_contextually_typed_row_value_constructor_element_list_ := &EarleyRule{
		name: '<contextually typed row value constructor element list>'
	}
	mut rule_contextually_typed_row_value_constructor_element__1_ := &EarleyRule{
		name: '<contextually typed row value constructor element: #1>'
	}
	mut rule_contextually_typed_row_value_constructor_element__2_ := &EarleyRule{
		name: '<contextually typed row value constructor element: #2>'
	}
	mut rule_contextually_typed_row_value_constructor_element_ := &EarleyRule{
		name: '<contextually typed row value constructor element>'
	}
	mut rule_contextually_typed_row_value_constructor__1_ := &EarleyRule{
		name: '<contextually typed row value constructor: #1>'
	}
	mut rule_contextually_typed_row_value_constructor__2_ := &EarleyRule{
		name: '<contextually typed row value constructor: #2>'
	}
	mut rule_contextually_typed_row_value_constructor__3_ := &EarleyRule{
		name: '<contextually typed row value constructor: #3>'
	}
	mut rule_contextually_typed_row_value_constructor__4_ := &EarleyRule{
		name: '<contextually typed row value constructor: #4>'
	}
	mut rule_contextually_typed_row_value_constructor__5_ := &EarleyRule{
		name: '<contextually typed row value constructor: #5>'
	}
	mut rule_contextually_typed_row_value_constructor_ := &EarleyRule{
		name: '<contextually typed row value constructor>'
	}
	mut rule_contextually_typed_row_value_expression_list__1_ := &EarleyRule{
		name: '<contextually typed row value expression list: #1>'
	}
	mut rule_contextually_typed_row_value_expression_list__2_ := &EarleyRule{
		name: '<contextually typed row value expression list: #2>'
	}
	mut rule_contextually_typed_row_value_expression_list_ := &EarleyRule{
		name: '<contextually typed row value expression list>'
	}
	mut rule_contextually_typed_row_value_expression_ := &EarleyRule{
		name: '<contextually typed row value expression>'
	}
	mut rule_contextually_typed_table_value_constructor__1_ := &EarleyRule{
		name: '<contextually typed table value constructor: #1>'
	}
	mut rule_contextually_typed_table_value_constructor_ := &EarleyRule{
		name: '<contextually typed table value constructor>'
	}
	mut rule_contextually_typed_value_specification_ := &EarleyRule{
		name: '<contextually typed value specification>'
	}
	mut rule_correlation_name__1_ := &EarleyRule{
		name: '<correlation name: #1>'
	}
	mut rule_correlation_name_ := &EarleyRule{
		name: '<correlation name>'
	}
	mut rule_correlation_or_recognition__1_ := &EarleyRule{
		name: '<correlation or recognition: #1>'
	}
	mut rule_correlation_or_recognition__2_ := &EarleyRule{
		name: '<correlation or recognition: #2>'
	}
	mut rule_correlation_or_recognition__3_ := &EarleyRule{
		name: '<correlation or recognition: #3>'
	}
	mut rule_correlation_or_recognition__4_ := &EarleyRule{
		name: '<correlation or recognition: #4>'
	}
	mut rule_correlation_or_recognition_ := &EarleyRule{
		name: '<correlation or recognition>'
	}
	mut rule_current_date_value_function__1_ := &EarleyRule{
		name: '<current date value function: #1>'
	}
	mut rule_current_date_value_function_ := &EarleyRule{
		name: '<current date value function>'
	}
	mut rule_current_local_time_value_function__1_ := &EarleyRule{
		name: '<current local time value function: #1>'
	}
	mut rule_current_local_time_value_function__2_ := &EarleyRule{
		name: '<current local time value function: #2>'
	}
	mut rule_current_local_time_value_function_ := &EarleyRule{
		name: '<current local time value function>'
	}
	mut rule_current_local_timestamp_value_function__1_ := &EarleyRule{
		name: '<current local timestamp value function: #1>'
	}
	mut rule_current_local_timestamp_value_function__2_ := &EarleyRule{
		name: '<current local timestamp value function: #2>'
	}
	mut rule_current_local_timestamp_value_function_ := &EarleyRule{
		name: '<current local timestamp value function>'
	}
	mut rule_current_time_value_function__1_ := &EarleyRule{
		name: '<current time value function: #1>'
	}
	mut rule_current_time_value_function__2_ := &EarleyRule{
		name: '<current time value function: #2>'
	}
	mut rule_current_time_value_function_ := &EarleyRule{
		name: '<current time value function>'
	}
	mut rule_current_timestamp_value_function__1_ := &EarleyRule{
		name: '<current timestamp value function: #1>'
	}
	mut rule_current_timestamp_value_function__2_ := &EarleyRule{
		name: '<current timestamp value function: #2>'
	}
	mut rule_current_timestamp_value_function_ := &EarleyRule{
		name: '<current timestamp value function>'
	}
	mut rule_cursor_specification__1_ := &EarleyRule{
		name: '<cursor specification: #1>'
	}
	mut rule_cursor_specification_ := &EarleyRule{
		name: '<cursor specification>'
	}
	mut rule_data_type_or_domain_name_ := &EarleyRule{
		name: '<data type or domain name>'
	}
	mut rule_data_type_ := &EarleyRule{
		name: '<data type>'
	}
	mut rule_date_literal__1_ := &EarleyRule{
		name: '<date literal: #1>'
	}
	mut rule_date_literal_ := &EarleyRule{
		name: '<date literal>'
	}
	mut rule_date_string_ := &EarleyRule{
		name: '<date string>'
	}
	mut rule_datetime_factor_ := &EarleyRule{
		name: '<datetime factor>'
	}
	mut rule_datetime_literal_ := &EarleyRule{
		name: '<datetime literal>'
	}
	mut rule_datetime_primary__1_ := &EarleyRule{
		name: '<datetime primary: #1>'
	}
	mut rule_datetime_primary__2_ := &EarleyRule{
		name: '<datetime primary: #2>'
	}
	mut rule_datetime_primary_ := &EarleyRule{
		name: '<datetime primary>'
	}
	mut rule_datetime_term_ := &EarleyRule{
		name: '<datetime term>'
	}
	mut rule_datetime_type__1_ := &EarleyRule{
		name: '<datetime type: #1>'
	}
	mut rule_datetime_type__2_ := &EarleyRule{
		name: '<datetime type: #2>'
	}
	mut rule_datetime_type__3_ := &EarleyRule{
		name: '<datetime type: #3>'
	}
	mut rule_datetime_type__4_ := &EarleyRule{
		name: '<datetime type: #4>'
	}
	mut rule_datetime_type__5_ := &EarleyRule{
		name: '<datetime type: #5>'
	}
	mut rule_datetime_type__6_ := &EarleyRule{
		name: '<datetime type: #6>'
	}
	mut rule_datetime_type__7_ := &EarleyRule{
		name: '<datetime type: #7>'
	}
	mut rule_datetime_type__8_ := &EarleyRule{
		name: '<datetime type: #8>'
	}
	mut rule_datetime_type__9_ := &EarleyRule{
		name: '<datetime type: #9>'
	}
	mut rule_datetime_type_ := &EarleyRule{
		name: '<datetime type>'
	}
	mut rule_datetime_value_expression_ := &EarleyRule{
		name: '<datetime value expression>'
	}
	mut rule_datetime_value_function_ := &EarleyRule{
		name: '<datetime value function>'
	}
	mut rule_delete_statement_searched__1_ := &EarleyRule{
		name: '<delete statement: searched: #1>'
	}
	mut rule_delete_statement_searched__2_ := &EarleyRule{
		name: '<delete statement: searched: #2>'
	}
	mut rule_delete_statement_searched_ := &EarleyRule{
		name: '<delete statement: searched>'
	}
	mut rule_derived_column_list_ := &EarleyRule{
		name: '<derived column list>'
	}
	mut rule_derived_column__1_ := &EarleyRule{
		name: '<derived column: #1>'
	}
	mut rule_derived_column__2_ := &EarleyRule{
		name: '<derived column: #2>'
	}
	mut rule_derived_column_ := &EarleyRule{
		name: '<derived column>'
	}
	mut rule_derived_table_ := &EarleyRule{
		name: '<derived table>'
	}
	mut rule_drop_behavior_ := &EarleyRule{
		name: '<drop behavior>'
	}
	mut rule_drop_schema_statement__1_ := &EarleyRule{
		name: '<drop schema statement: #1>'
	}
	mut rule_drop_schema_statement_ := &EarleyRule{
		name: '<drop schema statement>'
	}
	mut rule_drop_sequence_generator_statement__1_ := &EarleyRule{
		name: '<drop sequence generator statement: #1>'
	}
	mut rule_drop_sequence_generator_statement_ := &EarleyRule{
		name: '<drop sequence generator statement>'
	}
	mut rule_drop_table_statement__1_ := &EarleyRule{
		name: '<drop table statement: #1>'
	}
	mut rule_drop_table_statement_ := &EarleyRule{
		name: '<drop table statement>'
	}
	mut rule_dynamic_select_statement_ := &EarleyRule{
		name: '<dynamic select statement>'
	}
	mut rule_equals_operator_ := &EarleyRule{
		name: '<equals operator>'
	}
	mut rule_exact_numeric_literal__1_ := &EarleyRule{
		name: '<exact numeric literal: #1>'
	}
	mut rule_exact_numeric_literal__2_ := &EarleyRule{
		name: '<exact numeric literal: #2>'
	}
	mut rule_exact_numeric_literal__3_ := &EarleyRule{
		name: '<exact numeric literal: #3>'
	}
	mut rule_exact_numeric_literal__4_ := &EarleyRule{
		name: '<exact numeric literal: #4>'
	}
	mut rule_exact_numeric_literal_ := &EarleyRule{
		name: '<exact numeric literal>'
	}
	mut rule_exact_numeric_type__1_ := &EarleyRule{
		name: '<exact numeric type: #1>'
	}
	mut rule_exact_numeric_type__2_ := &EarleyRule{
		name: '<exact numeric type: #2>'
	}
	mut rule_exact_numeric_type__3_ := &EarleyRule{
		name: '<exact numeric type: #3>'
	}
	mut rule_exact_numeric_type__4_ := &EarleyRule{
		name: '<exact numeric type: #4>'
	}
	mut rule_exact_numeric_type_ := &EarleyRule{
		name: '<exact numeric type>'
	}
	mut rule_explicit_row_value_constructor__1_ := &EarleyRule{
		name: '<explicit row value constructor: #1>'
	}
	mut rule_explicit_row_value_constructor__2_ := &EarleyRule{
		name: '<explicit row value constructor: #2>'
	}
	mut rule_explicit_row_value_constructor_ := &EarleyRule{
		name: '<explicit row value constructor>'
	}
	mut rule_exponential_function__1_ := &EarleyRule{
		name: '<exponential function: #1>'
	}
	mut rule_exponential_function_ := &EarleyRule{
		name: '<exponential function>'
	}
	mut rule_factor__2_ := &EarleyRule{
		name: '<factor: #2>'
	}
	mut rule_factor_ := &EarleyRule{
		name: '<factor>'
	}
	mut rule_fetch_first_clause__1_ := &EarleyRule{
		name: '<fetch first clause: #1>'
	}
	mut rule_fetch_first_clause_ := &EarleyRule{
		name: '<fetch first clause>'
	}
	mut rule_fetch_first_quantity_ := &EarleyRule{
		name: '<fetch first quantity>'
	}
	mut rule_fetch_first_row_count_ := &EarleyRule{
		name: '<fetch first row count>'
	}
	mut rule_floor_function__1_ := &EarleyRule{
		name: '<floor function: #1>'
	}
	mut rule_floor_function_ := &EarleyRule{
		name: '<floor function>'
	}
	mut rule_fold__1_ := &EarleyRule{
		name: '<fold: #1>'
	}
	mut rule_fold__2_ := &EarleyRule{
		name: '<fold: #2>'
	}
	mut rule_fold_ := &EarleyRule{
		name: '<fold>'
	}
	mut rule_from_clause__1_ := &EarleyRule{
		name: '<from clause: #1>'
	}
	mut rule_from_clause_ := &EarleyRule{
		name: '<from clause>'
	}
	mut rule_from_constructor__1_ := &EarleyRule{
		name: '<from constructor: #1>'
	}
	mut rule_from_constructor_ := &EarleyRule{
		name: '<from constructor>'
	}
	mut rule_general_literal_ := &EarleyRule{
		name: '<general literal>'
	}
	mut rule_general_set_function__1_ := &EarleyRule{
		name: '<general set function: #1>'
	}
	mut rule_general_set_function_ := &EarleyRule{
		name: '<general set function>'
	}
	mut rule_general_value_specification__2_ := &EarleyRule{
		name: '<general value specification: #2>'
	}
	mut rule_general_value_specification__3_ := &EarleyRule{
		name: '<general value specification: #3>'
	}
	mut rule_general_value_specification_ := &EarleyRule{
		name: '<general value specification>'
	}
	mut rule_greater_than_operator_ := &EarleyRule{
		name: '<greater than operator>'
	}
	mut rule_greater_than_or_equals_operator_ := &EarleyRule{
		name: '<greater than or equals operator>'
	}
	mut rule_group_by_clause__1_ := &EarleyRule{
		name: '<group by clause: #1>'
	}
	mut rule_group_by_clause_ := &EarleyRule{
		name: '<group by clause>'
	}
	mut rule_grouping_column_reference_ := &EarleyRule{
		name: '<grouping column reference>'
	}
	mut rule_grouping_element_list__1_ := &EarleyRule{
		name: '<grouping element list: #1>'
	}
	mut rule_grouping_element_list__2_ := &EarleyRule{
		name: '<grouping element list: #2>'
	}
	mut rule_grouping_element_list_ := &EarleyRule{
		name: '<grouping element list>'
	}
	mut rule_grouping_element_ := &EarleyRule{
		name: '<grouping element>'
	}
	mut rule_host_parameter_name__1_ := &EarleyRule{
		name: '<host parameter name: #1>'
	}
	mut rule_host_parameter_name_ := &EarleyRule{
		name: '<host parameter name>'
	}
	mut rule_host_parameter_specification_ := &EarleyRule{
		name: '<host parameter specification>'
	}
	mut rule_identifier_body_ := &EarleyRule{
		name: '<identifier body>'
	}
	mut rule_identifier_chain__2_ := &EarleyRule{
		name: '<identifier chain: #2>'
	}
	mut rule_identifier_chain_ := &EarleyRule{
		name: '<identifier chain>'
	}
	mut rule_identifier_start_ := &EarleyRule{
		name: '<identifier start>'
	}
	mut rule_identifier_ := &EarleyRule{
		name: '<identifier>'
	}
	mut rule_implicitly_typed_value_specification_ := &EarleyRule{
		name: '<implicitly typed value specification>'
	}
	mut rule_insert_column_list_ := &EarleyRule{
		name: '<insert column list>'
	}
	mut rule_insert_columns_and_source_ := &EarleyRule{
		name: '<insert columns and source>'
	}
	mut rule_insert_statement__1_ := &EarleyRule{
		name: '<insert statement: #1>'
	}
	mut rule_insert_statement_ := &EarleyRule{
		name: '<insert statement>'
	}
	mut rule_insertion_target_ := &EarleyRule{
		name: '<insertion target>'
	}
	mut rule_is_symmetric__1_ := &EarleyRule{
		name: '<is symmetric: #1>'
	}
	mut rule_is_symmetric__2_ := &EarleyRule{
		name: '<is symmetric: #2>'
	}
	mut rule_is_symmetric_ := &EarleyRule{
		name: '<is symmetric>'
	}
	mut rule_join_condition__1_ := &EarleyRule{
		name: '<join condition: #1>'
	}
	mut rule_join_condition_ := &EarleyRule{
		name: '<join condition>'
	}
	mut rule_join_specification_ := &EarleyRule{
		name: '<join specification>'
	}
	mut rule_join_type__3_ := &EarleyRule{
		name: '<join type: #3>'
	}
	mut rule_join_type_ := &EarleyRule{
		name: '<join type>'
	}
	mut rule_joined_table_ := &EarleyRule{
		name: '<joined table>'
	}
	mut rule_left_paren_ := &EarleyRule{
		name: '<left paren>'
	}
	mut rule_length_expression_ := &EarleyRule{
		name: '<length expression>'
	}
	mut rule_length_ := &EarleyRule{
		name: '<length>'
	}
	mut rule_less_than_operator_ := &EarleyRule{
		name: '<less than operator>'
	}
	mut rule_less_than_or_equals_operator_ := &EarleyRule{
		name: '<less than or equals operator>'
	}
	mut rule_like_predicate_ := &EarleyRule{
		name: '<like predicate>'
	}
	mut rule_literal_ := &EarleyRule{
		name: '<literal>'
	}
	mut rule_local_or_schema_qualified_name__2_ := &EarleyRule{
		name: '<local or schema qualified name: #2>'
	}
	mut rule_local_or_schema_qualified_name_ := &EarleyRule{
		name: '<local or schema qualified name>'
	}
	mut rule_local_or_schema_qualifier_ := &EarleyRule{
		name: '<local or schema qualifier>'
	}
	mut rule_minus_sign_ := &EarleyRule{
		name: '<minus sign>'
	}
	mut rule_modulus_expression__1_ := &EarleyRule{
		name: '<modulus expression: #1>'
	}
	mut rule_modulus_expression_ := &EarleyRule{
		name: '<modulus expression>'
	}
	mut rule_natural_logarithm__1_ := &EarleyRule{
		name: '<natural logarithm: #1>'
	}
	mut rule_natural_logarithm_ := &EarleyRule{
		name: '<natural logarithm>'
	}
	mut rule_next_value_expression__1_ := &EarleyRule{
		name: '<next value expression: #1>'
	}
	mut rule_next_value_expression_ := &EarleyRule{
		name: '<next value expression>'
	}
	mut rule_non_reserved_word_ := &EarleyRule{
		name: '<non-reserved word>'
	}
	mut rule_nonparenthesized_value_expression_primary__1_ := &EarleyRule{
		name: '<nonparenthesized value expression primary: #1>'
	}
	mut rule_nonparenthesized_value_expression_primary__2_ := &EarleyRule{
		name: '<nonparenthesized value expression primary: #2>'
	}
	mut rule_nonparenthesized_value_expression_primary__3_ := &EarleyRule{
		name: '<nonparenthesized value expression primary: #3>'
	}
	mut rule_nonparenthesized_value_expression_primary__4_ := &EarleyRule{
		name: '<nonparenthesized value expression primary: #4>'
	}
	mut rule_nonparenthesized_value_expression_primary__5_ := &EarleyRule{
		name: '<nonparenthesized value expression primary: #5>'
	}
	mut rule_nonparenthesized_value_expression_primary__6_ := &EarleyRule{
		name: '<nonparenthesized value expression primary: #6>'
	}
	mut rule_nonparenthesized_value_expression_primary__7_ := &EarleyRule{
		name: '<nonparenthesized value expression primary: #7>'
	}
	mut rule_nonparenthesized_value_expression_primary_ := &EarleyRule{
		name: '<nonparenthesized value expression primary>'
	}
	mut rule_not_equals_operator_ := &EarleyRule{
		name: '<not equals operator>'
	}
	mut rule_null_predicate_part_2__1_ := &EarleyRule{
		name: '<null predicate part 2: #1>'
	}
	mut rule_null_predicate_part_2__2_ := &EarleyRule{
		name: '<null predicate part 2: #2>'
	}
	mut rule_null_predicate_part_2_ := &EarleyRule{
		name: '<null predicate part 2>'
	}
	mut rule_null_predicate__1_ := &EarleyRule{
		name: '<null predicate: #1>'
	}
	mut rule_null_predicate_ := &EarleyRule{
		name: '<null predicate>'
	}
	mut rule_null_specification__1_ := &EarleyRule{
		name: '<null specification: #1>'
	}
	mut rule_null_specification_ := &EarleyRule{
		name: '<null specification>'
	}
	mut rule_numeric_primary__1_ := &EarleyRule{
		name: '<numeric primary: #1>'
	}
	mut rule_numeric_primary__2_ := &EarleyRule{
		name: '<numeric primary: #2>'
	}
	mut rule_numeric_primary_ := &EarleyRule{
		name: '<numeric primary>'
	}
	mut rule_numeric_type_ := &EarleyRule{
		name: '<numeric type>'
	}
	mut rule_numeric_value_expression_base_ := &EarleyRule{
		name: '<numeric value expression base>'
	}
	mut rule_numeric_value_expression_dividend_ := &EarleyRule{
		name: '<numeric value expression dividend>'
	}
	mut rule_numeric_value_expression_divisor_ := &EarleyRule{
		name: '<numeric value expression divisor>'
	}
	mut rule_numeric_value_expression_exponent_ := &EarleyRule{
		name: '<numeric value expression exponent>'
	}
	mut rule_numeric_value_expression__1_ := &EarleyRule{
		name: '<numeric value expression: #1>'
	}
	mut rule_numeric_value_expression__2_ := &EarleyRule{
		name: '<numeric value expression: #2>'
	}
	mut rule_numeric_value_expression__3_ := &EarleyRule{
		name: '<numeric value expression: #3>'
	}
	mut rule_numeric_value_expression_ := &EarleyRule{
		name: '<numeric value expression>'
	}
	mut rule_numeric_value_function_ := &EarleyRule{
		name: '<numeric value function>'
	}
	mut rule_object_column_ := &EarleyRule{
		name: '<object column>'
	}
	mut rule_octet_length_expression__1_ := &EarleyRule{
		name: '<octet length expression: #1>'
	}
	mut rule_octet_length_expression_ := &EarleyRule{
		name: '<octet length expression>'
	}
	mut rule_offset_row_count_ := &EarleyRule{
		name: '<offset row count>'
	}
	mut rule_order_by_clause__1_ := &EarleyRule{
		name: '<order by clause: #1>'
	}
	mut rule_order_by_clause_ := &EarleyRule{
		name: '<order by clause>'
	}
	mut rule_ordering_specification__1_ := &EarleyRule{
		name: '<ordering specification: #1>'
	}
	mut rule_ordering_specification__2_ := &EarleyRule{
		name: '<ordering specification: #2>'
	}
	mut rule_ordering_specification_ := &EarleyRule{
		name: '<ordering specification>'
	}
	mut rule_ordinary_grouping_set_ := &EarleyRule{
		name: '<ordinary grouping set>'
	}
	mut rule_outer_join_type_ := &EarleyRule{
		name: '<outer join type>'
	}
	mut rule_parenthesized_boolean_value_expression__1_ := &EarleyRule{
		name: '<parenthesized boolean value expression: #1>'
	}
	mut rule_parenthesized_boolean_value_expression_ := &EarleyRule{
		name: '<parenthesized boolean value expression>'
	}
	mut rule_parenthesized_derived_column_list__1_ := &EarleyRule{
		name: '<parenthesized derived column list: #1>'
	}
	mut rule_parenthesized_derived_column_list_ := &EarleyRule{
		name: '<parenthesized derived column list>'
	}
	mut rule_parenthesized_value_expression__1_ := &EarleyRule{
		name: '<parenthesized value expression: #1>'
	}
	mut rule_parenthesized_value_expression_ := &EarleyRule{
		name: '<parenthesized value expression>'
	}
	mut rule_period_ := &EarleyRule{
		name: '<period>'
	}
	mut rule_plus_sign_ := &EarleyRule{
		name: '<plus sign>'
	}
	mut rule_position_expression_ := &EarleyRule{
		name: '<position expression>'
	}
	mut rule_power_function__1_ := &EarleyRule{
		name: '<power function: #1>'
	}
	mut rule_power_function_ := &EarleyRule{
		name: '<power function>'
	}
	mut rule_precision_ := &EarleyRule{
		name: '<precision>'
	}
	mut rule_predefined_type_ := &EarleyRule{
		name: '<predefined type>'
	}
	mut rule_predicate__1_ := &EarleyRule{
		name: '<predicate: #1>'
	}
	mut rule_predicate__2_ := &EarleyRule{
		name: '<predicate: #2>'
	}
	mut rule_predicate__3_ := &EarleyRule{
		name: '<predicate: #3>'
	}
	mut rule_predicate__4_ := &EarleyRule{
		name: '<predicate: #4>'
	}
	mut rule_predicate__5_ := &EarleyRule{
		name: '<predicate: #5>'
	}
	mut rule_predicate_ := &EarleyRule{
		name: '<predicate>'
	}
	mut rule_preparable_sql_data_statement_ := &EarleyRule{
		name: '<preparable SQL data statement>'
	}
	mut rule_preparable_sql_schema_statement_ := &EarleyRule{
		name: '<preparable SQL schema statement>'
	}
	mut rule_preparable_sql_session_statement_ := &EarleyRule{
		name: '<preparable SQL session statement>'
	}
	mut rule_preparable_sql_transaction_statement_ := &EarleyRule{
		name: '<preparable SQL transaction statement>'
	}
	mut rule_preparable_statement_ := &EarleyRule{
		name: '<preparable statement>'
	}
	mut rule_qualified_asterisk__1_ := &EarleyRule{
		name: '<qualified asterisk: #1>'
	}
	mut rule_qualified_asterisk_ := &EarleyRule{
		name: '<qualified asterisk>'
	}
	mut rule_qualified_identifier_ := &EarleyRule{
		name: '<qualified identifier>'
	}
	mut rule_qualified_join__1_ := &EarleyRule{
		name: '<qualified join: #1>'
	}
	mut rule_qualified_join__2_ := &EarleyRule{
		name: '<qualified join: #2>'
	}
	mut rule_qualified_join_ := &EarleyRule{
		name: '<qualified join>'
	}
	mut rule_query_expression_body_ := &EarleyRule{
		name: '<query expression body>'
	}
	mut rule_query_expression__1_ := &EarleyRule{
		name: '<query expression: #1>'
	}
	mut rule_query_expression__2_ := &EarleyRule{
		name: '<query expression: #2>'
	}
	mut rule_query_expression__3_ := &EarleyRule{
		name: '<query expression: #3>'
	}
	mut rule_query_expression__4_ := &EarleyRule{
		name: '<query expression: #4>'
	}
	mut rule_query_expression__5_ := &EarleyRule{
		name: '<query expression: #5>'
	}
	mut rule_query_expression__6_ := &EarleyRule{
		name: '<query expression: #6>'
	}
	mut rule_query_expression__7_ := &EarleyRule{
		name: '<query expression: #7>'
	}
	mut rule_query_expression__8_ := &EarleyRule{
		name: '<query expression: #8>'
	}
	mut rule_query_expression_ := &EarleyRule{
		name: '<query expression>'
	}
	mut rule_query_primary_ := &EarleyRule{
		name: '<query primary>'
	}
	mut rule_query_specification__1_ := &EarleyRule{
		name: '<query specification: #1>'
	}
	mut rule_query_specification_ := &EarleyRule{
		name: '<query specification>'
	}
	mut rule_query_term_ := &EarleyRule{
		name: '<query term>'
	}
	mut rule_regular_identifier__2_ := &EarleyRule{
		name: '<regular identifier: #2>'
	}
	mut rule_regular_identifier_ := &EarleyRule{
		name: '<regular identifier>'
	}
	mut rule_result_offset_clause__1_ := &EarleyRule{
		name: '<result offset clause: #1>'
	}
	mut rule_result_offset_clause_ := &EarleyRule{
		name: '<result offset clause>'
	}
	mut rule_right_paren_ := &EarleyRule{
		name: '<right paren>'
	}
	mut rule_rollback_statement__1_ := &EarleyRule{
		name: '<rollback statement: #1>'
	}
	mut rule_rollback_statement__2_ := &EarleyRule{
		name: '<rollback statement: #2>'
	}
	mut rule_rollback_statement_ := &EarleyRule{
		name: '<rollback statement>'
	}
	mut rule_routine_invocation__1_ := &EarleyRule{
		name: '<routine invocation: #1>'
	}
	mut rule_routine_invocation_ := &EarleyRule{
		name: '<routine invocation>'
	}
	mut rule_routine_name__1_ := &EarleyRule{
		name: '<routine name: #1>'
	}
	mut rule_routine_name_ := &EarleyRule{
		name: '<routine name>'
	}
	mut rule_row_or_rows_ := &EarleyRule{
		name: '<row or rows>'
	}
	mut rule_row_subquery_ := &EarleyRule{
		name: '<row subquery>'
	}
	mut rule_row_value_constructor_element_list__1_ := &EarleyRule{
		name: '<row value constructor element list: #1>'
	}
	mut rule_row_value_constructor_element_list__2_ := &EarleyRule{
		name: '<row value constructor element list: #2>'
	}
	mut rule_row_value_constructor_element_list_ := &EarleyRule{
		name: '<row value constructor element list>'
	}
	mut rule_row_value_constructor_element_ := &EarleyRule{
		name: '<row value constructor element>'
	}
	mut rule_row_value_constructor_predicand__1_ := &EarleyRule{
		name: '<row value constructor predicand: #1>'
	}
	mut rule_row_value_constructor_predicand__2_ := &EarleyRule{
		name: '<row value constructor predicand: #2>'
	}
	mut rule_row_value_constructor_predicand_ := &EarleyRule{
		name: '<row value constructor predicand>'
	}
	mut rule_row_value_constructor__1_ := &EarleyRule{
		name: '<row value constructor: #1>'
	}
	mut rule_row_value_constructor__2_ := &EarleyRule{
		name: '<row value constructor: #2>'
	}
	mut rule_row_value_constructor__3_ := &EarleyRule{
		name: '<row value constructor: #3>'
	}
	mut rule_row_value_constructor_ := &EarleyRule{
		name: '<row value constructor>'
	}
	mut rule_row_value_expression_list__1_ := &EarleyRule{
		name: '<row value expression list: #1>'
	}
	mut rule_row_value_expression_list__2_ := &EarleyRule{
		name: '<row value expression list: #2>'
	}
	mut rule_row_value_expression_list_ := &EarleyRule{
		name: '<row value expression list>'
	}
	mut rule_row_value_predicand_ := &EarleyRule{
		name: '<row value predicand>'
	}
	mut rule_schema_definition__1_ := &EarleyRule{
		name: '<schema definition: #1>'
	}
	mut rule_schema_definition_ := &EarleyRule{
		name: '<schema definition>'
	}
	mut rule_schema_name_characteristic__1_ := &EarleyRule{
		name: '<schema name characteristic: #1>'
	}
	mut rule_schema_name_characteristic_ := &EarleyRule{
		name: '<schema name characteristic>'
	}
	mut rule_schema_name_clause_ := &EarleyRule{
		name: '<schema name clause>'
	}
	mut rule_schema_name__1_ := &EarleyRule{
		name: '<schema name: #1>'
	}
	mut rule_schema_name_ := &EarleyRule{
		name: '<schema name>'
	}
	mut rule_schema_qualified_name__2_ := &EarleyRule{
		name: '<schema qualified name: #2>'
	}
	mut rule_schema_qualified_name_ := &EarleyRule{
		name: '<schema qualified name>'
	}
	mut rule_search_condition_ := &EarleyRule{
		name: '<search condition>'
	}
	mut rule_select_list__1_ := &EarleyRule{
		name: '<select list: #1>'
	}
	mut rule_select_list__3_ := &EarleyRule{
		name: '<select list: #3>'
	}
	mut rule_select_list_ := &EarleyRule{
		name: '<select list>'
	}
	mut rule_select_sublist__1_ := &EarleyRule{
		name: '<select sublist: #1>'
	}
	mut rule_select_sublist__2_ := &EarleyRule{
		name: '<select sublist: #2>'
	}
	mut rule_select_sublist_ := &EarleyRule{
		name: '<select sublist>'
	}
	mut rule_sequence_generator_cycle_option__1_ := &EarleyRule{
		name: '<sequence generator cycle option: #1>'
	}
	mut rule_sequence_generator_cycle_option__2_ := &EarleyRule{
		name: '<sequence generator cycle option: #2>'
	}
	mut rule_sequence_generator_cycle_option_ := &EarleyRule{
		name: '<sequence generator cycle option>'
	}
	mut rule_sequence_generator_definition__1_ := &EarleyRule{
		name: '<sequence generator definition: #1>'
	}
	mut rule_sequence_generator_definition__2_ := &EarleyRule{
		name: '<sequence generator definition: #2>'
	}
	mut rule_sequence_generator_definition_ := &EarleyRule{
		name: '<sequence generator definition>'
	}
	mut rule_sequence_generator_increment_by_option__1_ := &EarleyRule{
		name: '<sequence generator increment by option: #1>'
	}
	mut rule_sequence_generator_increment_by_option_ := &EarleyRule{
		name: '<sequence generator increment by option>'
	}
	mut rule_sequence_generator_increment_ := &EarleyRule{
		name: '<sequence generator increment>'
	}
	mut rule_sequence_generator_max_value_ := &EarleyRule{
		name: '<sequence generator max value>'
	}
	mut rule_sequence_generator_maxvalue_option__1_ := &EarleyRule{
		name: '<sequence generator maxvalue option: #1>'
	}
	mut rule_sequence_generator_maxvalue_option__2_ := &EarleyRule{
		name: '<sequence generator maxvalue option: #2>'
	}
	mut rule_sequence_generator_maxvalue_option_ := &EarleyRule{
		name: '<sequence generator maxvalue option>'
	}
	mut rule_sequence_generator_min_value_ := &EarleyRule{
		name: '<sequence generator min value>'
	}
	mut rule_sequence_generator_minvalue_option__1_ := &EarleyRule{
		name: '<sequence generator minvalue option: #1>'
	}
	mut rule_sequence_generator_minvalue_option__2_ := &EarleyRule{
		name: '<sequence generator minvalue option: #2>'
	}
	mut rule_sequence_generator_minvalue_option_ := &EarleyRule{
		name: '<sequence generator minvalue option>'
	}
	mut rule_sequence_generator_name__1_ := &EarleyRule{
		name: '<sequence generator name: #1>'
	}
	mut rule_sequence_generator_name_ := &EarleyRule{
		name: '<sequence generator name>'
	}
	mut rule_sequence_generator_option_ := &EarleyRule{
		name: '<sequence generator option>'
	}
	mut rule_sequence_generator_options_ := &EarleyRule{
		name: '<sequence generator options>'
	}
	mut rule_sequence_generator_restart_value_ := &EarleyRule{
		name: '<sequence generator restart value>'
	}
	mut rule_sequence_generator_start_value_ := &EarleyRule{
		name: '<sequence generator start value>'
	}
	mut rule_sequence_generator_start_with_option__1_ := &EarleyRule{
		name: '<sequence generator start with option: #1>'
	}
	mut rule_sequence_generator_start_with_option_ := &EarleyRule{
		name: '<sequence generator start with option>'
	}
	mut rule_set_catalog_statement__1_ := &EarleyRule{
		name: '<set catalog statement: #1>'
	}
	mut rule_set_catalog_statement_ := &EarleyRule{
		name: '<set catalog statement>'
	}
	mut rule_set_clause_list__2_ := &EarleyRule{
		name: '<set clause list: #2>'
	}
	mut rule_set_clause_list_ := &EarleyRule{
		name: '<set clause list>'
	}
	mut rule_set_clause__1_ := &EarleyRule{
		name: '<set clause: #1>'
	}
	mut rule_set_clause_ := &EarleyRule{
		name: '<set clause>'
	}
	mut rule_set_function_specification_ := &EarleyRule{
		name: '<set function specification>'
	}
	mut rule_set_function_type_ := &EarleyRule{
		name: '<set function type>'
	}
	mut rule_set_schema_statement__1_ := &EarleyRule{
		name: '<set schema statement: #1>'
	}
	mut rule_set_schema_statement_ := &EarleyRule{
		name: '<set schema statement>'
	}
	mut rule_set_target_ := &EarleyRule{
		name: '<set target>'
	}
	mut rule_sign_ := &EarleyRule{
		name: '<sign>'
	}
	mut rule_signed_numeric_literal__2_ := &EarleyRule{
		name: '<signed numeric literal: #2>'
	}
	mut rule_signed_numeric_literal_ := &EarleyRule{
		name: '<signed numeric literal>'
	}
	mut rule_similar_pattern_ := &EarleyRule{
		name: '<similar pattern>'
	}
	mut rule_similar_predicate_part_2__1_ := &EarleyRule{
		name: '<similar predicate part 2: #1>'
	}
	mut rule_similar_predicate_part_2__2_ := &EarleyRule{
		name: '<similar predicate part 2: #2>'
	}
	mut rule_similar_predicate_part_2_ := &EarleyRule{
		name: '<similar predicate part 2>'
	}
	mut rule_similar_predicate__1_ := &EarleyRule{
		name: '<similar predicate: #1>'
	}
	mut rule_similar_predicate_ := &EarleyRule{
		name: '<similar predicate>'
	}
	mut rule_simple_table_ := &EarleyRule{
		name: '<simple table>'
	}
	mut rule_simple_value_specification__1_ := &EarleyRule{
		name: '<simple value specification: #1>'
	}
	mut rule_simple_value_specification__2_ := &EarleyRule{
		name: '<simple value specification: #2>'
	}
	mut rule_simple_value_specification_ := &EarleyRule{
		name: '<simple value specification>'
	}
	mut rule_solidus_ := &EarleyRule{
		name: '<solidus>'
	}
	mut rule_sort_key_ := &EarleyRule{
		name: '<sort key>'
	}
	mut rule_sort_specification_list__1_ := &EarleyRule{
		name: '<sort specification list: #1>'
	}
	mut rule_sort_specification_list__2_ := &EarleyRule{
		name: '<sort specification list: #2>'
	}
	mut rule_sort_specification_list_ := &EarleyRule{
		name: '<sort specification list>'
	}
	mut rule_sort_specification__1_ := &EarleyRule{
		name: '<sort specification: #1>'
	}
	mut rule_sort_specification__2_ := &EarleyRule{
		name: '<sort specification: #2>'
	}
	mut rule_sort_specification_ := &EarleyRule{
		name: '<sort specification>'
	}
	mut rule_sql_argument_list__1_ := &EarleyRule{
		name: '<SQL argument list: #1>'
	}
	mut rule_sql_argument_list__2_ := &EarleyRule{
		name: '<SQL argument list: #2>'
	}
	mut rule_sql_argument_list__3_ := &EarleyRule{
		name: '<SQL argument list: #3>'
	}
	mut rule_sql_argument_list_ := &EarleyRule{
		name: '<SQL argument list>'
	}
	mut rule_sql_argument_ := &EarleyRule{
		name: '<SQL argument>'
	}
	mut rule_sql_schema_definition_statement_ := &EarleyRule{
		name: '<SQL schema definition statement>'
	}
	mut rule_sql_schema_manipulation_statement__3_ := &EarleyRule{
		name: '<SQL schema manipulation statement: #3>'
	}
	mut rule_sql_schema_manipulation_statement_ := &EarleyRule{
		name: '<SQL schema manipulation statement>'
	}
	mut rule_sql_schema_statement_ := &EarleyRule{
		name: '<SQL schema statement>'
	}
	mut rule_sql_session_statement_ := &EarleyRule{
		name: '<SQL session statement>'
	}
	mut rule_sql_transaction_statement_ := &EarleyRule{
		name: '<SQL transaction statement>'
	}
	mut rule_square_root__1_ := &EarleyRule{
		name: '<square root: #1>'
	}
	mut rule_square_root_ := &EarleyRule{
		name: '<square root>'
	}
	mut rule_start_position_ := &EarleyRule{
		name: '<start position>'
	}
	mut rule_start_transaction_statement__1_ := &EarleyRule{
		name: '<start transaction statement: #1>'
	}
	mut rule_start_transaction_statement_ := &EarleyRule{
		name: '<start transaction statement>'
	}
	mut rule_string_length_ := &EarleyRule{
		name: '<string length>'
	}
	mut rule_string_value_expression_ := &EarleyRule{
		name: '<string value expression>'
	}
	mut rule_string_value_function_ := &EarleyRule{
		name: '<string value function>'
	}
	mut rule_subquery__1_ := &EarleyRule{
		name: '<subquery: #1>'
	}
	mut rule_subquery_ := &EarleyRule{
		name: '<subquery>'
	}
	mut rule_table_constraint_definition_ := &EarleyRule{
		name: '<table constraint definition>'
	}
	mut rule_table_constraint_ := &EarleyRule{
		name: '<table constraint>'
	}
	mut rule_table_contents_source_ := &EarleyRule{
		name: '<table contents source>'
	}
	mut rule_table_definition__1_ := &EarleyRule{
		name: '<table definition: #1>'
	}
	mut rule_table_definition_ := &EarleyRule{
		name: '<table definition>'
	}
	mut rule_table_element_list__1_ := &EarleyRule{
		name: '<table element list: #1>'
	}
	mut rule_table_element_list_ := &EarleyRule{
		name: '<table element list>'
	}
	mut rule_table_element_ := &EarleyRule{
		name: '<table element>'
	}
	mut rule_table_elements__1_ := &EarleyRule{
		name: '<table elements: #1>'
	}
	mut rule_table_elements__2_ := &EarleyRule{
		name: '<table elements: #2>'
	}
	mut rule_table_elements_ := &EarleyRule{
		name: '<table elements>'
	}
	mut rule_table_expression__1_ := &EarleyRule{
		name: '<table expression: #1>'
	}
	mut rule_table_expression__2_ := &EarleyRule{
		name: '<table expression: #2>'
	}
	mut rule_table_expression__3_ := &EarleyRule{
		name: '<table expression: #3>'
	}
	mut rule_table_expression__4_ := &EarleyRule{
		name: '<table expression: #4>'
	}
	mut rule_table_expression_ := &EarleyRule{
		name: '<table expression>'
	}
	mut rule_table_factor_ := &EarleyRule{
		name: '<table factor>'
	}
	mut rule_table_name__1_ := &EarleyRule{
		name: '<table name: #1>'
	}
	mut rule_table_name_ := &EarleyRule{
		name: '<table name>'
	}
	mut rule_table_or_query_name_ := &EarleyRule{
		name: '<table or query name>'
	}
	mut rule_table_primary__1_ := &EarleyRule{
		name: '<table primary: #1>'
	}
	mut rule_table_primary__3_ := &EarleyRule{
		name: '<table primary: #3>'
	}
	mut rule_table_primary_ := &EarleyRule{
		name: '<table primary>'
	}
	mut rule_table_reference_list_ := &EarleyRule{
		name: '<table reference list>'
	}
	mut rule_table_reference__1_ := &EarleyRule{
		name: '<table reference: #1>'
	}
	mut rule_table_reference__2_ := &EarleyRule{
		name: '<table reference: #2>'
	}
	mut rule_table_reference_ := &EarleyRule{
		name: '<table reference>'
	}
	mut rule_table_row_value_expression_ := &EarleyRule{
		name: '<table row value expression>'
	}
	mut rule_table_subquery_ := &EarleyRule{
		name: '<table subquery>'
	}
	mut rule_table_value_constructor__1_ := &EarleyRule{
		name: '<table value constructor: #1>'
	}
	mut rule_table_value_constructor_ := &EarleyRule{
		name: '<table value constructor>'
	}
	mut rule_target_table_ := &EarleyRule{
		name: '<target table>'
	}
	mut rule_term__1_ := &EarleyRule{
		name: '<term: #1>'
	}
	mut rule_term__2_ := &EarleyRule{
		name: '<term: #2>'
	}
	mut rule_term__3_ := &EarleyRule{
		name: '<term: #3>'
	}
	mut rule_term_ := &EarleyRule{
		name: '<term>'
	}
	mut rule_time_fractional_seconds_precision_ := &EarleyRule{
		name: '<time fractional seconds precision>'
	}
	mut rule_time_literal__1_ := &EarleyRule{
		name: '<time literal: #1>'
	}
	mut rule_time_literal_ := &EarleyRule{
		name: '<time literal>'
	}
	mut rule_time_precision_ := &EarleyRule{
		name: '<time precision>'
	}
	mut rule_time_string_ := &EarleyRule{
		name: '<time string>'
	}
	mut rule_timestamp_literal__1_ := &EarleyRule{
		name: '<timestamp literal: #1>'
	}
	mut rule_timestamp_literal_ := &EarleyRule{
		name: '<timestamp literal>'
	}
	mut rule_timestamp_precision_ := &EarleyRule{
		name: '<timestamp precision>'
	}
	mut rule_timestamp_string_ := &EarleyRule{
		name: '<timestamp string>'
	}
	mut rule_trigonometric_function_name_ := &EarleyRule{
		name: '<trigonometric function name>'
	}
	mut rule_trigonometric_function__1_ := &EarleyRule{
		name: '<trigonometric function: #1>'
	}
	mut rule_trigonometric_function_ := &EarleyRule{
		name: '<trigonometric function>'
	}
	mut rule_trim_character_ := &EarleyRule{
		name: '<trim character>'
	}
	mut rule_trim_function__1_ := &EarleyRule{
		name: '<trim function: #1>'
	}
	mut rule_trim_function_ := &EarleyRule{
		name: '<trim function>'
	}
	mut rule_trim_operands__1_ := &EarleyRule{
		name: '<trim operands: #1>'
	}
	mut rule_trim_operands__2_ := &EarleyRule{
		name: '<trim operands: #2>'
	}
	mut rule_trim_operands__3_ := &EarleyRule{
		name: '<trim operands: #3>'
	}
	mut rule_trim_operands__4_ := &EarleyRule{
		name: '<trim operands: #4>'
	}
	mut rule_trim_operands__5_ := &EarleyRule{
		name: '<trim operands: #5>'
	}
	mut rule_trim_operands_ := &EarleyRule{
		name: '<trim operands>'
	}
	mut rule_trim_source_ := &EarleyRule{
		name: '<trim source>'
	}
	mut rule_trim_specification_ := &EarleyRule{
		name: '<trim specification>'
	}
	mut rule_truth_value__1_ := &EarleyRule{
		name: '<truth value: #1>'
	}
	mut rule_truth_value__2_ := &EarleyRule{
		name: '<truth value: #2>'
	}
	mut rule_truth_value__3_ := &EarleyRule{
		name: '<truth value: #3>'
	}
	mut rule_truth_value_ := &EarleyRule{
		name: '<truth value>'
	}
	mut rule_unique_column_list_ := &EarleyRule{
		name: '<unique column list>'
	}
	mut rule_unique_constraint_definition__1_ := &EarleyRule{
		name: '<unique constraint definition: #1>'
	}
	mut rule_unique_constraint_definition_ := &EarleyRule{
		name: '<unique constraint definition>'
	}
	mut rule_unique_specification__1_ := &EarleyRule{
		name: '<unique specification: #1>'
	}
	mut rule_unique_specification_ := &EarleyRule{
		name: '<unique specification>'
	}
	mut rule_unqualified_schema_name__1_ := &EarleyRule{
		name: '<unqualified schema name: #1>'
	}
	mut rule_unqualified_schema_name_ := &EarleyRule{
		name: '<unqualified schema name>'
	}
	mut rule_unsigned_integer_ := &EarleyRule{
		name: '<unsigned integer>'
	}
	mut rule_unsigned_literal_ := &EarleyRule{
		name: '<unsigned literal>'
	}
	mut rule_unsigned_numeric_literal_ := &EarleyRule{
		name: '<unsigned numeric literal>'
	}
	mut rule_unsigned_value_specification__1_ := &EarleyRule{
		name: '<unsigned value specification: #1>'
	}
	mut rule_unsigned_value_specification__2_ := &EarleyRule{
		name: '<unsigned value specification: #2>'
	}
	mut rule_unsigned_value_specification_ := &EarleyRule{
		name: '<unsigned value specification>'
	}
	mut rule_update_source__1_ := &EarleyRule{
		name: '<update source: #1>'
	}
	mut rule_update_source__2_ := &EarleyRule{
		name: '<update source: #2>'
	}
	mut rule_update_source_ := &EarleyRule{
		name: '<update source>'
	}
	mut rule_update_statement_searched__1_ := &EarleyRule{
		name: '<update statement: searched: #1>'
	}
	mut rule_update_statement_searched__2_ := &EarleyRule{
		name: '<update statement: searched: #2>'
	}
	mut rule_update_statement_searched_ := &EarleyRule{
		name: '<update statement: searched>'
	}
	mut rule_update_target_ := &EarleyRule{
		name: '<update target>'
	}
	mut rule_value_expression_list__1_ := &EarleyRule{
		name: '<value expression list: #1>'
	}
	mut rule_value_expression_list__2_ := &EarleyRule{
		name: '<value expression list: #2>'
	}
	mut rule_value_expression_list_ := &EarleyRule{
		name: '<value expression list>'
	}
	mut rule_value_expression_primary__1_ := &EarleyRule{
		name: '<value expression primary: #1>'
	}
	mut rule_value_expression_primary__2_ := &EarleyRule{
		name: '<value expression primary: #2>'
	}
	mut rule_value_expression_primary_ := &EarleyRule{
		name: '<value expression primary>'
	}
	mut rule_value_expression__1_ := &EarleyRule{
		name: '<value expression: #1>'
	}
	mut rule_value_expression__2_ := &EarleyRule{
		name: '<value expression: #2>'
	}
	mut rule_value_expression_ := &EarleyRule{
		name: '<value expression>'
	}
	mut rule_value_specification__1_ := &EarleyRule{
		name: '<value specification: #1>'
	}
	mut rule_value_specification__2_ := &EarleyRule{
		name: '<value specification: #2>'
	}
	mut rule_value_specification_ := &EarleyRule{
		name: '<value specification>'
	}
	mut rule_where_clause__1_ := &EarleyRule{
		name: '<where clause: #1>'
	}
	mut rule_where_clause_ := &EarleyRule{
		name: '<where clause>'
	}
	mut rule_with_or_without_time_zone__1_ := &EarleyRule{
		name: '<with or without time zone: #1>'
	}
	mut rule_with_or_without_time_zone__2_ := &EarleyRule{
		name: '<with or without time zone: #2>'
	}
	mut rule_with_or_without_time_zone_ := &EarleyRule{
		name: '<with or without time zone>'
	}
	mut rule__identifier := &EarleyRule{
		name: '^identifier'
	}
	mut rule__integer := &EarleyRule{
		name: '^integer'
	}
	mut rule__string := &EarleyRule{
		name: '^string'
	}
	mut rule_a := &EarleyRule{
		name: 'A'
	}
	mut rule_abs := &EarleyRule{
		name: 'ABS'
	}
	mut rule_absolute := &EarleyRule{
		name: 'ABSOLUTE'
	}
	mut rule_acos := &EarleyRule{
		name: 'ACOS'
	}
	mut rule_action := &EarleyRule{
		name: 'ACTION'
	}
	mut rule_ada := &EarleyRule{
		name: 'ADA'
	}
	mut rule_add := &EarleyRule{
		name: 'ADD'
	}
	mut rule_admin := &EarleyRule{
		name: 'ADMIN'
	}
	mut rule_after := &EarleyRule{
		name: 'AFTER'
	}
	mut rule_alter := &EarleyRule{
		name: 'ALTER'
	}
	mut rule_always := &EarleyRule{
		name: 'ALWAYS'
	}
	mut rule_and := &EarleyRule{
		name: 'AND'
	}
	mut rule_as := &EarleyRule{
		name: 'AS'
	}
	mut rule_asc := &EarleyRule{
		name: 'ASC'
	}
	mut rule_asin := &EarleyRule{
		name: 'ASIN'
	}
	mut rule_assertion := &EarleyRule{
		name: 'ASSERTION'
	}
	mut rule_assignment := &EarleyRule{
		name: 'ASSIGNMENT'
	}
	mut rule_asymmetric := &EarleyRule{
		name: 'ASYMMETRIC'
	}
	mut rule_atan := &EarleyRule{
		name: 'ATAN'
	}
	mut rule_attribute := &EarleyRule{
		name: 'ATTRIBUTE'
	}
	mut rule_attributes := &EarleyRule{
		name: 'ATTRIBUTES'
	}
	mut rule_avg := &EarleyRule{
		name: 'AVG'
	}
	mut rule_before := &EarleyRule{
		name: 'BEFORE'
	}
	mut rule_bernoulli := &EarleyRule{
		name: 'BERNOULLI'
	}
	mut rule_between := &EarleyRule{
		name: 'BETWEEN'
	}
	mut rule_bigint := &EarleyRule{
		name: 'BIGINT'
	}
	mut rule_boolean := &EarleyRule{
		name: 'BOOLEAN'
	}
	mut rule_both := &EarleyRule{
		name: 'BOTH'
	}
	mut rule_breadth := &EarleyRule{
		name: 'BREADTH'
	}
	mut rule_by := &EarleyRule{
		name: 'BY'
	}
	mut rule_c := &EarleyRule{
		name: 'C'
	}
	mut rule_cascade := &EarleyRule{
		name: 'CASCADE'
	}
	mut rule_cast := &EarleyRule{
		name: 'CAST'
	}
	mut rule_catalog := &EarleyRule{
		name: 'CATALOG'
	}
	mut rule_catalog_name := &EarleyRule{
		name: 'CATALOG_NAME'
	}
	mut rule_ceil := &EarleyRule{
		name: 'CEIL'
	}
	mut rule_ceiling := &EarleyRule{
		name: 'CEILING'
	}
	mut rule_chain := &EarleyRule{
		name: 'CHAIN'
	}
	mut rule_chaining := &EarleyRule{
		name: 'CHAINING'
	}
	mut rule_char := &EarleyRule{
		name: 'CHAR'
	}
	mut rule_char_length := &EarleyRule{
		name: 'CHAR_LENGTH'
	}
	mut rule_character := &EarleyRule{
		name: 'CHARACTER'
	}
	mut rule_character_length := &EarleyRule{
		name: 'CHARACTER_LENGTH'
	}
	mut rule_character_set_catalog := &EarleyRule{
		name: 'CHARACTER_SET_CATALOG'
	}
	mut rule_character_set_name := &EarleyRule{
		name: 'CHARACTER_SET_NAME'
	}
	mut rule_character_set_schema := &EarleyRule{
		name: 'CHARACTER_SET_SCHEMA'
	}
	mut rule_characteristics := &EarleyRule{
		name: 'CHARACTERISTICS'
	}
	mut rule_characters := &EarleyRule{
		name: 'CHARACTERS'
	}
	mut rule_class_origin := &EarleyRule{
		name: 'CLASS_ORIGIN'
	}
	mut rule_coalesce := &EarleyRule{
		name: 'COALESCE'
	}
	mut rule_cobol := &EarleyRule{
		name: 'COBOL'
	}
	mut rule_collation := &EarleyRule{
		name: 'COLLATION'
	}
	mut rule_collation_catalog := &EarleyRule{
		name: 'COLLATION_CATALOG'
	}
	mut rule_collation_name := &EarleyRule{
		name: 'COLLATION_NAME'
	}
	mut rule_collation_schema := &EarleyRule{
		name: 'COLLATION_SCHEMA'
	}
	mut rule_column_name := &EarleyRule{
		name: 'COLUMN_NAME'
	}
	mut rule_columns := &EarleyRule{
		name: 'COLUMNS'
	}
	mut rule_command_function := &EarleyRule{
		name: 'COMMAND_FUNCTION'
	}
	mut rule_command_function_code := &EarleyRule{
		name: 'COMMAND_FUNCTION_CODE'
	}
	mut rule_commit := &EarleyRule{
		name: 'COMMIT'
	}
	mut rule_committed := &EarleyRule{
		name: 'COMMITTED'
	}
	mut rule_condition_number := &EarleyRule{
		name: 'CONDITION_NUMBER'
	}
	mut rule_conditional := &EarleyRule{
		name: 'CONDITIONAL'
	}
	mut rule_connection := &EarleyRule{
		name: 'CONNECTION'
	}
	mut rule_connection_name := &EarleyRule{
		name: 'CONNECTION_NAME'
	}
	mut rule_constraint_catalog := &EarleyRule{
		name: 'CONSTRAINT_CATALOG'
	}
	mut rule_constraint_name := &EarleyRule{
		name: 'CONSTRAINT_NAME'
	}
	mut rule_constraint_schema := &EarleyRule{
		name: 'CONSTRAINT_SCHEMA'
	}
	mut rule_constraints := &EarleyRule{
		name: 'CONSTRAINTS'
	}
	mut rule_constructor := &EarleyRule{
		name: 'CONSTRUCTOR'
	}
	mut rule_continue := &EarleyRule{
		name: 'CONTINUE'
	}
	mut rule_cos := &EarleyRule{
		name: 'COS'
	}
	mut rule_cosh := &EarleyRule{
		name: 'COSH'
	}
	mut rule_count := &EarleyRule{
		name: 'COUNT'
	}
	mut rule_create := &EarleyRule{
		name: 'CREATE'
	}
	mut rule_current_catalog := &EarleyRule{
		name: 'CURRENT_CATALOG'
	}
	mut rule_current_date := &EarleyRule{
		name: 'CURRENT_DATE'
	}
	mut rule_current_schema := &EarleyRule{
		name: 'CURRENT_SCHEMA'
	}
	mut rule_current_time := &EarleyRule{
		name: 'CURRENT_TIME'
	}
	mut rule_current_timestamp := &EarleyRule{
		name: 'CURRENT_TIMESTAMP'
	}
	mut rule_cursor_name := &EarleyRule{
		name: 'CURSOR_NAME'
	}
	mut rule_cycle := &EarleyRule{
		name: 'CYCLE'
	}
	mut rule_data := &EarleyRule{
		name: 'DATA'
	}
	mut rule_date := &EarleyRule{
		name: 'DATE'
	}
	mut rule_datetime_interval_code := &EarleyRule{
		name: 'DATETIME_INTERVAL_CODE'
	}
	mut rule_datetime_interval_precision := &EarleyRule{
		name: 'DATETIME_INTERVAL_PRECISION'
	}
	mut rule_defaults := &EarleyRule{
		name: 'DEFAULTS'
	}
	mut rule_deferrable := &EarleyRule{
		name: 'DEFERRABLE'
	}
	mut rule_deferred := &EarleyRule{
		name: 'DEFERRED'
	}
	mut rule_defined := &EarleyRule{
		name: 'DEFINED'
	}
	mut rule_definer := &EarleyRule{
		name: 'DEFINER'
	}
	mut rule_degree := &EarleyRule{
		name: 'DEGREE'
	}
	mut rule_delete := &EarleyRule{
		name: 'DELETE'
	}
	mut rule_depth := &EarleyRule{
		name: 'DEPTH'
	}
	mut rule_derived := &EarleyRule{
		name: 'DERIVED'
	}
	mut rule_desc := &EarleyRule{
		name: 'DESC'
	}
	mut rule_describe_catalog := &EarleyRule{
		name: 'DESCRIBE_CATALOG'
	}
	mut rule_describe_name := &EarleyRule{
		name: 'DESCRIBE_NAME'
	}
	mut rule_describe_procedure_specific_catalog := &EarleyRule{
		name: 'DESCRIBE_PROCEDURE_SPECIFIC_CATALOG'
	}
	mut rule_describe_procedure_specific_name := &EarleyRule{
		name: 'DESCRIBE_PROCEDURE_SPECIFIC_NAME'
	}
	mut rule_describe_procedure_specific_schema := &EarleyRule{
		name: 'DESCRIBE_PROCEDURE_SPECIFIC_SCHEMA'
	}
	mut rule_describe_schema := &EarleyRule{
		name: 'DESCRIBE_SCHEMA'
	}
	mut rule_descriptor := &EarleyRule{
		name: 'DESCRIPTOR'
	}
	mut rule_diagnostics := &EarleyRule{
		name: 'DIAGNOSTICS'
	}
	mut rule_dispatch := &EarleyRule{
		name: 'DISPATCH'
	}
	mut rule_domain := &EarleyRule{
		name: 'DOMAIN'
	}
	mut rule_double := &EarleyRule{
		name: 'DOUBLE'
	}
	mut rule_drop := &EarleyRule{
		name: 'DROP'
	}
	mut rule_dynamic_function := &EarleyRule{
		name: 'DYNAMIC_FUNCTION'
	}
	mut rule_dynamic_function_code := &EarleyRule{
		name: 'DYNAMIC_FUNCTION_CODE'
	}
	mut rule_encoding := &EarleyRule{
		name: 'ENCODING'
	}
	mut rule_enforced := &EarleyRule{
		name: 'ENFORCED'
	}
	mut rule_error := &EarleyRule{
		name: 'ERROR'
	}
	mut rule_exclude := &EarleyRule{
		name: 'EXCLUDE'
	}
	mut rule_excluding := &EarleyRule{
		name: 'EXCLUDING'
	}
	mut rule_exp := &EarleyRule{
		name: 'EXP'
	}
	mut rule_expression := &EarleyRule{
		name: 'EXPRESSION'
	}
	mut rule_false := &EarleyRule{
		name: 'FALSE'
	}
	mut rule_fetch := &EarleyRule{
		name: 'FETCH'
	}
	mut rule_final := &EarleyRule{
		name: 'FINAL'
	}
	mut rule_finish := &EarleyRule{
		name: 'FINISH'
	}
	mut rule_finish_catalog := &EarleyRule{
		name: 'FINISH_CATALOG'
	}
	mut rule_finish_name := &EarleyRule{
		name: 'FINISH_NAME'
	}
	mut rule_finish_procedure_specific_catalog := &EarleyRule{
		name: 'FINISH_PROCEDURE_SPECIFIC_CATALOG'
	}
	mut rule_finish_procedure_specific_name := &EarleyRule{
		name: 'FINISH_PROCEDURE_SPECIFIC_NAME'
	}
	mut rule_finish_procedure_specific_schema := &EarleyRule{
		name: 'FINISH_PROCEDURE_SPECIFIC_SCHEMA'
	}
	mut rule_finish_schema := &EarleyRule{
		name: 'FINISH_SCHEMA'
	}
	mut rule_first := &EarleyRule{
		name: 'FIRST'
	}
	mut rule_flag := &EarleyRule{
		name: 'FLAG'
	}
	mut rule_float := &EarleyRule{
		name: 'FLOAT'
	}
	mut rule_floor := &EarleyRule{
		name: 'FLOOR'
	}
	mut rule_following := &EarleyRule{
		name: 'FOLLOWING'
	}
	mut rule_for := &EarleyRule{
		name: 'FOR'
	}
	mut rule_format := &EarleyRule{
		name: 'FORMAT'
	}
	mut rule_fortran := &EarleyRule{
		name: 'FORTRAN'
	}
	mut rule_found := &EarleyRule{
		name: 'FOUND'
	}
	mut rule_from := &EarleyRule{
		name: 'FROM'
	}
	mut rule_fulfill := &EarleyRule{
		name: 'FULFILL'
	}
	mut rule_fulfill_catalog := &EarleyRule{
		name: 'FULFILL_CATALOG'
	}
	mut rule_fulfill_name := &EarleyRule{
		name: 'FULFILL_NAME'
	}
	mut rule_fulfill_procedure_specific_catalog := &EarleyRule{
		name: 'FULFILL_PROCEDURE_SPECIFIC_CATALOG'
	}
	mut rule_fulfill_procedure_specific_name := &EarleyRule{
		name: 'FULFILL_PROCEDURE_SPECIFIC_NAME'
	}
	mut rule_fulfill_procedure_specific_schema := &EarleyRule{
		name: 'FULFILL_PROCEDURE_SPECIFIC_SCHEMA'
	}
	mut rule_fulfill_schema := &EarleyRule{
		name: 'FULFILL_SCHEMA'
	}
	mut rule_g := &EarleyRule{
		name: 'G'
	}
	mut rule_general := &EarleyRule{
		name: 'GENERAL'
	}
	mut rule_generated := &EarleyRule{
		name: 'GENERATED'
	}
	mut rule_go := &EarleyRule{
		name: 'GO'
	}
	mut rule_goto := &EarleyRule{
		name: 'GOTO'
	}
	mut rule_granted := &EarleyRule{
		name: 'GRANTED'
	}
	mut rule_group := &EarleyRule{
		name: 'GROUP'
	}
	mut rule_has_pass_through_columns := &EarleyRule{
		name: 'HAS_PASS_THROUGH_COLUMNS'
	}
	mut rule_has_pass_thru_cols := &EarleyRule{
		name: 'HAS_PASS_THRU_COLS'
	}
	mut rule_hierarchy := &EarleyRule{
		name: 'HIERARCHY'
	}
	mut rule_ignore := &EarleyRule{
		name: 'IGNORE'
	}
	mut rule_immediate := &EarleyRule{
		name: 'IMMEDIATE'
	}
	mut rule_immediately := &EarleyRule{
		name: 'IMMEDIATELY'
	}
	mut rule_implementation := &EarleyRule{
		name: 'IMPLEMENTATION'
	}
	mut rule_in := &EarleyRule{
		name: 'IN'
	}
	mut rule_including := &EarleyRule{
		name: 'INCLUDING'
	}
	mut rule_increment := &EarleyRule{
		name: 'INCREMENT'
	}
	mut rule_initially := &EarleyRule{
		name: 'INITIALLY'
	}
	mut rule_inner := &EarleyRule{
		name: 'INNER'
	}
	mut rule_input := &EarleyRule{
		name: 'INPUT'
	}
	mut rule_insert := &EarleyRule{
		name: 'INSERT'
	}
	mut rule_instance := &EarleyRule{
		name: 'INSTANCE'
	}
	mut rule_instantiable := &EarleyRule{
		name: 'INSTANTIABLE'
	}
	mut rule_instead := &EarleyRule{
		name: 'INSTEAD'
	}
	mut rule_int := &EarleyRule{
		name: 'INT'
	}
	mut rule_integer := &EarleyRule{
		name: 'INTEGER'
	}
	mut rule_into := &EarleyRule{
		name: 'INTO'
	}
	mut rule_invoker := &EarleyRule{
		name: 'INVOKER'
	}
	mut rule_is := &EarleyRule{
		name: 'IS'
	}
	mut rule_is_prunable := &EarleyRule{
		name: 'IS_PRUNABLE'
	}
	mut rule_isolation := &EarleyRule{
		name: 'ISOLATION'
	}
	mut rule_join := &EarleyRule{
		name: 'JOIN'
	}
	mut rule_json := &EarleyRule{
		name: 'JSON'
	}
	mut rule_k := &EarleyRule{
		name: 'K'
	}
	mut rule_keep := &EarleyRule{
		name: 'KEEP'
	}
	mut rule_key := &EarleyRule{
		name: 'KEY'
	}
	mut rule_key_member := &EarleyRule{
		name: 'KEY_MEMBER'
	}
	mut rule_key_type := &EarleyRule{
		name: 'KEY_TYPE'
	}
	mut rule_keys := &EarleyRule{
		name: 'KEYS'
	}
	mut rule_last := &EarleyRule{
		name: 'LAST'
	}
	mut rule_leading := &EarleyRule{
		name: 'LEADING'
	}
	mut rule_left := &EarleyRule{
		name: 'LEFT'
	}
	mut rule_length := &EarleyRule{
		name: 'LENGTH'
	}
	mut rule_level := &EarleyRule{
		name: 'LEVEL'
	}
	mut rule_like := &EarleyRule{
		name: 'LIKE'
	}
	mut rule_ln := &EarleyRule{
		name: 'LN'
	}
	mut rule_localtime := &EarleyRule{
		name: 'LOCALTIME'
	}
	mut rule_localtimestamp := &EarleyRule{
		name: 'LOCALTIMESTAMP'
	}
	mut rule_locator := &EarleyRule{
		name: 'LOCATOR'
	}
	mut rule_log10 := &EarleyRule{
		name: 'LOG10'
	}
	mut rule_lower := &EarleyRule{
		name: 'LOWER'
	}
	mut rule_m := &EarleyRule{
		name: 'M'
	}
	mut rule_map := &EarleyRule{
		name: 'MAP'
	}
	mut rule_matched := &EarleyRule{
		name: 'MATCHED'
	}
	mut rule_max := &EarleyRule{
		name: 'MAX'
	}
	mut rule_maxvalue := &EarleyRule{
		name: 'MAXVALUE'
	}
	mut rule_message_length := &EarleyRule{
		name: 'MESSAGE_LENGTH'
	}
	mut rule_message_octet_length := &EarleyRule{
		name: 'MESSAGE_OCTET_LENGTH'
	}
	mut rule_message_text := &EarleyRule{
		name: 'MESSAGE_TEXT'
	}
	mut rule_min := &EarleyRule{
		name: 'MIN'
	}
	mut rule_minvalue := &EarleyRule{
		name: 'MINVALUE'
	}
	mut rule_mod := &EarleyRule{
		name: 'MOD'
	}
	mut rule_more := &EarleyRule{
		name: 'MORE'
	}
	mut rule_mumps := &EarleyRule{
		name: 'MUMPS'
	}
	mut rule_name := &EarleyRule{
		name: 'NAME'
	}
	mut rule_names := &EarleyRule{
		name: 'NAMES'
	}
	mut rule_nested := &EarleyRule{
		name: 'NESTED'
	}
	mut rule_nesting := &EarleyRule{
		name: 'NESTING'
	}
	mut rule_next := &EarleyRule{
		name: 'NEXT'
	}
	mut rule_nfc := &EarleyRule{
		name: 'NFC'
	}
	mut rule_nfd := &EarleyRule{
		name: 'NFD'
	}
	mut rule_nfkc := &EarleyRule{
		name: 'NFKC'
	}
	mut rule_nfkd := &EarleyRule{
		name: 'NFKD'
	}
	mut rule_no := &EarleyRule{
		name: 'NO'
	}
	mut rule_normalized := &EarleyRule{
		name: 'NORMALIZED'
	}
	mut rule_not := &EarleyRule{
		name: 'NOT'
	}
	mut rule_null := &EarleyRule{
		name: 'NULL'
	}
	mut rule_nullable := &EarleyRule{
		name: 'NULLABLE'
	}
	mut rule_nullif := &EarleyRule{
		name: 'NULLIF'
	}
	mut rule_nulls := &EarleyRule{
		name: 'NULLS'
	}
	mut rule_number := &EarleyRule{
		name: 'NUMBER'
	}
	mut rule_object := &EarleyRule{
		name: 'OBJECT'
	}
	mut rule_octet_length := &EarleyRule{
		name: 'OCTET_LENGTH'
	}
	mut rule_octets := &EarleyRule{
		name: 'OCTETS'
	}
	mut rule_offset := &EarleyRule{
		name: 'OFFSET'
	}
	mut rule_on := &EarleyRule{
		name: 'ON'
	}
	mut rule_only := &EarleyRule{
		name: 'ONLY'
	}
	mut rule_option := &EarleyRule{
		name: 'OPTION'
	}
	mut rule_options := &EarleyRule{
		name: 'OPTIONS'
	}
	mut rule_or := &EarleyRule{
		name: 'OR'
	}
	mut rule_order := &EarleyRule{
		name: 'ORDER'
	}
	mut rule_ordering := &EarleyRule{
		name: 'ORDERING'
	}
	mut rule_ordinality := &EarleyRule{
		name: 'ORDINALITY'
	}
	mut rule_others := &EarleyRule{
		name: 'OTHERS'
	}
	mut rule_outer := &EarleyRule{
		name: 'OUTER'
	}
	mut rule_output := &EarleyRule{
		name: 'OUTPUT'
	}
	mut rule_overflow := &EarleyRule{
		name: 'OVERFLOW'
	}
	mut rule_overriding := &EarleyRule{
		name: 'OVERRIDING'
	}
	mut rule_p := &EarleyRule{
		name: 'P'
	}
	mut rule_pad := &EarleyRule{
		name: 'PAD'
	}
	mut rule_parameter_mode := &EarleyRule{
		name: 'PARAMETER_MODE'
	}
	mut rule_parameter_name := &EarleyRule{
		name: 'PARAMETER_NAME'
	}
	mut rule_parameter_ordinal_position := &EarleyRule{
		name: 'PARAMETER_ORDINAL_POSITION'
	}
	mut rule_parameter_specific_catalog := &EarleyRule{
		name: 'PARAMETER_SPECIFIC_CATALOG'
	}
	mut rule_parameter_specific_name := &EarleyRule{
		name: 'PARAMETER_SPECIFIC_NAME'
	}
	mut rule_parameter_specific_schema := &EarleyRule{
		name: 'PARAMETER_SPECIFIC_SCHEMA'
	}
	mut rule_partial := &EarleyRule{
		name: 'PARTIAL'
	}
	mut rule_pascal := &EarleyRule{
		name: 'PASCAL'
	}
	mut rule_pass := &EarleyRule{
		name: 'PASS'
	}
	mut rule_passing := &EarleyRule{
		name: 'PASSING'
	}
	mut rule_past := &EarleyRule{
		name: 'PAST'
	}
	mut rule_path := &EarleyRule{
		name: 'PATH'
	}
	mut rule_placing := &EarleyRule{
		name: 'PLACING'
	}
	mut rule_plan := &EarleyRule{
		name: 'PLAN'
	}
	mut rule_pli := &EarleyRule{
		name: 'PLI'
	}
	mut rule_position := &EarleyRule{
		name: 'POSITION'
	}
	mut rule_power := &EarleyRule{
		name: 'POWER'
	}
	mut rule_preceding := &EarleyRule{
		name: 'PRECEDING'
	}
	mut rule_precision := &EarleyRule{
		name: 'PRECISION'
	}
	mut rule_preserve := &EarleyRule{
		name: 'PRESERVE'
	}
	mut rule_primary := &EarleyRule{
		name: 'PRIMARY'
	}
	mut rule_prior := &EarleyRule{
		name: 'PRIOR'
	}
	mut rule_private := &EarleyRule{
		name: 'PRIVATE'
	}
	mut rule_private_parameters := &EarleyRule{
		name: 'PRIVATE_PARAMETERS'
	}
	mut rule_private_params_s := &EarleyRule{
		name: 'PRIVATE_PARAMS_S'
	}
	mut rule_privileges := &EarleyRule{
		name: 'PRIVILEGES'
	}
	mut rule_prune := &EarleyRule{
		name: 'PRUNE'
	}
	mut rule_public := &EarleyRule{
		name: 'PUBLIC'
	}
	mut rule_quotes := &EarleyRule{
		name: 'QUOTES'
	}
	mut rule_read := &EarleyRule{
		name: 'READ'
	}
	mut rule_real := &EarleyRule{
		name: 'REAL'
	}
	mut rule_relative := &EarleyRule{
		name: 'RELATIVE'
	}
	mut rule_repeatable := &EarleyRule{
		name: 'REPEATABLE'
	}
	mut rule_respect := &EarleyRule{
		name: 'RESPECT'
	}
	mut rule_restart := &EarleyRule{
		name: 'RESTART'
	}
	mut rule_restrict := &EarleyRule{
		name: 'RESTRICT'
	}
	mut rule_ret_only_pass_thru := &EarleyRule{
		name: 'RET_ONLY_PASS_THRU'
	}
	mut rule_returned_cardinality := &EarleyRule{
		name: 'RETURNED_CARDINALITY'
	}
	mut rule_returned_length := &EarleyRule{
		name: 'RETURNED_LENGTH'
	}
	mut rule_returned_octet_length := &EarleyRule{
		name: 'RETURNED_OCTET_LENGTH'
	}
	mut rule_returned_sqlstate := &EarleyRule{
		name: 'RETURNED_SQLSTATE'
	}
	mut rule_returning := &EarleyRule{
		name: 'RETURNING'
	}
	mut rule_returns_only_pass_through := &EarleyRule{
		name: 'RETURNS_ONLY_PASS_THROUGH'
	}
	mut rule_right := &EarleyRule{
		name: 'RIGHT'
	}
	mut rule_role := &EarleyRule{
		name: 'ROLE'
	}
	mut rule_rollback := &EarleyRule{
		name: 'ROLLBACK'
	}
	mut rule_routine := &EarleyRule{
		name: 'ROUTINE'
	}
	mut rule_routine_catalog := &EarleyRule{
		name: 'ROUTINE_CATALOG'
	}
	mut rule_routine_name := &EarleyRule{
		name: 'ROUTINE_NAME'
	}
	mut rule_routine_schema := &EarleyRule{
		name: 'ROUTINE_SCHEMA'
	}
	mut rule_row := &EarleyRule{
		name: 'ROW'
	}
	mut rule_row_count := &EarleyRule{
		name: 'ROW_COUNT'
	}
	mut rule_rows := &EarleyRule{
		name: 'ROWS'
	}
	mut rule_scalar := &EarleyRule{
		name: 'SCALAR'
	}
	mut rule_scale := &EarleyRule{
		name: 'SCALE'
	}
	mut rule_schema := &EarleyRule{
		name: 'SCHEMA'
	}
	mut rule_schema_name := &EarleyRule{
		name: 'SCHEMA_NAME'
	}
	mut rule_scope_catalog := &EarleyRule{
		name: 'SCOPE_CATALOG'
	}
	mut rule_scope_name := &EarleyRule{
		name: 'SCOPE_NAME'
	}
	mut rule_scope_schema := &EarleyRule{
		name: 'SCOPE_SCHEMA'
	}
	mut rule_section := &EarleyRule{
		name: 'SECTION'
	}
	mut rule_security := &EarleyRule{
		name: 'SECURITY'
	}
	mut rule_select := &EarleyRule{
		name: 'SELECT'
	}
	mut rule_self := &EarleyRule{
		name: 'SELF'
	}
	mut rule_sequence := &EarleyRule{
		name: 'SEQUENCE'
	}
	mut rule_serializable := &EarleyRule{
		name: 'SERIALIZABLE'
	}
	mut rule_server_name := &EarleyRule{
		name: 'SERVER_NAME'
	}
	mut rule_session := &EarleyRule{
		name: 'SESSION'
	}
	mut rule_set := &EarleyRule{
		name: 'SET'
	}
	mut rule_sets := &EarleyRule{
		name: 'SETS'
	}
	mut rule_similar := &EarleyRule{
		name: 'SIMILAR'
	}
	mut rule_simple := &EarleyRule{
		name: 'SIMPLE'
	}
	mut rule_sin := &EarleyRule{
		name: 'SIN'
	}
	mut rule_sinh := &EarleyRule{
		name: 'SINH'
	}
	mut rule_size := &EarleyRule{
		name: 'SIZE'
	}
	mut rule_smallint := &EarleyRule{
		name: 'SMALLINT'
	}
	mut rule_source := &EarleyRule{
		name: 'SOURCE'
	}
	mut rule_space := &EarleyRule{
		name: 'SPACE'
	}
	mut rule_specific_name := &EarleyRule{
		name: 'SPECIFIC_NAME'
	}
	mut rule_sqrt := &EarleyRule{
		name: 'SQRT'
	}
	mut rule_start := &EarleyRule{
		name: 'START'
	}
	mut rule_start_catalog := &EarleyRule{
		name: 'START_CATALOG'
	}
	mut rule_start_name := &EarleyRule{
		name: 'START_NAME'
	}
	mut rule_start_procedure_specific_catalog := &EarleyRule{
		name: 'START_PROCEDURE_SPECIFIC_CATALOG'
	}
	mut rule_start_procedure_specific_name := &EarleyRule{
		name: 'START_PROCEDURE_SPECIFIC_NAME'
	}
	mut rule_start_procedure_specific_schema := &EarleyRule{
		name: 'START_PROCEDURE_SPECIFIC_SCHEMA'
	}
	mut rule_start_schema := &EarleyRule{
		name: 'START_SCHEMA'
	}
	mut rule_state := &EarleyRule{
		name: 'STATE'
	}
	mut rule_statement := &EarleyRule{
		name: 'STATEMENT'
	}
	mut rule_string := &EarleyRule{
		name: 'STRING'
	}
	mut rule_structure := &EarleyRule{
		name: 'STRUCTURE'
	}
	mut rule_style := &EarleyRule{
		name: 'STYLE'
	}
	mut rule_subclass_origin := &EarleyRule{
		name: 'SUBCLASS_ORIGIN'
	}
	mut rule_substring := &EarleyRule{
		name: 'SUBSTRING'
	}
	mut rule_sum := &EarleyRule{
		name: 'SUM'
	}
	mut rule_symmetric := &EarleyRule{
		name: 'SYMMETRIC'
	}
	mut rule_t := &EarleyRule{
		name: 'T'
	}
	mut rule_table := &EarleyRule{
		name: 'TABLE'
	}
	mut rule_table_name := &EarleyRule{
		name: 'TABLE_NAME'
	}
	mut rule_table_semantics := &EarleyRule{
		name: 'TABLE_SEMANTICS'
	}
	mut rule_tan := &EarleyRule{
		name: 'TAN'
	}
	mut rule_tanh := &EarleyRule{
		name: 'TANH'
	}
	mut rule_temporary := &EarleyRule{
		name: 'TEMPORARY'
	}
	mut rule_through := &EarleyRule{
		name: 'THROUGH'
	}
	mut rule_ties := &EarleyRule{
		name: 'TIES'
	}
	mut rule_time := &EarleyRule{
		name: 'TIME'
	}
	mut rule_timestamp := &EarleyRule{
		name: 'TIMESTAMP'
	}
	mut rule_to := &EarleyRule{
		name: 'TO'
	}
	mut rule_top_level_count := &EarleyRule{
		name: 'TOP_LEVEL_COUNT'
	}
	mut rule_trailing := &EarleyRule{
		name: 'TRAILING'
	}
	mut rule_transaction := &EarleyRule{
		name: 'TRANSACTION'
	}
	mut rule_transaction_active := &EarleyRule{
		name: 'TRANSACTION_ACTIVE'
	}
	mut rule_transactions_committed := &EarleyRule{
		name: 'TRANSACTIONS_COMMITTED'
	}
	mut rule_transactions_rolled_back := &EarleyRule{
		name: 'TRANSACTIONS_ROLLED_BACK'
	}
	mut rule_transform := &EarleyRule{
		name: 'TRANSFORM'
	}
	mut rule_transforms := &EarleyRule{
		name: 'TRANSFORMS'
	}
	mut rule_trigger_catalog := &EarleyRule{
		name: 'TRIGGER_CATALOG'
	}
	mut rule_trigger_name := &EarleyRule{
		name: 'TRIGGER_NAME'
	}
	mut rule_trigger_schema := &EarleyRule{
		name: 'TRIGGER_SCHEMA'
	}
	mut rule_trim := &EarleyRule{
		name: 'TRIM'
	}
	mut rule_true := &EarleyRule{
		name: 'TRUE'
	}
	mut rule_type := &EarleyRule{
		name: 'TYPE'
	}
	mut rule_unbounded := &EarleyRule{
		name: 'UNBOUNDED'
	}
	mut rule_uncommitted := &EarleyRule{
		name: 'UNCOMMITTED'
	}
	mut rule_unconditional := &EarleyRule{
		name: 'UNCONDITIONAL'
	}
	mut rule_under := &EarleyRule{
		name: 'UNDER'
	}
	mut rule_unknown := &EarleyRule{
		name: 'UNKNOWN'
	}
	mut rule_unnamed := &EarleyRule{
		name: 'UNNAMED'
	}
	mut rule_update := &EarleyRule{
		name: 'UPDATE'
	}
	mut rule_upper := &EarleyRule{
		name: 'UPPER'
	}
	mut rule_usage := &EarleyRule{
		name: 'USAGE'
	}
	mut rule_user_defined_type_catalog := &EarleyRule{
		name: 'USER_DEFINED_TYPE_CATALOG'
	}
	mut rule_user_defined_type_code := &EarleyRule{
		name: 'USER_DEFINED_TYPE_CODE'
	}
	mut rule_user_defined_type_name := &EarleyRule{
		name: 'USER_DEFINED_TYPE_NAME'
	}
	mut rule_user_defined_type_schema := &EarleyRule{
		name: 'USER_DEFINED_TYPE_SCHEMA'
	}
	mut rule_using := &EarleyRule{
		name: 'USING'
	}
	mut rule_utf16 := &EarleyRule{
		name: 'UTF16'
	}
	mut rule_utf32 := &EarleyRule{
		name: 'UTF32'
	}
	mut rule_utf8 := &EarleyRule{
		name: 'UTF8'
	}
	mut rule_value := &EarleyRule{
		name: 'VALUE'
	}
	mut rule_values := &EarleyRule{
		name: 'VALUES'
	}
	mut rule_varchar := &EarleyRule{
		name: 'VARCHAR'
	}
	mut rule_varying := &EarleyRule{
		name: 'VARYING'
	}
	mut rule_view := &EarleyRule{
		name: 'VIEW'
	}
	mut rule_where := &EarleyRule{
		name: 'WHERE'
	}
	mut rule_with := &EarleyRule{
		name: 'WITH'
	}
	mut rule_without := &EarleyRule{
		name: 'WITHOUT'
	}
	mut rule_work := &EarleyRule{
		name: 'WORK'
	}
	mut rule_wrapper := &EarleyRule{
		name: 'WRAPPER'
	}
	mut rule_write := &EarleyRule{
		name: 'WRITE'
	}
	mut rule_zone := &EarleyRule{
		name: 'ZONE'
	}

	rule_absolute_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_abs
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_absolute_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_absolute_value_expression__1_
		},
	]}

	rule_actual_identifier_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_regular_identifier_
		},
	]}

	rule_aggregate_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_count
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_asterisk_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_aggregate_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_aggregate_function__1_
		},
	]}
	rule_aggregate_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_set_function_
		},
	]}

	rule_alter_sequence_generator_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_restart_option_
		},
	]}

	rule_alter_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_option__1_
		},
	]}
	rule_alter_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_basic_sequence_generator_option_
		},
	]}

	rule_alter_sequence_generator_options__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_option_
		},
	]}

	rule_alter_sequence_generator_options__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_options_
		},
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_option_
		},
	]}

	rule_alter_sequence_generator_options_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_options__1_
		},
	]}
	rule_alter_sequence_generator_options_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_options__2_
		},
	]}

	rule_alter_sequence_generator_restart_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_restart
		},
	]}

	rule_alter_sequence_generator_restart_option__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_restart
		},
		&EarleyRuleOrString{
			rule: rule_with
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_restart_value_
		},
	]}

	rule_alter_sequence_generator_restart_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_restart_option__1_
		},
	]}
	rule_alter_sequence_generator_restart_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_restart_option__2_
		},
	]}

	rule_alter_sequence_generator_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter
		},
		&EarleyRuleOrString{
			rule: rule_sequence
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_name_
		},
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_options_
		},
	]}

	rule_alter_sequence_generator_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_statement__1_
		},
	]}

	rule_approximate_numeric_type__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_float
		},
	]}

	rule_approximate_numeric_type__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_float
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_approximate_numeric_type__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_real
		},
	]}

	rule_approximate_numeric_type__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_double
		},
		&EarleyRuleOrString{
			rule: rule_precision
		},
	]}

	rule_approximate_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_approximate_numeric_type__1_
		},
	]}
	rule_approximate_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_approximate_numeric_type__2_
		},
	]}
	rule_approximate_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_approximate_numeric_type__3_
		},
	]}
	rule_approximate_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_approximate_numeric_type__4_
		},
	]}

	rule_as_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_as
		},
		&EarleyRuleOrString{
			rule: rule_column_name_
		},
	]}

	rule_as_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_as_clause__1_
		},
	]}
	rule_as_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_
		},
	]}

	rule_asterisk_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '*'
			rule: 0
		},
	]}

	rule_asterisked_identifier_chain_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_asterisked_identifier_
		},
	]}

	rule_asterisked_identifier_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_basic_identifier_chain_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_chain_
		},
	]}

	rule_basic_sequence_generator_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_increment_by_option_
		},
	]}

	rule_basic_sequence_generator_option__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_maxvalue_option_
		},
	]}

	rule_basic_sequence_generator_option__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_minvalue_option_
		},
	]}

	rule_basic_sequence_generator_option__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_cycle_option_
		},
	]}

	rule_basic_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_basic_sequence_generator_option__1_
		},
	]}
	rule_basic_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_basic_sequence_generator_option__2_
		},
	]}
	rule_basic_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_basic_sequence_generator_option__3_
		},
	]}
	rule_basic_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_basic_sequence_generator_option__4_
		},
	]}

	rule_between_predicate_part_1__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between
		},
	]}

	rule_between_predicate_part_1__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_not
		},
		&EarleyRuleOrString{
			rule: rule_between
		},
	]}

	rule_between_predicate_part_1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate_part_1__1_
		},
	]}
	rule_between_predicate_part_1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate_part_1__2_
		},
	]}

	rule_between_predicate_part_2__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate_part_1_
		},
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
		&EarleyRuleOrString{
			rule: rule_and
		},
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
	]}

	rule_between_predicate_part_2__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate_part_1_
		},
		&EarleyRuleOrString{
			rule: rule_is_symmetric_
		},
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
		&EarleyRuleOrString{
			rule: rule_and
		},
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
	]}

	rule_between_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate_part_2__1_
		},
	]}
	rule_between_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate_part_2__2_
		},
	]}

	rule_between_predicate__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
		&EarleyRuleOrString{
			rule: rule_between_predicate_part_2_
		},
	]}

	rule_between_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate__1_
		},
	]}

	rule_boolean_factor__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_not
		},
		&EarleyRuleOrString{
			rule: rule_boolean_test_
		},
	]}

	rule_boolean_factor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_test_
		},
	]}
	rule_boolean_factor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_factor__2_
		},
	]}

	rule_boolean_literal__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_true
		},
	]}

	rule_boolean_literal__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_false
		},
	]}

	rule_boolean_literal__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unknown
		},
	]}

	rule_boolean_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_literal__1_
		},
	]}
	rule_boolean_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_literal__2_
		},
	]}
	rule_boolean_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_literal__3_
		},
	]}

	rule_boolean_predicand__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parenthesized_boolean_value_expression_
		},
	]}

	rule_boolean_predicand__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary_
		},
	]}

	rule_boolean_predicand_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_predicand__1_
		},
	]}
	rule_boolean_predicand_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_predicand__2_
		},
	]}

	rule_boolean_primary__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_predicate_
		},
	]}

	rule_boolean_primary__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_predicand_
		},
	]}

	rule_boolean_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_primary__1_
		},
	]}
	rule_boolean_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_primary__2_
		},
	]}

	rule_boolean_term__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_factor_
		},
	]}

	rule_boolean_term__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_term_
		},
		&EarleyRuleOrString{
			rule: rule_and
		},
		&EarleyRuleOrString{
			rule: rule_boolean_factor_
		},
	]}

	rule_boolean_term_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_term__1_
		},
	]}
	rule_boolean_term_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_term__2_
		},
	]}

	rule_boolean_test__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_primary_
		},
	]}

	rule_boolean_test__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_primary_
		},
		&EarleyRuleOrString{
			rule: rule_is
		},
		&EarleyRuleOrString{
			rule: rule_truth_value_
		},
	]}

	rule_boolean_test__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_primary_
		},
		&EarleyRuleOrString{
			rule: rule_is
		},
		&EarleyRuleOrString{
			rule: rule_not
		},
		&EarleyRuleOrString{
			rule: rule_truth_value_
		},
	]}

	rule_boolean_test_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_test__1_
		},
	]}
	rule_boolean_test_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_test__2_
		},
	]}
	rule_boolean_test_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_test__3_
		},
	]}

	rule_boolean_type__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean
		},
	]}

	rule_boolean_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_type__1_
		},
	]}

	rule_boolean_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_term_
		},
	]}

	rule_boolean_value_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_or
		},
		&EarleyRuleOrString{
			rule: rule_boolean_term_
		},
	]}

	rule_boolean_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression__1_
		},
	]}
	rule_boolean_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression__2_
		},
	]}

	rule_case_abbreviation__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nullif
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_case_abbreviation__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_coalesce
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_value_expression_list_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_case_abbreviation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_case_abbreviation__1_
		},
	]}
	rule_case_abbreviation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_case_abbreviation__2_
		},
	]}

	rule_case_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_case_abbreviation_
		},
	]}

	rule_cast_operand__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_cast_operand__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_implicitly_typed_value_specification_
		},
	]}

	rule_cast_operand_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cast_operand__1_
		},
	]}
	rule_cast_operand_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cast_operand__2_
		},
	]}

	rule_cast_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cast
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_cast_operand_
		},
		&EarleyRuleOrString{
			rule: rule_as
		},
		&EarleyRuleOrString{
			rule: rule_cast_target_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_cast_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cast_specification__1_
		},
	]}

	rule_cast_target_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_data_type_
		},
	]}

	rule_catalog_name_characteristic__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_catalog
		},
		&EarleyRuleOrString{
			rule: rule_value_specification_
		},
	]}

	rule_catalog_name_characteristic_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_catalog_name_characteristic__1_
		},
	]}

	rule_catalog_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_ceiling_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ceil
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_ceiling_function__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ceiling
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_ceiling_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ceiling_function__1_
		},
	]}
	rule_ceiling_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ceiling_function__2_
		},
	]}

	rule_char_length_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_char_length
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_char_length_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_length
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_char_length_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_char_length_expression__1_
		},
	]}
	rule_char_length_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_char_length_expression__2_
		},
	]}

	rule_char_length_units_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_characters
		},
	]}
	rule_char_length_units_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_octets
		},
	]}

	rule_character_factor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_primary_
		},
	]}

	rule_character_length_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_length_
		},
	]}

	rule_character_like_predicate_part_2__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_like
		},
		&EarleyRuleOrString{
			rule: rule_character_pattern_
		},
	]}

	rule_character_like_predicate_part_2__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_not
		},
		&EarleyRuleOrString{
			rule: rule_like
		},
		&EarleyRuleOrString{
			rule: rule_character_pattern_
		},
	]}

	rule_character_like_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_like_predicate_part_2__1_
		},
	]}
	rule_character_like_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_like_predicate_part_2__2_
		},
	]}

	rule_character_like_predicate__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
		&EarleyRuleOrString{
			rule: rule_character_like_predicate_part_2_
		},
	]}

	rule_character_like_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_like_predicate__1_
		},
	]}

	rule_character_pattern_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
	]}

	rule_character_position_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_position
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_1_
		},
		&EarleyRuleOrString{
			rule: rule_in
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_2_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_position_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_position_expression__1_
		},
	]}

	rule_character_primary__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_primary_
		},
	]}

	rule_character_primary__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_string_value_function_
		},
	]}

	rule_character_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_primary__1_
		},
	]}
	rule_character_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_primary__2_
		},
	]}

	rule_character_string_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule__string
		},
	]}

	rule_character_string_type__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character
		},
	]}

	rule_character_string_type__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_length_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_string_type__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_char
		},
	]}

	rule_character_string_type__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_char
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_length_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_string_type__5_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character
		},
		&EarleyRuleOrString{
			rule: rule_varying
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_length_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_string_type__6_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_char
		},
		&EarleyRuleOrString{
			rule: rule_varying
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_length_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_string_type__7_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_varchar
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_length_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_string_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type__1_
		},
	]}
	rule_character_string_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type__2_
		},
	]}
	rule_character_string_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type__3_
		},
	]}
	rule_character_string_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type__4_
		},
	]}
	rule_character_string_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type__5_
		},
	]}
	rule_character_string_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type__6_
		},
	]}
	rule_character_string_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type__7_
		},
	]}

	rule_character_substring_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_substring
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_start_position_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_substring_function__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_substring
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_start_position_
		},
		&EarleyRuleOrString{
			rule: rule_for
		},
		&EarleyRuleOrString{
			rule: rule_string_length_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_substring_function__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_substring
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_start_position_
		},
		&EarleyRuleOrString{
			rule: rule_using
		},
		&EarleyRuleOrString{
			rule: rule_char_length_units_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_substring_function__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_substring
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_start_position_
		},
		&EarleyRuleOrString{
			rule: rule_for
		},
		&EarleyRuleOrString{
			rule: rule_string_length_
		},
		&EarleyRuleOrString{
			rule: rule_using
		},
		&EarleyRuleOrString{
			rule: rule_char_length_units_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_character_substring_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_substring_function__1_
		},
	]}
	rule_character_substring_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_substring_function__2_
		},
	]}
	rule_character_substring_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_substring_function__3_
		},
	]}
	rule_character_substring_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_substring_function__4_
		},
	]}

	rule_character_value_expression_1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
	]}

	rule_character_value_expression_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
	]}

	rule_character_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_concatenation_
		},
	]}

	rule_character_value_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_factor_
		},
	]}

	rule_character_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression__1_
		},
	]}
	rule_character_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression__2_
		},
	]}

	rule_character_value_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_substring_function_
		},
	]}

	rule_character_value_function__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fold_
		},
	]}

	rule_character_value_function__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_function_
		},
	]}

	rule_character_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_function__1_
		},
	]}
	rule_character_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_function__2_
		},
	]}
	rule_character_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_function__3_
		},
	]}

	rule_colon_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: ':'
			rule: 0
		},
	]}

	rule_column_constraint_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_constraint_
		},
	]}

	rule_column_constraint__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_not
		},
		&EarleyRuleOrString{
			rule: rule_null
		},
	]}

	rule_column_constraint_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_constraint__1_
		},
	]}

	rule_column_definition__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_
		},
		&EarleyRuleOrString{
			rule: rule_data_type_or_domain_name_
		},
	]}

	rule_column_definition__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_
		},
		&EarleyRuleOrString{
			rule: rule_data_type_or_domain_name_
		},
		&EarleyRuleOrString{
			rule: rule_column_constraint_definition_
		},
	]}

	rule_column_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_definition__1_
		},
	]}
	rule_column_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_definition__2_
		},
	]}

	rule_column_name_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_
		},
	]}

	rule_column_name_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_column_name_
		},
	]}

	rule_column_name_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_list__1_
		},
	]}
	rule_column_name_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_list__2_
		},
	]}

	rule_column_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_column_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name__1_
		},
	]}

	rule_column_reference__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_basic_identifier_chain_
		},
	]}

	rule_column_reference_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_reference__1_
		},
	]}

	rule_comma_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: ','
			rule: 0
		},
	]}

	rule_commit_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_commit
		},
	]}

	rule_commit_statement__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_commit
		},
		&EarleyRuleOrString{
			rule: rule_work
		},
	]}

	rule_commit_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_commit_statement__1_
		},
	]}
	rule_commit_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_commit_statement__2_
		},
	]}

	rule_common_logarithm__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_log10
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_common_logarithm_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_logarithm__1_
		},
	]}

	rule_common_sequence_generator_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_start_with_option_
		},
	]}

	rule_common_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_sequence_generator_option__1_
		},
	]}
	rule_common_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_basic_sequence_generator_option_
		},
	]}

	rule_common_sequence_generator_options__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_sequence_generator_option_
		},
	]}

	rule_common_sequence_generator_options__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_sequence_generator_options_
		},
		&EarleyRuleOrString{
			rule: rule_common_sequence_generator_option_
		},
	]}

	rule_common_sequence_generator_options_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_sequence_generator_options__1_
		},
	]}
	rule_common_sequence_generator_options_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_sequence_generator_options__2_
		},
	]}

	rule_common_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
	]}

	rule_common_value_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_string_value_expression_
		},
	]}

	rule_common_value_expression__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_value_expression_
		},
	]}

	rule_common_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_value_expression__1_
		},
	]}
	rule_common_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_value_expression__2_
		},
	]}
	rule_common_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_value_expression__3_
		},
	]}

	rule_comp_op_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_equals_operator_
		},
	]}
	rule_comp_op_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_not_equals_operator_
		},
	]}
	rule_comp_op_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_less_than_operator_
		},
	]}
	rule_comp_op_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_greater_than_operator_
		},
	]}
	rule_comp_op_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_less_than_or_equals_operator_
		},
	]}
	rule_comp_op_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_greater_than_or_equals_operator_
		},
	]}

	rule_comparison_predicate_part_2__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_comp_op_
		},
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
	]}

	rule_comparison_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_comparison_predicate_part_2__1_
		},
	]}

	rule_comparison_predicate__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
		&EarleyRuleOrString{
			rule: rule_comparison_predicate_part_2_
		},
	]}

	rule_comparison_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_comparison_predicate__1_
		},
	]}

	rule_computational_operation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_avg
		},
	]}
	rule_computational_operation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_max
		},
	]}
	rule_computational_operation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_min
		},
	]}
	rule_computational_operation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sum
		},
	]}
	rule_computational_operation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_count
		},
	]}

	rule_concatenation_operator_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '||'
			rule: 0
		},
	]}

	rule_concatenation__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_concatenation_operator_
		},
		&EarleyRuleOrString{
			rule: rule_character_factor_
		},
	]}

	rule_concatenation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_concatenation__1_
		},
	]}

	rule_contextually_typed_row_value_constructor_element_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element_
		},
	]}

	rule_contextually_typed_row_value_constructor_element_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element_
		},
	]}

	rule_contextually_typed_row_value_constructor_element_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element_list__1_
		},
	]}
	rule_contextually_typed_row_value_constructor_element_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element_list__2_
		},
	]}

	rule_contextually_typed_row_value_constructor_element__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_contextually_typed_row_value_constructor_element__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_value_specification_
		},
	]}

	rule_contextually_typed_row_value_constructor_element_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element__1_
		},
	]}
	rule_contextually_typed_row_value_constructor_element_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element__2_
		},
	]}

	rule_contextually_typed_row_value_constructor__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_value_expression_
		},
	]}

	rule_contextually_typed_row_value_constructor__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression_
		},
	]}

	rule_contextually_typed_row_value_constructor__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_value_specification_
		},
	]}

	rule_contextually_typed_row_value_constructor__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_contextually_typed_value_specification_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_contextually_typed_row_value_constructor__5_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_element_list_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_contextually_typed_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor__1_
		},
	]}
	rule_contextually_typed_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor__2_
		},
	]}
	rule_contextually_typed_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor__3_
		},
	]}
	rule_contextually_typed_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor__4_
		},
	]}
	rule_contextually_typed_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor__5_
		},
	]}

	rule_contextually_typed_row_value_expression_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_expression_
		},
	]}

	rule_contextually_typed_row_value_expression_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_expression_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_expression_
		},
	]}

	rule_contextually_typed_row_value_expression_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_expression_list__1_
		},
	]}
	rule_contextually_typed_row_value_expression_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_expression_list__2_
		},
	]}

	rule_contextually_typed_row_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_constructor_
		},
	]}

	rule_contextually_typed_table_value_constructor__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_values
		},
		&EarleyRuleOrString{
			rule: rule_contextually_typed_row_value_expression_list_
		},
	]}

	rule_contextually_typed_table_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_table_value_constructor__1_
		},
	]}

	rule_contextually_typed_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_implicitly_typed_value_specification_
		},
	]}

	rule_correlation_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_correlation_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_correlation_name__1_
		},
	]}

	rule_correlation_or_recognition__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_correlation_name_
		},
	]}

	rule_correlation_or_recognition__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_as
		},
		&EarleyRuleOrString{
			rule: rule_correlation_name_
		},
	]}

	rule_correlation_or_recognition__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_correlation_name_
		},
		&EarleyRuleOrString{
			rule: rule_parenthesized_derived_column_list_
		},
	]}

	rule_correlation_or_recognition__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_as
		},
		&EarleyRuleOrString{
			rule: rule_correlation_name_
		},
		&EarleyRuleOrString{
			rule: rule_parenthesized_derived_column_list_
		},
	]}

	rule_correlation_or_recognition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_correlation_or_recognition__1_
		},
	]}
	rule_correlation_or_recognition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_correlation_or_recognition__2_
		},
	]}
	rule_correlation_or_recognition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_correlation_or_recognition__3_
		},
	]}
	rule_correlation_or_recognition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_correlation_or_recognition__4_
		},
	]}

	rule_current_date_value_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_date
		},
	]}

	rule_current_date_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_date_value_function__1_
		},
	]}

	rule_current_local_time_value_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_localtime
		},
	]}

	rule_current_local_time_value_function__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_localtime
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_time_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_current_local_time_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_local_time_value_function__1_
		},
	]}
	rule_current_local_time_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_local_time_value_function__2_
		},
	]}

	rule_current_local_timestamp_value_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_localtimestamp
		},
	]}

	rule_current_local_timestamp_value_function__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_localtimestamp
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_timestamp_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_current_local_timestamp_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_local_timestamp_value_function__1_
		},
	]}
	rule_current_local_timestamp_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_local_timestamp_value_function__2_
		},
	]}

	rule_current_time_value_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_time
		},
	]}

	rule_current_time_value_function__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_time
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_time_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_current_time_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_time_value_function__1_
		},
	]}
	rule_current_time_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_time_value_function__2_
		},
	]}

	rule_current_timestamp_value_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_timestamp
		},
	]}

	rule_current_timestamp_value_function__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_timestamp
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_timestamp_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_current_timestamp_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_timestamp_value_function__1_
		},
	]}
	rule_current_timestamp_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_timestamp_value_function__2_
		},
	]}

	rule_cursor_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_
		},
	]}

	rule_cursor_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cursor_specification__1_
		},
	]}

	rule_data_type_or_domain_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_data_type_
		},
	]}

	rule_data_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_predefined_type_
		},
	]}

	rule_date_literal__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_date
		},
		&EarleyRuleOrString{
			rule: rule_date_string_
		},
	]}

	rule_date_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_date_literal__1_
		},
	]}

	rule_date_string_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule__string
		},
	]}

	rule_datetime_factor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_primary_
		},
	]}

	rule_datetime_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_date_literal_
		},
	]}
	rule_datetime_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time_literal_
		},
	]}
	rule_datetime_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_timestamp_literal_
		},
	]}

	rule_datetime_primary__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_primary_
		},
	]}

	rule_datetime_primary__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_value_function_
		},
	]}

	rule_datetime_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_primary__1_
		},
	]}
	rule_datetime_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_primary__2_
		},
	]}

	rule_datetime_term_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_factor_
		},
	]}

	rule_datetime_type__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_date
		},
	]}

	rule_datetime_type__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time
		},
	]}

	rule_datetime_type__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_time_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_datetime_type__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time
		},
		&EarleyRuleOrString{
			rule: rule_with_or_without_time_zone_
		},
	]}

	rule_datetime_type__5_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_time_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
		&EarleyRuleOrString{
			rule: rule_with_or_without_time_zone_
		},
	]}

	rule_datetime_type__6_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_timestamp
		},
	]}

	rule_datetime_type__7_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_timestamp
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_timestamp_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_datetime_type__8_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_timestamp
		},
		&EarleyRuleOrString{
			rule: rule_with_or_without_time_zone_
		},
	]}

	rule_datetime_type__9_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_timestamp
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_timestamp_precision_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
		&EarleyRuleOrString{
			rule: rule_with_or_without_time_zone_
		},
	]}

	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__1_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__2_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__3_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__4_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__5_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__6_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__7_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__8_
		},
	]}
	rule_datetime_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type__9_
		},
	]}

	rule_datetime_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_term_
		},
	]}

	rule_datetime_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_date_value_function_
		},
	]}
	rule_datetime_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_time_value_function_
		},
	]}
	rule_datetime_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_timestamp_value_function_
		},
	]}
	rule_datetime_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_local_time_value_function_
		},
	]}
	rule_datetime_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_local_timestamp_value_function_
		},
	]}

	rule_delete_statement_searched__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_delete
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_target_table_
		},
	]}

	rule_delete_statement_searched__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_delete
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_target_table_
		},
		&EarleyRuleOrString{
			rule: rule_where
		},
		&EarleyRuleOrString{
			rule: rule_search_condition_
		},
	]}

	rule_delete_statement_searched_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_delete_statement_searched__1_
		},
	]}
	rule_delete_statement_searched_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_delete_statement_searched__2_
		},
	]}

	rule_derived_column_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_list_
		},
	]}

	rule_derived_column__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_derived_column__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_as_clause_
		},
	]}

	rule_derived_column_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_derived_column__1_
		},
	]}
	rule_derived_column_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_derived_column__2_
		},
	]}

	rule_derived_table_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_subquery_
		},
	]}

	rule_drop_behavior_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cascade
		},
	]}
	rule_drop_behavior_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_restrict
		},
	]}

	rule_drop_schema_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop
		},
		&EarleyRuleOrString{
			rule: rule_schema
		},
		&EarleyRuleOrString{
			rule: rule_schema_name_
		},
		&EarleyRuleOrString{
			rule: rule_drop_behavior_
		},
	]}

	rule_drop_schema_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop_schema_statement__1_
		},
	]}

	rule_drop_sequence_generator_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop
		},
		&EarleyRuleOrString{
			rule: rule_sequence
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_name_
		},
	]}

	rule_drop_sequence_generator_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop_sequence_generator_statement__1_
		},
	]}

	rule_drop_table_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop
		},
		&EarleyRuleOrString{
			rule: rule_table
		},
		&EarleyRuleOrString{
			rule: rule_table_name_
		},
	]}

	rule_drop_table_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop_table_statement__1_
		},
	]}

	rule_dynamic_select_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cursor_specification_
		},
	]}

	rule_equals_operator_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '='
			rule: 0
		},
	]}

	rule_exact_numeric_literal__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
	]}

	rule_exact_numeric_literal__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
		&EarleyRuleOrString{
			rule: rule_period_
		},
	]}

	rule_exact_numeric_literal__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
		&EarleyRuleOrString{
			rule: rule_period_
		},
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
	]}

	rule_exact_numeric_literal__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_period_
		},
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
	]}

	rule_exact_numeric_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_literal__1_
		},
	]}
	rule_exact_numeric_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_literal__2_
		},
	]}
	rule_exact_numeric_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_literal__3_
		},
	]}
	rule_exact_numeric_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_literal__4_
		},
	]}

	rule_exact_numeric_type__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_smallint
		},
	]}

	rule_exact_numeric_type__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_integer
		},
	]}

	rule_exact_numeric_type__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_int
		},
	]}

	rule_exact_numeric_type__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_bigint
		},
	]}

	rule_exact_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_type__1_
		},
	]}
	rule_exact_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_type__2_
		},
	]}
	rule_exact_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_type__3_
		},
	]}
	rule_exact_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_type__4_
		},
	]}

	rule_explicit_row_value_constructor__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_element_list_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_explicit_row_value_constructor__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_subquery_
		},
	]}

	rule_explicit_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_explicit_row_value_constructor__1_
		},
	]}
	rule_explicit_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_explicit_row_value_constructor__2_
		},
	]}

	rule_exponential_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exp
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_exponential_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exponential_function__1_
		},
	]}

	rule_factor__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sign_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_primary_
		},
	]}

	rule_factor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_primary_
		},
	]}
	rule_factor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_factor__2_
		},
	]}

	rule_fetch_first_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fetch
		},
		&EarleyRuleOrString{
			rule: rule_first
		},
		&EarleyRuleOrString{
			rule: rule_fetch_first_quantity_
		},
		&EarleyRuleOrString{
			rule: rule_row_or_rows_
		},
		&EarleyRuleOrString{
			rule: rule_only
		},
	]}

	rule_fetch_first_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fetch_first_clause__1_
		},
	]}

	rule_fetch_first_quantity_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fetch_first_row_count_
		},
	]}

	rule_fetch_first_row_count_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_simple_value_specification_
		},
	]}

	rule_floor_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_floor
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_floor_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_floor_function__1_
		},
	]}

	rule_fold__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_upper
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_fold__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_lower
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_fold_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fold__1_
		},
	]}
	rule_fold_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fold__2_
		},
	]}

	rule_from_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_table_reference_list_
		},
	]}

	rule_from_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from_clause__1_
		},
	]}

	rule_from_constructor__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_insert_column_list_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
		&EarleyRuleOrString{
			rule: rule_contextually_typed_table_value_constructor_
		},
	]}

	rule_from_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from_constructor__1_
		},
	]}

	rule_general_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_literal_
		},
	]}
	rule_general_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_literal_
		},
	]}
	rule_general_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_literal_
		},
	]}

	rule_general_set_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_function_type_
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_general_set_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_set_function__1_
		},
	]}

	rule_general_value_specification__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_catalog
		},
	]}

	rule_general_value_specification__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_current_schema
		},
	]}

	rule_general_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_host_parameter_specification_
		},
	]}
	rule_general_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_value_specification__2_
		},
	]}
	rule_general_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_value_specification__3_
		},
	]}

	rule_greater_than_operator_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '>'
			rule: 0
		},
	]}

	rule_greater_than_or_equals_operator_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '>='
			rule: 0
		},
	]}

	rule_group_by_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_group
		},
		&EarleyRuleOrString{
			rule: rule_by
		},
		&EarleyRuleOrString{
			rule: rule_grouping_element_list_
		},
	]}

	rule_group_by_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_group_by_clause__1_
		},
	]}

	rule_grouping_column_reference_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_reference_
		},
	]}

	rule_grouping_element_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_grouping_element_
		},
	]}

	rule_grouping_element_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_grouping_element_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_grouping_element_
		},
	]}

	rule_grouping_element_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_grouping_element_list__1_
		},
	]}
	rule_grouping_element_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_grouping_element_list__2_
		},
	]}

	rule_grouping_element_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ordinary_grouping_set_
		},
	]}

	rule_host_parameter_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_colon_
		},
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_host_parameter_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_host_parameter_name__1_
		},
	]}

	rule_host_parameter_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_host_parameter_name_
		},
	]}

	rule_identifier_body_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_start_
		},
	]}

	rule_identifier_chain__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
		&EarleyRuleOrString{
			rule: rule_period_
		},
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_identifier_chain_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}
	rule_identifier_chain_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_chain__2_
		},
	]}

	rule_identifier_start_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule__identifier
		},
	]}

	rule_identifier_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_actual_identifier_
		},
	]}

	rule_implicitly_typed_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_null_specification_
		},
	]}

	rule_insert_column_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_list_
		},
	]}

	rule_insert_columns_and_source_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from_constructor_
		},
	]}

	rule_insert_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_insert
		},
		&EarleyRuleOrString{
			rule: rule_into
		},
		&EarleyRuleOrString{
			rule: rule_insertion_target_
		},
		&EarleyRuleOrString{
			rule: rule_insert_columns_and_source_
		},
	]}

	rule_insert_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_insert_statement__1_
		},
	]}

	rule_insertion_target_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_name_
		},
	]}

	rule_is_symmetric__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_symmetric
		},
	]}

	rule_is_symmetric__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_asymmetric
		},
	]}

	rule_is_symmetric_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_is_symmetric__1_
		},
	]}
	rule_is_symmetric_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_is_symmetric__2_
		},
	]}

	rule_join_condition__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_on
		},
		&EarleyRuleOrString{
			rule: rule_search_condition_
		},
	]}

	rule_join_condition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_join_condition__1_
		},
	]}

	rule_join_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_join_condition_
		},
	]}

	rule_join_type__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_outer_join_type_
		},
		&EarleyRuleOrString{
			rule: rule_outer
		},
	]}

	rule_join_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_inner
		},
	]}
	rule_join_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_outer_join_type_
		},
	]}
	rule_join_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_join_type__3_
		},
	]}

	rule_joined_table_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_join_
		},
	]}

	rule_left_paren_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '('
			rule: 0
		},
	]}

	rule_length_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_char_length_expression_
		},
	]}
	rule_length_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_octet_length_expression_
		},
	]}

	rule_length_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
	]}

	rule_less_than_operator_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '<'
			rule: 0
		},
	]}

	rule_less_than_or_equals_operator_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '<='
			rule: 0
		},
	]}

	rule_like_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_like_predicate_
		},
	]}

	rule_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_signed_numeric_literal_
		},
	]}
	rule_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_literal_
		},
	]}

	rule_local_or_schema_qualified_name__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_local_or_schema_qualifier_
		},
		&EarleyRuleOrString{
			rule: rule_period_
		},
		&EarleyRuleOrString{
			rule: rule_qualified_identifier_
		},
	]}

	rule_local_or_schema_qualified_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_identifier_
		},
	]}
	rule_local_or_schema_qualified_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_local_or_schema_qualified_name__2_
		},
	]}

	rule_local_or_schema_qualifier_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_name_
		},
	]}

	rule_minus_sign_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '-'
			rule: 0
		},
	]}

	rule_modulus_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_mod
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_dividend_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_divisor_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_modulus_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_modulus_expression__1_
		},
	]}

	rule_natural_logarithm__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ln
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_natural_logarithm_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_natural_logarithm__1_
		},
	]}

	rule_next_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_next
		},
		&EarleyRuleOrString{
			rule: rule_value
		},
		&EarleyRuleOrString{
			rule: rule_for
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_name_
		},
	]}

	rule_next_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_next_value_expression__1_
		},
	]}

	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_a
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_absolute
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_action
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ada
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_add
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_admin
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_after
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_always
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_asc
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_assertion
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_assignment
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_attribute
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_attributes
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_before
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_bernoulli
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_breadth
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_c
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cascade
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_catalog_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_chain
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_chaining
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_set_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_set_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_set_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_characteristics
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_characters
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_class_origin
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cobol
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_collation
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_collation_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_collation_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_collation_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_columns
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_command_function
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_command_function_code
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_committed
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_conditional
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_condition_number
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_connection
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_connection_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_constraint_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_constraint_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_constraint_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_constraints
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_constructor
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_continue
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cursor_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_data
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_interval_code
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_interval_precision
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_defaults
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_deferrable
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_deferred
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_defined
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_definer
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_degree
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_depth
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_derived
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_desc
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_describe_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_describe_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_describe_procedure_specific_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_describe_procedure_specific_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_describe_procedure_specific_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_describe_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_descriptor
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_diagnostics
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_dispatch
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_domain
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_dynamic_function
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_dynamic_function_code
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_encoding
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_enforced
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_error
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exclude
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_excluding
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_expression
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_final
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_finish
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_finish_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_finish_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_finish_procedure_specific_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_finish_procedure_specific_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_finish_procedure_specific_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_finish_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_first
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_flag
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_following
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_format
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fortran
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_found
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fulfill
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fulfill_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fulfill_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fulfill_procedure_specific_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fulfill_procedure_specific_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fulfill_procedure_specific_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_fulfill_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_g
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_generated
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_go
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_goto
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_granted
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_has_pass_through_columns
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_has_pass_thru_cols
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_hierarchy
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ignore
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_immediate
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_immediately
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_implementation
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_including
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_increment
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_initially
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_input
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_instance
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_instantiable
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_instead
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_invoker
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_isolation
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_is_prunable
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_json
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_k
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_keep
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_key
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_keys
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_key_member
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_key_type
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_last
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_length
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_level
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_locator
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_m
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_map
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_matched
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_maxvalue
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_message_length
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_message_octet_length
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_message_text
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_minvalue
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_more
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_mumps
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_names
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nested
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nesting
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_next
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nfc
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nfd
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nfkc
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nfkd
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_normalized
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nullable
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nulls
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_number
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_object
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_octets
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_option
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_options
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ordering
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ordinality
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_others
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_output
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_overflow
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_overriding
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_p
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_pad
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parameter_mode
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parameter_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parameter_ordinal_position
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parameter_specific_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parameter_specific_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parameter_specific_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_partial
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_pascal
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_pass
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_passing
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_past
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_path
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_placing
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_plan
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_pli
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_preceding
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_preserve
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_prior
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_private
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_private_parameters
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_private_params_s
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_privileges
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_prune
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_public
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_quotes
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_read
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_relative
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_repeatable
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_respect
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_restart
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_restrict
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_returned_cardinality
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_returned_length
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_returned_octet_length
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_returned_sqlstate
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_returning
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_returns_only_pass_through
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ret_only_pass_thru
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_role
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_count
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_scalar
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_scale
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_scope_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_scope_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_scope_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_section
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_security
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_self
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_serializable
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_server_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_session
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sets
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_simple
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_size
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_source
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_space
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_specific_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_procedure_specific_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_procedure_specific_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_procedure_specific_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_state
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_statement
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_string
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_structure
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_style
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_subclass_origin
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_t
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_semantics
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_temporary
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_through
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ties
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_top_level_count
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_transaction
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_transaction_active
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_transactions_committed
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_transactions_rolled_back
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_transform
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_transforms
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trigger_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trigger_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trigger_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_type
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unbounded
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_uncommitted
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unconditional
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_under
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unnamed
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_usage
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_user_defined_type_catalog
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_user_defined_type_code
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_user_defined_type_name
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_user_defined_type_schema
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_utf16
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_utf32
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_utf8
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_view
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_work
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_wrapper
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_write
		},
	]}
	rule_non_reserved_word_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_zone
		},
	]}

	rule_nonparenthesized_value_expression_primary__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_value_specification_
		},
	]}

	rule_nonparenthesized_value_expression_primary__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_reference_
		},
	]}

	rule_nonparenthesized_value_expression_primary__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_function_specification_
		},
	]}

	rule_nonparenthesized_value_expression_primary__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine_invocation_
		},
	]}

	rule_nonparenthesized_value_expression_primary__5_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_case_expression_
		},
	]}

	rule_nonparenthesized_value_expression_primary__6_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cast_specification_
		},
	]}

	rule_nonparenthesized_value_expression_primary__7_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_next_value_expression_
		},
	]}

	rule_nonparenthesized_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary__1_
		},
	]}
	rule_nonparenthesized_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary__2_
		},
	]}
	rule_nonparenthesized_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary__3_
		},
	]}
	rule_nonparenthesized_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary__4_
		},
	]}
	rule_nonparenthesized_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary__5_
		},
	]}
	rule_nonparenthesized_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary__6_
		},
	]}
	rule_nonparenthesized_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary__7_
		},
	]}

	rule_not_equals_operator_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '<>'
			rule: 0
		},
	]}

	rule_null_predicate_part_2__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_is
		},
		&EarleyRuleOrString{
			rule: rule_null
		},
	]}

	rule_null_predicate_part_2__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_is
		},
		&EarleyRuleOrString{
			rule: rule_not
		},
		&EarleyRuleOrString{
			rule: rule_null
		},
	]}

	rule_null_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_null_predicate_part_2__1_
		},
	]}
	rule_null_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_null_predicate_part_2__2_
		},
	]}

	rule_null_predicate__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
		&EarleyRuleOrString{
			rule: rule_null_predicate_part_2_
		},
	]}

	rule_null_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_null_predicate__1_
		},
	]}

	rule_null_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_null
		},
	]}

	rule_null_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_null_specification__1_
		},
	]}

	rule_numeric_primary__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_primary_
		},
	]}

	rule_numeric_primary__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_function_
		},
	]}

	rule_numeric_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_primary__1_
		},
	]}
	rule_numeric_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_primary__2_
		},
	]}

	rule_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_type_
		},
	]}
	rule_numeric_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_approximate_numeric_type_
		},
	]}

	rule_numeric_value_expression_base_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
	]}

	rule_numeric_value_expression_dividend_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
	]}

	rule_numeric_value_expression_divisor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
	]}

	rule_numeric_value_expression_exponent_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
	]}

	rule_numeric_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_term_
		},
	]}

	rule_numeric_value_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_plus_sign_
		},
		&EarleyRuleOrString{
			rule: rule_term_
		},
	]}

	rule_numeric_value_expression__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_minus_sign_
		},
		&EarleyRuleOrString{
			rule: rule_term_
		},
	]}

	rule_numeric_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression__1_
		},
	]}
	rule_numeric_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression__2_
		},
	]}
	rule_numeric_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression__3_
		},
	]}

	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_position_expression_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_length_expression_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_absolute_value_expression_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_modulus_expression_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trigonometric_function_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_logarithm_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_natural_logarithm_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exponential_function_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_power_function_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_square_root_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_floor_function_
		},
	]}
	rule_numeric_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ceiling_function_
		},
	]}

	rule_object_column_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_
		},
	]}

	rule_octet_length_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_octet_length
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_string_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_octet_length_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_octet_length_expression__1_
		},
	]}

	rule_offset_row_count_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_simple_value_specification_
		},
	]}

	rule_order_by_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_order
		},
		&EarleyRuleOrString{
			rule: rule_by
		},
		&EarleyRuleOrString{
			rule: rule_sort_specification_list_
		},
	]}

	rule_order_by_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_order_by_clause__1_
		},
	]}

	rule_ordering_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_asc
		},
	]}

	rule_ordering_specification__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_desc
		},
	]}

	rule_ordering_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ordering_specification__1_
		},
	]}
	rule_ordering_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_ordering_specification__2_
		},
	]}

	rule_ordinary_grouping_set_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_grouping_column_reference_
		},
	]}

	rule_outer_join_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left
		},
	]}
	rule_outer_join_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_right
		},
	]}

	rule_parenthesized_boolean_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_parenthesized_boolean_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parenthesized_boolean_value_expression__1_
		},
	]}

	rule_parenthesized_derived_column_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_derived_column_list_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_parenthesized_derived_column_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parenthesized_derived_column_list__1_
		},
	]}

	rule_parenthesized_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_parenthesized_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parenthesized_value_expression__1_
		},
	]}

	rule_period_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '.'
			rule: 0
		},
	]}

	rule_plus_sign_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '+'
			rule: 0
		},
	]}

	rule_position_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_position_expression_
		},
	]}

	rule_power_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_power
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_base_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_exponent_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_power_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_power_function__1_
		},
	]}

	rule_precision_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
	]}

	rule_predefined_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_string_type_
		},
	]}
	rule_predefined_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_type_
		},
	]}
	rule_predefined_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_type_
		},
	]}
	rule_predefined_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_datetime_type_
		},
	]}

	rule_predicate__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_comparison_predicate_
		},
	]}

	rule_predicate__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_between_predicate_
		},
	]}

	rule_predicate__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_like_predicate_
		},
	]}

	rule_predicate__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_similar_predicate_
		},
	]}

	rule_predicate__5_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_null_predicate_
		},
	]}

	rule_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_predicate__1_
		},
	]}
	rule_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_predicate__2_
		},
	]}
	rule_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_predicate__3_
		},
	]}
	rule_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_predicate__4_
		},
	]}
	rule_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_predicate__5_
		},
	]}

	rule_preparable_sql_data_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_delete_statement_searched_
		},
	]}
	rule_preparable_sql_data_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_insert_statement_
		},
	]}
	rule_preparable_sql_data_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_dynamic_select_statement_
		},
	]}
	rule_preparable_sql_data_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update_statement_searched_
		},
	]}

	rule_preparable_sql_schema_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_schema_statement_
		},
	]}

	rule_preparable_sql_session_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_session_statement_
		},
	]}

	rule_preparable_sql_transaction_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_transaction_statement_
		},
	]}

	rule_preparable_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_preparable_sql_data_statement_
		},
	]}
	rule_preparable_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_preparable_sql_schema_statement_
		},
	]}
	rule_preparable_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_preparable_sql_transaction_statement_
		},
	]}
	rule_preparable_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_preparable_sql_session_statement_
		},
	]}

	rule_qualified_asterisk__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_asterisked_identifier_chain_
		},
		&EarleyRuleOrString{
			rule: rule_period_
		},
		&EarleyRuleOrString{
			rule: rule_asterisk_
		},
	]}

	rule_qualified_asterisk_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_asterisk__1_
		},
	]}

	rule_qualified_identifier_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_qualified_join__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_reference_
		},
		&EarleyRuleOrString{
			rule: rule_join
		},
		&EarleyRuleOrString{
			rule: rule_table_reference_
		},
		&EarleyRuleOrString{
			rule: rule_join_specification_
		},
	]}

	rule_qualified_join__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_reference_
		},
		&EarleyRuleOrString{
			rule: rule_join_type_
		},
		&EarleyRuleOrString{
			rule: rule_join
		},
		&EarleyRuleOrString{
			rule: rule_table_reference_
		},
		&EarleyRuleOrString{
			rule: rule_join_specification_
		},
	]}

	rule_qualified_join_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_join__1_
		},
	]}
	rule_qualified_join_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_join__2_
		},
	]}

	rule_query_expression_body_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_term_
		},
	]}

	rule_query_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
	]}

	rule_query_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
		&EarleyRuleOrString{
			rule: rule_order_by_clause_
		},
	]}

	rule_query_expression__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
		&EarleyRuleOrString{
			rule: rule_result_offset_clause_
		},
	]}

	rule_query_expression__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
		&EarleyRuleOrString{
			rule: rule_order_by_clause_
		},
		&EarleyRuleOrString{
			rule: rule_result_offset_clause_
		},
	]}

	rule_query_expression__5_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
		&EarleyRuleOrString{
			rule: rule_fetch_first_clause_
		},
	]}

	rule_query_expression__6_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
		&EarleyRuleOrString{
			rule: rule_order_by_clause_
		},
		&EarleyRuleOrString{
			rule: rule_fetch_first_clause_
		},
	]}

	rule_query_expression__7_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
		&EarleyRuleOrString{
			rule: rule_order_by_clause_
		},
		&EarleyRuleOrString{
			rule: rule_result_offset_clause_
		},
		&EarleyRuleOrString{
			rule: rule_fetch_first_clause_
		},
	]}

	rule_query_expression__8_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression_body_
		},
		&EarleyRuleOrString{
			rule: rule_result_offset_clause_
		},
		&EarleyRuleOrString{
			rule: rule_fetch_first_clause_
		},
	]}

	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__1_
		},
	]}
	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__2_
		},
	]}
	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__3_
		},
	]}
	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__4_
		},
	]}
	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__5_
		},
	]}
	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__6_
		},
	]}
	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__7_
		},
	]}
	rule_query_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_expression__8_
		},
	]}

	rule_query_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_simple_table_
		},
	]}

	rule_query_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_select
		},
		&EarleyRuleOrString{
			rule: rule_select_list_
		},
		&EarleyRuleOrString{
			rule: rule_table_expression_
		},
	]}

	rule_query_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_specification__1_
		},
	]}

	rule_query_term_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_primary_
		},
	]}

	rule_regular_identifier__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_non_reserved_word_
		},
	]}

	rule_regular_identifier_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_body_
		},
	]}
	rule_regular_identifier_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_regular_identifier__2_
		},
	]}

	rule_result_offset_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_offset
		},
		&EarleyRuleOrString{
			rule: rule_offset_row_count_
		},
		&EarleyRuleOrString{
			rule: rule_row_or_rows_
		},
	]}

	rule_result_offset_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_result_offset_clause__1_
		},
	]}

	rule_right_paren_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: ')'
			rule: 0
		},
	]}

	rule_rollback_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_rollback
		},
	]}

	rule_rollback_statement__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_rollback
		},
		&EarleyRuleOrString{
			rule: rule_work
		},
	]}

	rule_rollback_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_rollback_statement__1_
		},
	]}
	rule_rollback_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_rollback_statement__2_
		},
	]}

	rule_routine_invocation__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine_name_
		},
		&EarleyRuleOrString{
			rule: rule_sql_argument_list_
		},
	]}

	rule_routine_invocation_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine_invocation__1_
		},
	]}

	rule_routine_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_identifier_
		},
	]}

	rule_routine_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_routine_name__1_
		},
	]}

	rule_row_or_rows_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row
		},
	]}
	rule_row_or_rows_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_rows
		},
	]}

	rule_row_subquery_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_subquery_
		},
	]}

	rule_row_value_constructor_element_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_element_
		},
	]}

	rule_row_value_constructor_element_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_element_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_element_
		},
	]}

	rule_row_value_constructor_element_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_element_list__1_
		},
	]}
	rule_row_value_constructor_element_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_element_list__2_
		},
	]}

	rule_row_value_constructor_element_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_row_value_constructor_predicand__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_value_expression_
		},
	]}

	rule_row_value_constructor_predicand__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_predicand_
		},
	]}

	rule_row_value_constructor_predicand_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_predicand__1_
		},
	]}
	rule_row_value_constructor_predicand_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_predicand__2_
		},
	]}

	rule_row_value_constructor__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_value_expression_
		},
	]}

	rule_row_value_constructor__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression_
		},
	]}

	rule_row_value_constructor__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_explicit_row_value_constructor_
		},
	]}

	rule_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor__1_
		},
	]}
	rule_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor__2_
		},
	]}
	rule_row_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor__3_
		},
	]}

	rule_row_value_expression_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_row_value_expression_
		},
	]}

	rule_row_value_expression_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_expression_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_table_row_value_expression_
		},
	]}

	rule_row_value_expression_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_expression_list__1_
		},
	]}
	rule_row_value_expression_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_expression_list__2_
		},
	]}

	rule_row_value_predicand_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_predicand_
		},
	]}

	rule_schema_definition__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_create
		},
		&EarleyRuleOrString{
			rule: rule_schema
		},
		&EarleyRuleOrString{
			rule: rule_schema_name_clause_
		},
	]}

	rule_schema_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_definition__1_
		},
	]}

	rule_schema_name_characteristic__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema
		},
		&EarleyRuleOrString{
			rule: rule_value_specification_
		},
	]}

	rule_schema_name_characteristic_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_name_characteristic__1_
		},
	]}

	rule_schema_name_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_name_
		},
	]}

	rule_schema_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_catalog_name_
		},
		&EarleyRuleOrString{
			rule: rule_period_
		},
		&EarleyRuleOrString{
			rule: rule_unqualified_schema_name_
		},
	]}

	rule_schema_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_name__1_
		},
	]}
	rule_schema_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unqualified_schema_name_
		},
	]}

	rule_schema_qualified_name__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_name_
		},
		&EarleyRuleOrString{
			rule: rule_period_
		},
		&EarleyRuleOrString{
			rule: rule_qualified_identifier_
		},
	]}

	rule_schema_qualified_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_identifier_
		},
	]}
	rule_schema_qualified_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_qualified_name__2_
		},
	]}

	rule_search_condition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression_
		},
	]}

	rule_select_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_asterisk_
		},
	]}

	rule_select_list__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_select_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_select_sublist_
		},
	]}

	rule_select_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_select_list__1_
		},
	]}
	rule_select_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_select_sublist_
		},
	]}
	rule_select_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_select_list__3_
		},
	]}

	rule_select_sublist__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_derived_column_
		},
	]}

	rule_select_sublist__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_qualified_asterisk_
		},
	]}

	rule_select_sublist_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_select_sublist__1_
		},
	]}
	rule_select_sublist_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_select_sublist__2_
		},
	]}

	rule_sequence_generator_cycle_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cycle
		},
	]}

	rule_sequence_generator_cycle_option__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_no
		},
		&EarleyRuleOrString{
			rule: rule_cycle
		},
	]}

	rule_sequence_generator_cycle_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_cycle_option__1_
		},
	]}
	rule_sequence_generator_cycle_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_cycle_option__2_
		},
	]}

	rule_sequence_generator_definition__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_create
		},
		&EarleyRuleOrString{
			rule: rule_sequence
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_name_
		},
	]}

	rule_sequence_generator_definition__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_create
		},
		&EarleyRuleOrString{
			rule: rule_sequence
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_name_
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_options_
		},
	]}

	rule_sequence_generator_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_definition__1_
		},
	]}
	rule_sequence_generator_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_definition__2_
		},
	]}

	rule_sequence_generator_increment_by_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_increment
		},
		&EarleyRuleOrString{
			rule: rule_by
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_increment_
		},
	]}

	rule_sequence_generator_increment_by_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_increment_by_option__1_
		},
	]}

	rule_sequence_generator_increment_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_signed_numeric_literal_
		},
	]}

	rule_sequence_generator_max_value_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_signed_numeric_literal_
		},
	]}

	rule_sequence_generator_maxvalue_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_maxvalue
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_max_value_
		},
	]}

	rule_sequence_generator_maxvalue_option__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_no
		},
		&EarleyRuleOrString{
			rule: rule_maxvalue
		},
	]}

	rule_sequence_generator_maxvalue_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_maxvalue_option__1_
		},
	]}
	rule_sequence_generator_maxvalue_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_maxvalue_option__2_
		},
	]}

	rule_sequence_generator_min_value_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_signed_numeric_literal_
		},
	]}

	rule_sequence_generator_minvalue_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_minvalue
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_min_value_
		},
	]}

	rule_sequence_generator_minvalue_option__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_no
		},
		&EarleyRuleOrString{
			rule: rule_minvalue
		},
	]}

	rule_sequence_generator_minvalue_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_minvalue_option__1_
		},
	]}
	rule_sequence_generator_minvalue_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_minvalue_option__2_
		},
	]}

	rule_sequence_generator_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_qualified_name_
		},
	]}

	rule_sequence_generator_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_name__1_
		},
	]}

	rule_sequence_generator_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_sequence_generator_options_
		},
	]}

	rule_sequence_generator_options_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_option_
		},
	]}
	rule_sequence_generator_options_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_options_
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_option_
		},
	]}

	rule_sequence_generator_restart_value_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_signed_numeric_literal_
		},
	]}

	rule_sequence_generator_start_value_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_signed_numeric_literal_
		},
	]}

	rule_sequence_generator_start_with_option__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start
		},
		&EarleyRuleOrString{
			rule: rule_with
		},
		&EarleyRuleOrString{
			rule: rule_sequence_generator_start_value_
		},
	]}

	rule_sequence_generator_start_with_option_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_start_with_option__1_
		},
	]}

	rule_set_catalog_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set
		},
		&EarleyRuleOrString{
			rule: rule_catalog_name_characteristic_
		},
	]}

	rule_set_catalog_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_catalog_statement__1_
		},
	]}

	rule_set_clause_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_clause_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_set_clause_
		},
	]}

	rule_set_clause_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_clause_
		},
	]}
	rule_set_clause_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_clause_list__2_
		},
	]}

	rule_set_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_target_
		},
		&EarleyRuleOrString{
			rule: rule_equals_operator_
		},
		&EarleyRuleOrString{
			rule: rule_update_source_
		},
	]}

	rule_set_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_clause__1_
		},
	]}

	rule_set_function_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_aggregate_function_
		},
	]}

	rule_set_function_type_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_computational_operation_
		},
	]}

	rule_set_schema_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set
		},
		&EarleyRuleOrString{
			rule: rule_schema_name_characteristic_
		},
	]}

	rule_set_schema_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_schema_statement__1_
		},
	]}

	rule_set_target_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update_target_
		},
	]}

	rule_sign_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_plus_sign_
		},
	]}
	rule_sign_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_minus_sign_
		},
	]}

	rule_signed_numeric_literal__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sign_
		},
		&EarleyRuleOrString{
			rule: rule_unsigned_numeric_literal_
		},
	]}

	rule_signed_numeric_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_numeric_literal_
		},
	]}
	rule_signed_numeric_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_signed_numeric_literal__2_
		},
	]}

	rule_similar_pattern_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
	]}

	rule_similar_predicate_part_2__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_similar
		},
		&EarleyRuleOrString{
			rule: rule_to
		},
		&EarleyRuleOrString{
			rule: rule_similar_pattern_
		},
	]}

	rule_similar_predicate_part_2__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_not
		},
		&EarleyRuleOrString{
			rule: rule_similar
		},
		&EarleyRuleOrString{
			rule: rule_to
		},
		&EarleyRuleOrString{
			rule: rule_similar_pattern_
		},
	]}

	rule_similar_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_similar_predicate_part_2__1_
		},
	]}
	rule_similar_predicate_part_2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_similar_predicate_part_2__2_
		},
	]}

	rule_similar_predicate__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_predicand_
		},
		&EarleyRuleOrString{
			rule: rule_similar_predicate_part_2_
		},
	]}

	rule_similar_predicate_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_similar_predicate__1_
		},
	]}

	rule_simple_table_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_query_specification_
		},
	]}
	rule_simple_table_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_value_constructor_
		},
	]}

	rule_simple_value_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_literal_
		},
	]}

	rule_simple_value_specification__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_host_parameter_name_
		},
	]}

	rule_simple_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_simple_value_specification__1_
		},
	]}
	rule_simple_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_simple_value_specification__2_
		},
	]}

	rule_solidus_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '/'
			rule: 0
		},
	]}

	rule_sort_key_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_sort_specification_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_specification_
		},
	]}

	rule_sort_specification_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_specification_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_sort_specification_
		},
	]}

	rule_sort_specification_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_specification_list__1_
		},
	]}
	rule_sort_specification_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_specification_list__2_
		},
	]}

	rule_sort_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_key_
		},
	]}

	rule_sort_specification__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_key_
		},
		&EarleyRuleOrString{
			rule: rule_ordering_specification_
		},
	]}

	rule_sort_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_specification__1_
		},
	]}
	rule_sort_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sort_specification__2_
		},
	]}

	rule_sql_argument_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_sql_argument_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_sql_argument_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_sql_argument_list__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_sql_argument_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_sql_argument_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_sql_argument_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_argument_list__1_
		},
	]}
	rule_sql_argument_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_argument_list__2_
		},
	]}
	rule_sql_argument_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_argument_list__3_
		},
	]}

	rule_sql_argument_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_sql_schema_definition_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_schema_definition_
		},
	]}
	rule_sql_schema_definition_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_definition_
		},
	]}
	rule_sql_schema_definition_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sequence_generator_definition_
		},
	]}

	rule_sql_schema_manipulation_statement__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_alter_sequence_generator_statement_
		},
	]}

	rule_sql_schema_manipulation_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop_schema_statement_
		},
	]}
	rule_sql_schema_manipulation_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop_table_statement_
		},
	]}
	rule_sql_schema_manipulation_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_schema_manipulation_statement__3_
		},
	]}
	rule_sql_schema_manipulation_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_drop_sequence_generator_statement_
		},
	]}

	rule_sql_schema_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_schema_definition_statement_
		},
	]}
	rule_sql_schema_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sql_schema_manipulation_statement_
		},
	]}

	rule_sql_session_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_schema_statement_
		},
	]}
	rule_sql_session_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_set_catalog_statement_
		},
	]}

	rule_sql_transaction_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_transaction_statement_
		},
	]}
	rule_sql_transaction_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_commit_statement_
		},
	]}
	rule_sql_transaction_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_rollback_statement_
		},
	]}

	rule_square_root__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sqrt
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_square_root_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_square_root__1_
		},
	]}

	rule_start_position_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
	]}

	rule_start_transaction_statement__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start
		},
		&EarleyRuleOrString{
			rule: rule_transaction
		},
	]}

	rule_start_transaction_statement_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_start_transaction_statement__1_
		},
	]}

	rule_string_length_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
	]}

	rule_string_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
	]}

	rule_string_value_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_function_
		},
	]}

	rule_subquery__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_query_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_subquery_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_subquery__1_
		},
	]}

	rule_table_constraint_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_constraint_
		},
	]}

	rule_table_constraint_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unique_constraint_definition_
		},
	]}

	rule_table_contents_source_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_element_list_
		},
	]}

	rule_table_definition__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_create
		},
		&EarleyRuleOrString{
			rule: rule_table
		},
		&EarleyRuleOrString{
			rule: rule_table_name_
		},
		&EarleyRuleOrString{
			rule: rule_table_contents_source_
		},
	]}

	rule_table_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_definition__1_
		},
	]}

	rule_table_element_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_table_elements_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_table_element_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_element_list__1_
		},
	]}

	rule_table_element_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_definition_
		},
	]}
	rule_table_element_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_constraint_definition_
		},
	]}

	rule_table_elements__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_element_
		},
	]}

	rule_table_elements__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_elements_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_table_element_
		},
	]}

	rule_table_elements_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_elements__1_
		},
	]}
	rule_table_elements_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_elements__2_
		},
	]}

	rule_table_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from_clause_
		},
	]}

	rule_table_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from_clause_
		},
		&EarleyRuleOrString{
			rule: rule_where_clause_
		},
	]}

	rule_table_expression__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from_clause_
		},
		&EarleyRuleOrString{
			rule: rule_group_by_clause_
		},
	]}

	rule_table_expression__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from_clause_
		},
		&EarleyRuleOrString{
			rule: rule_where_clause_
		},
		&EarleyRuleOrString{
			rule: rule_group_by_clause_
		},
	]}

	rule_table_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_expression__1_
		},
	]}
	rule_table_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_expression__2_
		},
	]}
	rule_table_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_expression__3_
		},
	]}
	rule_table_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_expression__4_
		},
	]}

	rule_table_factor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_primary_
		},
	]}

	rule_table_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_local_or_schema_qualified_name_
		},
	]}

	rule_table_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_name__1_
		},
	]}

	rule_table_or_query_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_name_
		},
	]}

	rule_table_primary__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_or_query_name_
		},
	]}

	rule_table_primary__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_derived_table_
		},
		&EarleyRuleOrString{
			rule: rule_correlation_or_recognition_
		},
	]}

	rule_table_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_primary__1_
		},
	]}
	rule_table_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_derived_table_
		},
	]}
	rule_table_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_primary__3_
		},
	]}

	rule_table_reference_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_reference_
		},
	]}

	rule_table_reference__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_factor_
		},
	]}

	rule_table_reference__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_joined_table_
		},
	]}

	rule_table_reference_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_reference__1_
		},
	]}
	rule_table_reference_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_reference__2_
		},
	]}

	rule_table_row_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_row_value_constructor_
		},
	]}

	rule_table_subquery_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_subquery_
		},
	]}

	rule_table_value_constructor__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_values
		},
		&EarleyRuleOrString{
			rule: rule_row_value_expression_list_
		},
	]}

	rule_table_value_constructor_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_value_constructor__1_
		},
	]}

	rule_target_table_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_table_name_
		},
	]}

	rule_term__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_factor_
		},
	]}

	rule_term__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_term_
		},
		&EarleyRuleOrString{
			rule: rule_asterisk_
		},
		&EarleyRuleOrString{
			rule: rule_factor_
		},
	]}

	rule_term__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_term_
		},
		&EarleyRuleOrString{
			rule: rule_solidus_
		},
		&EarleyRuleOrString{
			rule: rule_factor_
		},
	]}

	rule_term_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_term__1_
		},
	]}
	rule_term_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_term__2_
		},
	]}
	rule_term_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_term__3_
		},
	]}

	rule_time_fractional_seconds_precision_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_integer_
		},
	]}

	rule_time_literal__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time
		},
		&EarleyRuleOrString{
			rule: rule_time_string_
		},
	]}

	rule_time_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time_literal__1_
		},
	]}

	rule_time_precision_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time_fractional_seconds_precision_
		},
	]}

	rule_time_string_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule__string
		},
	]}

	rule_timestamp_literal__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_timestamp
		},
		&EarleyRuleOrString{
			rule: rule_timestamp_string_
		},
	]}

	rule_timestamp_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_timestamp_literal__1_
		},
	]}

	rule_timestamp_precision_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_time_fractional_seconds_precision_
		},
	]}

	rule_timestamp_string_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule__string
		},
	]}

	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sin
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cos
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_tan
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_sinh
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_cosh
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_tanh
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_asin
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_acos
		},
	]}
	rule_trigonometric_function_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_atan
		},
	]}

	rule_trigonometric_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trigonometric_function_name_
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_numeric_value_expression_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_trigonometric_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trigonometric_function__1_
		},
	]}

	rule_trim_character_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
	]}

	rule_trim_function__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_trim_operands_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_trim_function_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_function__1_
		},
	]}

	rule_trim_operands__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_source_
		},
	]}

	rule_trim_operands__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_trim_source_
		},
	]}

	rule_trim_operands__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_specification_
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_trim_source_
		},
	]}

	rule_trim_operands__4_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_character_
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_trim_source_
		},
	]}

	rule_trim_operands__5_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_specification_
		},
		&EarleyRuleOrString{
			rule: rule_trim_character_
		},
		&EarleyRuleOrString{
			rule: rule_from
		},
		&EarleyRuleOrString{
			rule: rule_trim_source_
		},
	]}

	rule_trim_operands_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_operands__1_
		},
	]}
	rule_trim_operands_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_operands__2_
		},
	]}
	rule_trim_operands_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_operands__3_
		},
	]}
	rule_trim_operands_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_operands__4_
		},
	]}
	rule_trim_operands_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trim_operands__5_
		},
	]}

	rule_trim_source_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_character_value_expression_
		},
	]}

	rule_trim_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_leading
		},
	]}
	rule_trim_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_trailing
		},
	]}
	rule_trim_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_both
		},
	]}

	rule_truth_value__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_true
		},
	]}

	rule_truth_value__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_false
		},
	]}

	rule_truth_value__3_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unknown
		},
	]}

	rule_truth_value_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_truth_value__1_
		},
	]}
	rule_truth_value_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_truth_value__2_
		},
	]}
	rule_truth_value_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_truth_value__3_
		},
	]}

	rule_unique_column_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_column_name_list_
		},
	]}

	rule_unique_constraint_definition__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unique_specification_
		},
		&EarleyRuleOrString{
			rule: rule_left_paren_
		},
		&EarleyRuleOrString{
			rule: rule_unique_column_list_
		},
		&EarleyRuleOrString{
			rule: rule_right_paren_
		},
	]}

	rule_unique_constraint_definition_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unique_constraint_definition__1_
		},
	]}

	rule_unique_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_primary
		},
		&EarleyRuleOrString{
			rule: rule_key
		},
	]}

	rule_unique_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unique_specification__1_
		},
	]}

	rule_unqualified_schema_name__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_identifier_
		},
	]}

	rule_unqualified_schema_name_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unqualified_schema_name__1_
		},
	]}

	rule_unsigned_integer_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule__integer
		},
	]}

	rule_unsigned_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_numeric_literal_
		},
	]}
	rule_unsigned_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_literal_
		},
	]}

	rule_unsigned_numeric_literal_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_exact_numeric_literal_
		},
	]}

	rule_unsigned_value_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_literal_
		},
	]}

	rule_unsigned_value_specification__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_value_specification_
		},
	]}

	rule_unsigned_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_value_specification__1_
		},
	]}
	rule_unsigned_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_unsigned_value_specification__2_
		},
	]}

	rule_update_source__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_update_source__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_contextually_typed_value_specification_
		},
	]}

	rule_update_source_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update_source__1_
		},
	]}
	rule_update_source_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update_source__2_
		},
	]}

	rule_update_statement_searched__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update
		},
		&EarleyRuleOrString{
			rule: rule_target_table_
		},
		&EarleyRuleOrString{
			rule: rule_set
		},
		&EarleyRuleOrString{
			rule: rule_set_clause_list_
		},
	]}

	rule_update_statement_searched__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update
		},
		&EarleyRuleOrString{
			rule: rule_target_table_
		},
		&EarleyRuleOrString{
			rule: rule_set
		},
		&EarleyRuleOrString{
			rule: rule_set_clause_list_
		},
		&EarleyRuleOrString{
			rule: rule_where
		},
		&EarleyRuleOrString{
			rule: rule_search_condition_
		},
	]}

	rule_update_statement_searched_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update_statement_searched__1_
		},
	]}
	rule_update_statement_searched_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_update_statement_searched__2_
		},
	]}

	rule_update_target_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_object_column_
		},
	]}

	rule_value_expression_list__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_value_expression_list__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_list_
		},
		&EarleyRuleOrString{
			rule: rule_comma_
		},
		&EarleyRuleOrString{
			rule: rule_value_expression_
		},
	]}

	rule_value_expression_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_list__1_
		},
	]}
	rule_value_expression_list_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_list__2_
		},
	]}

	rule_value_expression_primary__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_parenthesized_value_expression_
		},
	]}

	rule_value_expression_primary__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_nonparenthesized_value_expression_primary_
		},
	]}

	rule_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_primary__1_
		},
	]}
	rule_value_expression_primary_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression_primary__2_
		},
	]}

	rule_value_expression__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_common_value_expression_
		},
	]}

	rule_value_expression__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_boolean_value_expression_
		},
	]}

	rule_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression__1_
		},
	]}
	rule_value_expression_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_expression__2_
		},
	]}

	rule_value_specification__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_literal_
		},
	]}

	rule_value_specification__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_general_value_specification_
		},
	]}

	rule_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_specification__1_
		},
	]}
	rule_value_specification_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_value_specification__2_
		},
	]}

	rule_where_clause__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_where
		},
		&EarleyRuleOrString{
			rule: rule_search_condition_
		},
	]}

	rule_where_clause_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_where_clause__1_
		},
	]}

	rule_with_or_without_time_zone__1_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_with
		},
		&EarleyRuleOrString{
			rule: rule_time
		},
		&EarleyRuleOrString{
			rule: rule_zone
		},
	]}

	rule_with_or_without_time_zone__2_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_without
		},
		&EarleyRuleOrString{
			rule: rule_time
		},
		&EarleyRuleOrString{
			rule: rule_zone
		},
	]}

	rule_with_or_without_time_zone_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_with_or_without_time_zone__1_
		},
	]}
	rule_with_or_without_time_zone_.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			rule: rule_with_or_without_time_zone__2_
		},
	]}

	rule__identifier.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '^identifier'
			rule: 0
		},
	]}

	rule__integer.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '^integer'
			rule: 0
		},
	]}

	rule__string.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: '^string'
			rule: 0
		},
	]}

	rule_a.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'A'
			rule: 0
		},
	]}

	rule_abs.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ABS'
			rule: 0
		},
	]}

	rule_absolute.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ABSOLUTE'
			rule: 0
		},
	]}

	rule_acos.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ACOS'
			rule: 0
		},
	]}

	rule_action.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ACTION'
			rule: 0
		},
	]}

	rule_ada.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ADA'
			rule: 0
		},
	]}

	rule_add.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ADD'
			rule: 0
		},
	]}

	rule_admin.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ADMIN'
			rule: 0
		},
	]}

	rule_after.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'AFTER'
			rule: 0
		},
	]}

	rule_alter.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ALTER'
			rule: 0
		},
	]}

	rule_always.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ALWAYS'
			rule: 0
		},
	]}

	rule_and.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'AND'
			rule: 0
		},
	]}

	rule_as.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'AS'
			rule: 0
		},
	]}

	rule_asc.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ASC'
			rule: 0
		},
	]}

	rule_asin.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ASIN'
			rule: 0
		},
	]}

	rule_assertion.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ASSERTION'
			rule: 0
		},
	]}

	rule_assignment.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ASSIGNMENT'
			rule: 0
		},
	]}

	rule_asymmetric.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ASYMMETRIC'
			rule: 0
		},
	]}

	rule_atan.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ATAN'
			rule: 0
		},
	]}

	rule_attribute.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ATTRIBUTE'
			rule: 0
		},
	]}

	rule_attributes.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ATTRIBUTES'
			rule: 0
		},
	]}

	rule_avg.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'AVG'
			rule: 0
		},
	]}

	rule_before.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BEFORE'
			rule: 0
		},
	]}

	rule_bernoulli.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BERNOULLI'
			rule: 0
		},
	]}

	rule_between.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BETWEEN'
			rule: 0
		},
	]}

	rule_bigint.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BIGINT'
			rule: 0
		},
	]}

	rule_boolean.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BOOLEAN'
			rule: 0
		},
	]}

	rule_both.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BOTH'
			rule: 0
		},
	]}

	rule_breadth.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BREADTH'
			rule: 0
		},
	]}

	rule_by.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'BY'
			rule: 0
		},
	]}

	rule_c.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'C'
			rule: 0
		},
	]}

	rule_cascade.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CASCADE'
			rule: 0
		},
	]}

	rule_cast.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CAST'
			rule: 0
		},
	]}

	rule_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CATALOG'
			rule: 0
		},
	]}

	rule_catalog_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CATALOG_NAME'
			rule: 0
		},
	]}

	rule_ceil.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CEIL'
			rule: 0
		},
	]}

	rule_ceiling.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CEILING'
			rule: 0
		},
	]}

	rule_chain.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHAIN'
			rule: 0
		},
	]}

	rule_chaining.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHAINING'
			rule: 0
		},
	]}

	rule_char.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHAR'
			rule: 0
		},
	]}

	rule_char_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHAR_LENGTH'
			rule: 0
		},
	]}

	rule_character.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHARACTER'
			rule: 0
		},
	]}

	rule_character_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHARACTER_LENGTH'
			rule: 0
		},
	]}

	rule_character_set_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHARACTER_SET_CATALOG'
			rule: 0
		},
	]}

	rule_character_set_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHARACTER_SET_NAME'
			rule: 0
		},
	]}

	rule_character_set_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHARACTER_SET_SCHEMA'
			rule: 0
		},
	]}

	rule_characteristics.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHARACTERISTICS'
			rule: 0
		},
	]}

	rule_characters.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CHARACTERS'
			rule: 0
		},
	]}

	rule_class_origin.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CLASS_ORIGIN'
			rule: 0
		},
	]}

	rule_coalesce.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COALESCE'
			rule: 0
		},
	]}

	rule_cobol.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COBOL'
			rule: 0
		},
	]}

	rule_collation.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COLLATION'
			rule: 0
		},
	]}

	rule_collation_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COLLATION_CATALOG'
			rule: 0
		},
	]}

	rule_collation_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COLLATION_NAME'
			rule: 0
		},
	]}

	rule_collation_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COLLATION_SCHEMA'
			rule: 0
		},
	]}

	rule_column_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COLUMN_NAME'
			rule: 0
		},
	]}

	rule_columns.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COLUMNS'
			rule: 0
		},
	]}

	rule_command_function.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COMMAND_FUNCTION'
			rule: 0
		},
	]}

	rule_command_function_code.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COMMAND_FUNCTION_CODE'
			rule: 0
		},
	]}

	rule_commit.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COMMIT'
			rule: 0
		},
	]}

	rule_committed.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COMMITTED'
			rule: 0
		},
	]}

	rule_condition_number.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONDITION_NUMBER'
			rule: 0
		},
	]}

	rule_conditional.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONDITIONAL'
			rule: 0
		},
	]}

	rule_connection.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONNECTION'
			rule: 0
		},
	]}

	rule_connection_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONNECTION_NAME'
			rule: 0
		},
	]}

	rule_constraint_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONSTRAINT_CATALOG'
			rule: 0
		},
	]}

	rule_constraint_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONSTRAINT_NAME'
			rule: 0
		},
	]}

	rule_constraint_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONSTRAINT_SCHEMA'
			rule: 0
		},
	]}

	rule_constraints.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONSTRAINTS'
			rule: 0
		},
	]}

	rule_constructor.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONSTRUCTOR'
			rule: 0
		},
	]}

	rule_continue.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CONTINUE'
			rule: 0
		},
	]}

	rule_cos.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COS'
			rule: 0
		},
	]}

	rule_cosh.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COSH'
			rule: 0
		},
	]}

	rule_count.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'COUNT'
			rule: 0
		},
	]}

	rule_create.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CREATE'
			rule: 0
		},
	]}

	rule_current_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CURRENT_CATALOG'
			rule: 0
		},
	]}

	rule_current_date.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CURRENT_DATE'
			rule: 0
		},
	]}

	rule_current_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CURRENT_SCHEMA'
			rule: 0
		},
	]}

	rule_current_time.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CURRENT_TIME'
			rule: 0
		},
	]}

	rule_current_timestamp.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CURRENT_TIMESTAMP'
			rule: 0
		},
	]}

	rule_cursor_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CURSOR_NAME'
			rule: 0
		},
	]}

	rule_cycle.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'CYCLE'
			rule: 0
		},
	]}

	rule_data.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DATA'
			rule: 0
		},
	]}

	rule_date.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DATE'
			rule: 0
		},
	]}

	rule_datetime_interval_code.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DATETIME_INTERVAL_CODE'
			rule: 0
		},
	]}

	rule_datetime_interval_precision.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DATETIME_INTERVAL_PRECISION'
			rule: 0
		},
	]}

	rule_defaults.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DEFAULTS'
			rule: 0
		},
	]}

	rule_deferrable.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DEFERRABLE'
			rule: 0
		},
	]}

	rule_deferred.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DEFERRED'
			rule: 0
		},
	]}

	rule_defined.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DEFINED'
			rule: 0
		},
	]}

	rule_definer.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DEFINER'
			rule: 0
		},
	]}

	rule_degree.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DEGREE'
			rule: 0
		},
	]}

	rule_delete.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DELETE'
			rule: 0
		},
	]}

	rule_depth.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DEPTH'
			rule: 0
		},
	]}

	rule_derived.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DERIVED'
			rule: 0
		},
	]}

	rule_desc.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESC'
			rule: 0
		},
	]}

	rule_describe_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESCRIBE_CATALOG'
			rule: 0
		},
	]}

	rule_describe_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESCRIBE_NAME'
			rule: 0
		},
	]}

	rule_describe_procedure_specific_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESCRIBE_PROCEDURE_SPECIFIC_CATALOG'
			rule: 0
		},
	]}

	rule_describe_procedure_specific_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESCRIBE_PROCEDURE_SPECIFIC_NAME'
			rule: 0
		},
	]}

	rule_describe_procedure_specific_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESCRIBE_PROCEDURE_SPECIFIC_SCHEMA'
			rule: 0
		},
	]}

	rule_describe_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESCRIBE_SCHEMA'
			rule: 0
		},
	]}

	rule_descriptor.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DESCRIPTOR'
			rule: 0
		},
	]}

	rule_diagnostics.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DIAGNOSTICS'
			rule: 0
		},
	]}

	rule_dispatch.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DISPATCH'
			rule: 0
		},
	]}

	rule_domain.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DOMAIN'
			rule: 0
		},
	]}

	rule_double.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DOUBLE'
			rule: 0
		},
	]}

	rule_drop.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DROP'
			rule: 0
		},
	]}

	rule_dynamic_function.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DYNAMIC_FUNCTION'
			rule: 0
		},
	]}

	rule_dynamic_function_code.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'DYNAMIC_FUNCTION_CODE'
			rule: 0
		},
	]}

	rule_encoding.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ENCODING'
			rule: 0
		},
	]}

	rule_enforced.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ENFORCED'
			rule: 0
		},
	]}

	rule_error.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ERROR'
			rule: 0
		},
	]}

	rule_exclude.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'EXCLUDE'
			rule: 0
		},
	]}

	rule_excluding.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'EXCLUDING'
			rule: 0
		},
	]}

	rule_exp.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'EXP'
			rule: 0
		},
	]}

	rule_expression.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'EXPRESSION'
			rule: 0
		},
	]}

	rule_false.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FALSE'
			rule: 0
		},
	]}

	rule_fetch.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FETCH'
			rule: 0
		},
	]}

	rule_final.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINAL'
			rule: 0
		},
	]}

	rule_finish.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINISH'
			rule: 0
		},
	]}

	rule_finish_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINISH_CATALOG'
			rule: 0
		},
	]}

	rule_finish_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINISH_NAME'
			rule: 0
		},
	]}

	rule_finish_procedure_specific_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINISH_PROCEDURE_SPECIFIC_CATALOG'
			rule: 0
		},
	]}

	rule_finish_procedure_specific_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINISH_PROCEDURE_SPECIFIC_NAME'
			rule: 0
		},
	]}

	rule_finish_procedure_specific_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINISH_PROCEDURE_SPECIFIC_SCHEMA'
			rule: 0
		},
	]}

	rule_finish_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FINISH_SCHEMA'
			rule: 0
		},
	]}

	rule_first.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FIRST'
			rule: 0
		},
	]}

	rule_flag.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FLAG'
			rule: 0
		},
	]}

	rule_float.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FLOAT'
			rule: 0
		},
	]}

	rule_floor.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FLOOR'
			rule: 0
		},
	]}

	rule_following.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FOLLOWING'
			rule: 0
		},
	]}

	rule_for.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FOR'
			rule: 0
		},
	]}

	rule_format.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FORMAT'
			rule: 0
		},
	]}

	rule_fortran.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FORTRAN'
			rule: 0
		},
	]}

	rule_found.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FOUND'
			rule: 0
		},
	]}

	rule_from.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FROM'
			rule: 0
		},
	]}

	rule_fulfill.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FULFILL'
			rule: 0
		},
	]}

	rule_fulfill_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FULFILL_CATALOG'
			rule: 0
		},
	]}

	rule_fulfill_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FULFILL_NAME'
			rule: 0
		},
	]}

	rule_fulfill_procedure_specific_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FULFILL_PROCEDURE_SPECIFIC_CATALOG'
			rule: 0
		},
	]}

	rule_fulfill_procedure_specific_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FULFILL_PROCEDURE_SPECIFIC_NAME'
			rule: 0
		},
	]}

	rule_fulfill_procedure_specific_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FULFILL_PROCEDURE_SPECIFIC_SCHEMA'
			rule: 0
		},
	]}

	rule_fulfill_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'FULFILL_SCHEMA'
			rule: 0
		},
	]}

	rule_g.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'G'
			rule: 0
		},
	]}

	rule_general.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'GENERAL'
			rule: 0
		},
	]}

	rule_generated.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'GENERATED'
			rule: 0
		},
	]}

	rule_go.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'GO'
			rule: 0
		},
	]}

	rule_goto.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'GOTO'
			rule: 0
		},
	]}

	rule_granted.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'GRANTED'
			rule: 0
		},
	]}

	rule_group.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'GROUP'
			rule: 0
		},
	]}

	rule_has_pass_through_columns.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'HAS_PASS_THROUGH_COLUMNS'
			rule: 0
		},
	]}

	rule_has_pass_thru_cols.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'HAS_PASS_THRU_COLS'
			rule: 0
		},
	]}

	rule_hierarchy.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'HIERARCHY'
			rule: 0
		},
	]}

	rule_ignore.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'IGNORE'
			rule: 0
		},
	]}

	rule_immediate.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'IMMEDIATE'
			rule: 0
		},
	]}

	rule_immediately.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'IMMEDIATELY'
			rule: 0
		},
	]}

	rule_implementation.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'IMPLEMENTATION'
			rule: 0
		},
	]}

	rule_in.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'IN'
			rule: 0
		},
	]}

	rule_including.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INCLUDING'
			rule: 0
		},
	]}

	rule_increment.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INCREMENT'
			rule: 0
		},
	]}

	rule_initially.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INITIALLY'
			rule: 0
		},
	]}

	rule_inner.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INNER'
			rule: 0
		},
	]}

	rule_input.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INPUT'
			rule: 0
		},
	]}

	rule_insert.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INSERT'
			rule: 0
		},
	]}

	rule_instance.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INSTANCE'
			rule: 0
		},
	]}

	rule_instantiable.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INSTANTIABLE'
			rule: 0
		},
	]}

	rule_instead.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INSTEAD'
			rule: 0
		},
	]}

	rule_int.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INT'
			rule: 0
		},
	]}

	rule_integer.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INTEGER'
			rule: 0
		},
	]}

	rule_into.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INTO'
			rule: 0
		},
	]}

	rule_invoker.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'INVOKER'
			rule: 0
		},
	]}

	rule_is.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'IS'
			rule: 0
		},
	]}

	rule_is_prunable.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'IS_PRUNABLE'
			rule: 0
		},
	]}

	rule_isolation.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ISOLATION'
			rule: 0
		},
	]}

	rule_join.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'JOIN'
			rule: 0
		},
	]}

	rule_json.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'JSON'
			rule: 0
		},
	]}

	rule_k.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'K'
			rule: 0
		},
	]}

	rule_keep.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'KEEP'
			rule: 0
		},
	]}

	rule_key.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'KEY'
			rule: 0
		},
	]}

	rule_key_member.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'KEY_MEMBER'
			rule: 0
		},
	]}

	rule_key_type.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'KEY_TYPE'
			rule: 0
		},
	]}

	rule_keys.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'KEYS'
			rule: 0
		},
	]}

	rule_last.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LAST'
			rule: 0
		},
	]}

	rule_leading.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LEADING'
			rule: 0
		},
	]}

	rule_left.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LEFT'
			rule: 0
		},
	]}

	rule_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LENGTH'
			rule: 0
		},
	]}

	rule_level.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LEVEL'
			rule: 0
		},
	]}

	rule_like.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LIKE'
			rule: 0
		},
	]}

	rule_ln.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LN'
			rule: 0
		},
	]}

	rule_localtime.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LOCALTIME'
			rule: 0
		},
	]}

	rule_localtimestamp.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LOCALTIMESTAMP'
			rule: 0
		},
	]}

	rule_locator.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LOCATOR'
			rule: 0
		},
	]}

	rule_log10.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LOG10'
			rule: 0
		},
	]}

	rule_lower.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'LOWER'
			rule: 0
		},
	]}

	rule_m.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'M'
			rule: 0
		},
	]}

	rule_map.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MAP'
			rule: 0
		},
	]}

	rule_matched.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MATCHED'
			rule: 0
		},
	]}

	rule_max.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MAX'
			rule: 0
		},
	]}

	rule_maxvalue.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MAXVALUE'
			rule: 0
		},
	]}

	rule_message_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MESSAGE_LENGTH'
			rule: 0
		},
	]}

	rule_message_octet_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MESSAGE_OCTET_LENGTH'
			rule: 0
		},
	]}

	rule_message_text.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MESSAGE_TEXT'
			rule: 0
		},
	]}

	rule_min.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MIN'
			rule: 0
		},
	]}

	rule_minvalue.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MINVALUE'
			rule: 0
		},
	]}

	rule_mod.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MOD'
			rule: 0
		},
	]}

	rule_more.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MORE'
			rule: 0
		},
	]}

	rule_mumps.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'MUMPS'
			rule: 0
		},
	]}

	rule_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NAME'
			rule: 0
		},
	]}

	rule_names.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NAMES'
			rule: 0
		},
	]}

	rule_nested.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NESTED'
			rule: 0
		},
	]}

	rule_nesting.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NESTING'
			rule: 0
		},
	]}

	rule_next.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NEXT'
			rule: 0
		},
	]}

	rule_nfc.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NFC'
			rule: 0
		},
	]}

	rule_nfd.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NFD'
			rule: 0
		},
	]}

	rule_nfkc.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NFKC'
			rule: 0
		},
	]}

	rule_nfkd.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NFKD'
			rule: 0
		},
	]}

	rule_no.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NO'
			rule: 0
		},
	]}

	rule_normalized.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NORMALIZED'
			rule: 0
		},
	]}

	rule_not.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NOT'
			rule: 0
		},
	]}

	rule_null.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NULL'
			rule: 0
		},
	]}

	rule_nullable.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NULLABLE'
			rule: 0
		},
	]}

	rule_nullif.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NULLIF'
			rule: 0
		},
	]}

	rule_nulls.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NULLS'
			rule: 0
		},
	]}

	rule_number.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'NUMBER'
			rule: 0
		},
	]}

	rule_object.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OBJECT'
			rule: 0
		},
	]}

	rule_octet_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OCTET_LENGTH'
			rule: 0
		},
	]}

	rule_octets.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OCTETS'
			rule: 0
		},
	]}

	rule_offset.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OFFSET'
			rule: 0
		},
	]}

	rule_on.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ON'
			rule: 0
		},
	]}

	rule_only.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ONLY'
			rule: 0
		},
	]}

	rule_option.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OPTION'
			rule: 0
		},
	]}

	rule_options.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OPTIONS'
			rule: 0
		},
	]}

	rule_or.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OR'
			rule: 0
		},
	]}

	rule_order.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ORDER'
			rule: 0
		},
	]}

	rule_ordering.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ORDERING'
			rule: 0
		},
	]}

	rule_ordinality.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ORDINALITY'
			rule: 0
		},
	]}

	rule_others.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OTHERS'
			rule: 0
		},
	]}

	rule_outer.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OUTER'
			rule: 0
		},
	]}

	rule_output.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OUTPUT'
			rule: 0
		},
	]}

	rule_overflow.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OVERFLOW'
			rule: 0
		},
	]}

	rule_overriding.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'OVERRIDING'
			rule: 0
		},
	]}

	rule_p.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'P'
			rule: 0
		},
	]}

	rule_pad.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PAD'
			rule: 0
		},
	]}

	rule_parameter_mode.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PARAMETER_MODE'
			rule: 0
		},
	]}

	rule_parameter_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PARAMETER_NAME'
			rule: 0
		},
	]}

	rule_parameter_ordinal_position.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PARAMETER_ORDINAL_POSITION'
			rule: 0
		},
	]}

	rule_parameter_specific_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PARAMETER_SPECIFIC_CATALOG'
			rule: 0
		},
	]}

	rule_parameter_specific_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PARAMETER_SPECIFIC_NAME'
			rule: 0
		},
	]}

	rule_parameter_specific_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PARAMETER_SPECIFIC_SCHEMA'
			rule: 0
		},
	]}

	rule_partial.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PARTIAL'
			rule: 0
		},
	]}

	rule_pascal.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PASCAL'
			rule: 0
		},
	]}

	rule_pass.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PASS'
			rule: 0
		},
	]}

	rule_passing.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PASSING'
			rule: 0
		},
	]}

	rule_past.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PAST'
			rule: 0
		},
	]}

	rule_path.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PATH'
			rule: 0
		},
	]}

	rule_placing.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PLACING'
			rule: 0
		},
	]}

	rule_plan.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PLAN'
			rule: 0
		},
	]}

	rule_pli.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PLI'
			rule: 0
		},
	]}

	rule_position.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'POSITION'
			rule: 0
		},
	]}

	rule_power.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'POWER'
			rule: 0
		},
	]}

	rule_preceding.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRECEDING'
			rule: 0
		},
	]}

	rule_precision.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRECISION'
			rule: 0
		},
	]}

	rule_preserve.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRESERVE'
			rule: 0
		},
	]}

	rule_primary.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRIMARY'
			rule: 0
		},
	]}

	rule_prior.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRIOR'
			rule: 0
		},
	]}

	rule_private.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRIVATE'
			rule: 0
		},
	]}

	rule_private_parameters.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRIVATE_PARAMETERS'
			rule: 0
		},
	]}

	rule_private_params_s.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRIVATE_PARAMS_S'
			rule: 0
		},
	]}

	rule_privileges.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRIVILEGES'
			rule: 0
		},
	]}

	rule_prune.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PRUNE'
			rule: 0
		},
	]}

	rule_public.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'PUBLIC'
			rule: 0
		},
	]}

	rule_quotes.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'QUOTES'
			rule: 0
		},
	]}

	rule_read.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'READ'
			rule: 0
		},
	]}

	rule_real.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'REAL'
			rule: 0
		},
	]}

	rule_relative.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RELATIVE'
			rule: 0
		},
	]}

	rule_repeatable.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'REPEATABLE'
			rule: 0
		},
	]}

	rule_respect.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RESPECT'
			rule: 0
		},
	]}

	rule_restart.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RESTART'
			rule: 0
		},
	]}

	rule_restrict.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RESTRICT'
			rule: 0
		},
	]}

	rule_ret_only_pass_thru.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RET_ONLY_PASS_THRU'
			rule: 0
		},
	]}

	rule_returned_cardinality.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RETURNED_CARDINALITY'
			rule: 0
		},
	]}

	rule_returned_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RETURNED_LENGTH'
			rule: 0
		},
	]}

	rule_returned_octet_length.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RETURNED_OCTET_LENGTH'
			rule: 0
		},
	]}

	rule_returned_sqlstate.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RETURNED_SQLSTATE'
			rule: 0
		},
	]}

	rule_returning.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RETURNING'
			rule: 0
		},
	]}

	rule_returns_only_pass_through.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RETURNS_ONLY_PASS_THROUGH'
			rule: 0
		},
	]}

	rule_right.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'RIGHT'
			rule: 0
		},
	]}

	rule_role.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROLE'
			rule: 0
		},
	]}

	rule_rollback.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROLLBACK'
			rule: 0
		},
	]}

	rule_routine.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROUTINE'
			rule: 0
		},
	]}

	rule_routine_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROUTINE_CATALOG'
			rule: 0
		},
	]}

	rule_routine_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROUTINE_NAME'
			rule: 0
		},
	]}

	rule_routine_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROUTINE_SCHEMA'
			rule: 0
		},
	]}

	rule_row.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROW'
			rule: 0
		},
	]}

	rule_row_count.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROW_COUNT'
			rule: 0
		},
	]}

	rule_rows.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ROWS'
			rule: 0
		},
	]}

	rule_scalar.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SCALAR'
			rule: 0
		},
	]}

	rule_scale.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SCALE'
			rule: 0
		},
	]}

	rule_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SCHEMA'
			rule: 0
		},
	]}

	rule_schema_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SCHEMA_NAME'
			rule: 0
		},
	]}

	rule_scope_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SCOPE_CATALOG'
			rule: 0
		},
	]}

	rule_scope_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SCOPE_NAME'
			rule: 0
		},
	]}

	rule_scope_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SCOPE_SCHEMA'
			rule: 0
		},
	]}

	rule_section.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SECTION'
			rule: 0
		},
	]}

	rule_security.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SECURITY'
			rule: 0
		},
	]}

	rule_select.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SELECT'
			rule: 0
		},
	]}

	rule_self.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SELF'
			rule: 0
		},
	]}

	rule_sequence.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SEQUENCE'
			rule: 0
		},
	]}

	rule_serializable.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SERIALIZABLE'
			rule: 0
		},
	]}

	rule_server_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SERVER_NAME'
			rule: 0
		},
	]}

	rule_session.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SESSION'
			rule: 0
		},
	]}

	rule_set.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SET'
			rule: 0
		},
	]}

	rule_sets.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SETS'
			rule: 0
		},
	]}

	rule_similar.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SIMILAR'
			rule: 0
		},
	]}

	rule_simple.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SIMPLE'
			rule: 0
		},
	]}

	rule_sin.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SIN'
			rule: 0
		},
	]}

	rule_sinh.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SINH'
			rule: 0
		},
	]}

	rule_size.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SIZE'
			rule: 0
		},
	]}

	rule_smallint.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SMALLINT'
			rule: 0
		},
	]}

	rule_source.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SOURCE'
			rule: 0
		},
	]}

	rule_space.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SPACE'
			rule: 0
		},
	]}

	rule_specific_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SPECIFIC_NAME'
			rule: 0
		},
	]}

	rule_sqrt.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SQRT'
			rule: 0
		},
	]}

	rule_start.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'START'
			rule: 0
		},
	]}

	rule_start_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'START_CATALOG'
			rule: 0
		},
	]}

	rule_start_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'START_NAME'
			rule: 0
		},
	]}

	rule_start_procedure_specific_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'START_PROCEDURE_SPECIFIC_CATALOG'
			rule: 0
		},
	]}

	rule_start_procedure_specific_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'START_PROCEDURE_SPECIFIC_NAME'
			rule: 0
		},
	]}

	rule_start_procedure_specific_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'START_PROCEDURE_SPECIFIC_SCHEMA'
			rule: 0
		},
	]}

	rule_start_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'START_SCHEMA'
			rule: 0
		},
	]}

	rule_state.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'STATE'
			rule: 0
		},
	]}

	rule_statement.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'STATEMENT'
			rule: 0
		},
	]}

	rule_string.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'STRING'
			rule: 0
		},
	]}

	rule_structure.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'STRUCTURE'
			rule: 0
		},
	]}

	rule_style.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'STYLE'
			rule: 0
		},
	]}

	rule_subclass_origin.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SUBCLASS_ORIGIN'
			rule: 0
		},
	]}

	rule_substring.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SUBSTRING'
			rule: 0
		},
	]}

	rule_sum.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SUM'
			rule: 0
		},
	]}

	rule_symmetric.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'SYMMETRIC'
			rule: 0
		},
	]}

	rule_t.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'T'
			rule: 0
		},
	]}

	rule_table.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TABLE'
			rule: 0
		},
	]}

	rule_table_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TABLE_NAME'
			rule: 0
		},
	]}

	rule_table_semantics.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TABLE_SEMANTICS'
			rule: 0
		},
	]}

	rule_tan.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TAN'
			rule: 0
		},
	]}

	rule_tanh.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TANH'
			rule: 0
		},
	]}

	rule_temporary.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TEMPORARY'
			rule: 0
		},
	]}

	rule_through.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'THROUGH'
			rule: 0
		},
	]}

	rule_ties.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TIES'
			rule: 0
		},
	]}

	rule_time.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TIME'
			rule: 0
		},
	]}

	rule_timestamp.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TIMESTAMP'
			rule: 0
		},
	]}

	rule_to.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TO'
			rule: 0
		},
	]}

	rule_top_level_count.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TOP_LEVEL_COUNT'
			rule: 0
		},
	]}

	rule_trailing.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRAILING'
			rule: 0
		},
	]}

	rule_transaction.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRANSACTION'
			rule: 0
		},
	]}

	rule_transaction_active.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRANSACTION_ACTIVE'
			rule: 0
		},
	]}

	rule_transactions_committed.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRANSACTIONS_COMMITTED'
			rule: 0
		},
	]}

	rule_transactions_rolled_back.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRANSACTIONS_ROLLED_BACK'
			rule: 0
		},
	]}

	rule_transform.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRANSFORM'
			rule: 0
		},
	]}

	rule_transforms.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRANSFORMS'
			rule: 0
		},
	]}

	rule_trigger_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRIGGER_CATALOG'
			rule: 0
		},
	]}

	rule_trigger_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRIGGER_NAME'
			rule: 0
		},
	]}

	rule_trigger_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRIGGER_SCHEMA'
			rule: 0
		},
	]}

	rule_trim.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRIM'
			rule: 0
		},
	]}

	rule_true.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TRUE'
			rule: 0
		},
	]}

	rule_type.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'TYPE'
			rule: 0
		},
	]}

	rule_unbounded.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UNBOUNDED'
			rule: 0
		},
	]}

	rule_uncommitted.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UNCOMMITTED'
			rule: 0
		},
	]}

	rule_unconditional.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UNCONDITIONAL'
			rule: 0
		},
	]}

	rule_under.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UNDER'
			rule: 0
		},
	]}

	rule_unknown.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UNKNOWN'
			rule: 0
		},
	]}

	rule_unnamed.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UNNAMED'
			rule: 0
		},
	]}

	rule_update.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UPDATE'
			rule: 0
		},
	]}

	rule_upper.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UPPER'
			rule: 0
		},
	]}

	rule_usage.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'USAGE'
			rule: 0
		},
	]}

	rule_user_defined_type_catalog.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'USER_DEFINED_TYPE_CATALOG'
			rule: 0
		},
	]}

	rule_user_defined_type_code.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'USER_DEFINED_TYPE_CODE'
			rule: 0
		},
	]}

	rule_user_defined_type_name.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'USER_DEFINED_TYPE_NAME'
			rule: 0
		},
	]}

	rule_user_defined_type_schema.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'USER_DEFINED_TYPE_SCHEMA'
			rule: 0
		},
	]}

	rule_using.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'USING'
			rule: 0
		},
	]}

	rule_utf16.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UTF16'
			rule: 0
		},
	]}

	rule_utf32.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UTF32'
			rule: 0
		},
	]}

	rule_utf8.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'UTF8'
			rule: 0
		},
	]}

	rule_value.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'VALUE'
			rule: 0
		},
	]}

	rule_values.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'VALUES'
			rule: 0
		},
	]}

	rule_varchar.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'VARCHAR'
			rule: 0
		},
	]}

	rule_varying.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'VARYING'
			rule: 0
		},
	]}

	rule_view.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'VIEW'
			rule: 0
		},
	]}

	rule_where.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'WHERE'
			rule: 0
		},
	]}

	rule_with.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'WITH'
			rule: 0
		},
	]}

	rule_without.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'WITHOUT'
			rule: 0
		},
	]}

	rule_work.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'WORK'
			rule: 0
		},
	]}

	rule_wrapper.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'WRAPPER'
			rule: 0
		},
	]}

	rule_write.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'WRITE'
			rule: 0
		},
	]}

	rule_zone.productions << &EarleyProduction{[
		&EarleyRuleOrString{
			str: 'ZONE'
			rule: 0
		},
	]}

	rules['<absolute value expression: #1>'] = rule_absolute_value_expression__1_
	rules['<absolute value expression>'] = rule_absolute_value_expression_
	rules['<actual identifier>'] = rule_actual_identifier_
	rules['<aggregate function: #1>'] = rule_aggregate_function__1_
	rules['<aggregate function>'] = rule_aggregate_function_
	rules['<alter sequence generator option: #1>'] = rule_alter_sequence_generator_option__1_
	rules['<alter sequence generator option>'] = rule_alter_sequence_generator_option_
	rules['<alter sequence generator options: #1>'] = rule_alter_sequence_generator_options__1_
	rules['<alter sequence generator options: #2>'] = rule_alter_sequence_generator_options__2_
	rules['<alter sequence generator options>'] = rule_alter_sequence_generator_options_
	rules['<alter sequence generator restart option: #1>'] = rule_alter_sequence_generator_restart_option__1_
	rules['<alter sequence generator restart option: #2>'] = rule_alter_sequence_generator_restart_option__2_
	rules['<alter sequence generator restart option>'] = rule_alter_sequence_generator_restart_option_
	rules['<alter sequence generator statement: #1>'] = rule_alter_sequence_generator_statement__1_
	rules['<alter sequence generator statement>'] = rule_alter_sequence_generator_statement_
	rules['<approximate numeric type: #1>'] = rule_approximate_numeric_type__1_
	rules['<approximate numeric type: #2>'] = rule_approximate_numeric_type__2_
	rules['<approximate numeric type: #3>'] = rule_approximate_numeric_type__3_
	rules['<approximate numeric type: #4>'] = rule_approximate_numeric_type__4_
	rules['<approximate numeric type>'] = rule_approximate_numeric_type_
	rules['<as clause: #1>'] = rule_as_clause__1_
	rules['<as clause>'] = rule_as_clause_
	rules['<asterisk>'] = rule_asterisk_
	rules['<asterisked identifier chain>'] = rule_asterisked_identifier_chain_
	rules['<asterisked identifier>'] = rule_asterisked_identifier_
	rules['<basic identifier chain>'] = rule_basic_identifier_chain_
	rules['<basic sequence generator option: #1>'] = rule_basic_sequence_generator_option__1_
	rules['<basic sequence generator option: #2>'] = rule_basic_sequence_generator_option__2_
	rules['<basic sequence generator option: #3>'] = rule_basic_sequence_generator_option__3_
	rules['<basic sequence generator option: #4>'] = rule_basic_sequence_generator_option__4_
	rules['<basic sequence generator option>'] = rule_basic_sequence_generator_option_
	rules['<between predicate part 1: #1>'] = rule_between_predicate_part_1__1_
	rules['<between predicate part 1: #2>'] = rule_between_predicate_part_1__2_
	rules['<between predicate part 1>'] = rule_between_predicate_part_1_
	rules['<between predicate part 2: #1>'] = rule_between_predicate_part_2__1_
	rules['<between predicate part 2: #2>'] = rule_between_predicate_part_2__2_
	rules['<between predicate part 2>'] = rule_between_predicate_part_2_
	rules['<between predicate: #1>'] = rule_between_predicate__1_
	rules['<between predicate>'] = rule_between_predicate_
	rules['<boolean factor: #2>'] = rule_boolean_factor__2_
	rules['<boolean factor>'] = rule_boolean_factor_
	rules['<boolean literal: #1>'] = rule_boolean_literal__1_
	rules['<boolean literal: #2>'] = rule_boolean_literal__2_
	rules['<boolean literal: #3>'] = rule_boolean_literal__3_
	rules['<boolean literal>'] = rule_boolean_literal_
	rules['<boolean predicand: #1>'] = rule_boolean_predicand__1_
	rules['<boolean predicand: #2>'] = rule_boolean_predicand__2_
	rules['<boolean predicand>'] = rule_boolean_predicand_
	rules['<boolean primary: #1>'] = rule_boolean_primary__1_
	rules['<boolean primary: #2>'] = rule_boolean_primary__2_
	rules['<boolean primary>'] = rule_boolean_primary_
	rules['<boolean term: #1>'] = rule_boolean_term__1_
	rules['<boolean term: #2>'] = rule_boolean_term__2_
	rules['<boolean term>'] = rule_boolean_term_
	rules['<boolean test: #1>'] = rule_boolean_test__1_
	rules['<boolean test: #2>'] = rule_boolean_test__2_
	rules['<boolean test: #3>'] = rule_boolean_test__3_
	rules['<boolean test>'] = rule_boolean_test_
	rules['<boolean type: #1>'] = rule_boolean_type__1_
	rules['<boolean type>'] = rule_boolean_type_
	rules['<boolean value expression: #1>'] = rule_boolean_value_expression__1_
	rules['<boolean value expression: #2>'] = rule_boolean_value_expression__2_
	rules['<boolean value expression>'] = rule_boolean_value_expression_
	rules['<case abbreviation: #1>'] = rule_case_abbreviation__1_
	rules['<case abbreviation: #2>'] = rule_case_abbreviation__2_
	rules['<case abbreviation>'] = rule_case_abbreviation_
	rules['<case expression>'] = rule_case_expression_
	rules['<cast operand: #1>'] = rule_cast_operand__1_
	rules['<cast operand: #2>'] = rule_cast_operand__2_
	rules['<cast operand>'] = rule_cast_operand_
	rules['<cast specification: #1>'] = rule_cast_specification__1_
	rules['<cast specification>'] = rule_cast_specification_
	rules['<cast target>'] = rule_cast_target_
	rules['<catalog name characteristic: #1>'] = rule_catalog_name_characteristic__1_
	rules['<catalog name characteristic>'] = rule_catalog_name_characteristic_
	rules['<catalog name>'] = rule_catalog_name_
	rules['<ceiling function: #1>'] = rule_ceiling_function__1_
	rules['<ceiling function: #2>'] = rule_ceiling_function__2_
	rules['<ceiling function>'] = rule_ceiling_function_
	rules['<char length expression: #1>'] = rule_char_length_expression__1_
	rules['<char length expression: #2>'] = rule_char_length_expression__2_
	rules['<char length expression>'] = rule_char_length_expression_
	rules['<char length units>'] = rule_char_length_units_
	rules['<character factor>'] = rule_character_factor_
	rules['<character length>'] = rule_character_length_
	rules['<character like predicate part 2: #1>'] = rule_character_like_predicate_part_2__1_
	rules['<character like predicate part 2: #2>'] = rule_character_like_predicate_part_2__2_
	rules['<character like predicate part 2>'] = rule_character_like_predicate_part_2_
	rules['<character like predicate: #1>'] = rule_character_like_predicate__1_
	rules['<character like predicate>'] = rule_character_like_predicate_
	rules['<character pattern>'] = rule_character_pattern_
	rules['<character position expression: #1>'] = rule_character_position_expression__1_
	rules['<character position expression>'] = rule_character_position_expression_
	rules['<character primary: #1>'] = rule_character_primary__1_
	rules['<character primary: #2>'] = rule_character_primary__2_
	rules['<character primary>'] = rule_character_primary_
	rules['<character string literal>'] = rule_character_string_literal_
	rules['<character string type: #1>'] = rule_character_string_type__1_
	rules['<character string type: #2>'] = rule_character_string_type__2_
	rules['<character string type: #3>'] = rule_character_string_type__3_
	rules['<character string type: #4>'] = rule_character_string_type__4_
	rules['<character string type: #5>'] = rule_character_string_type__5_
	rules['<character string type: #6>'] = rule_character_string_type__6_
	rules['<character string type: #7>'] = rule_character_string_type__7_
	rules['<character string type>'] = rule_character_string_type_
	rules['<character substring function: #1>'] = rule_character_substring_function__1_
	rules['<character substring function: #2>'] = rule_character_substring_function__2_
	rules['<character substring function: #3>'] = rule_character_substring_function__3_
	rules['<character substring function: #4>'] = rule_character_substring_function__4_
	rules['<character substring function>'] = rule_character_substring_function_
	rules['<character value expression 1>'] = rule_character_value_expression_1_
	rules['<character value expression 2>'] = rule_character_value_expression_2_
	rules['<character value expression: #1>'] = rule_character_value_expression__1_
	rules['<character value expression: #2>'] = rule_character_value_expression__2_
	rules['<character value expression>'] = rule_character_value_expression_
	rules['<character value function: #1>'] = rule_character_value_function__1_
	rules['<character value function: #2>'] = rule_character_value_function__2_
	rules['<character value function: #3>'] = rule_character_value_function__3_
	rules['<character value function>'] = rule_character_value_function_
	rules['<colon>'] = rule_colon_
	rules['<column constraint definition>'] = rule_column_constraint_definition_
	rules['<column constraint: #1>'] = rule_column_constraint__1_
	rules['<column constraint>'] = rule_column_constraint_
	rules['<column definition: #1>'] = rule_column_definition__1_
	rules['<column definition: #2>'] = rule_column_definition__2_
	rules['<column definition>'] = rule_column_definition_
	rules['<column name list: #1>'] = rule_column_name_list__1_
	rules['<column name list: #2>'] = rule_column_name_list__2_
	rules['<column name list>'] = rule_column_name_list_
	rules['<column name: #1>'] = rule_column_name__1_
	rules['<column name>'] = rule_column_name_
	rules['<column reference: #1>'] = rule_column_reference__1_
	rules['<column reference>'] = rule_column_reference_
	rules['<comma>'] = rule_comma_
	rules['<commit statement: #1>'] = rule_commit_statement__1_
	rules['<commit statement: #2>'] = rule_commit_statement__2_
	rules['<commit statement>'] = rule_commit_statement_
	rules['<common logarithm: #1>'] = rule_common_logarithm__1_
	rules['<common logarithm>'] = rule_common_logarithm_
	rules['<common sequence generator option: #1>'] = rule_common_sequence_generator_option__1_
	rules['<common sequence generator option>'] = rule_common_sequence_generator_option_
	rules['<common sequence generator options: #1>'] = rule_common_sequence_generator_options__1_
	rules['<common sequence generator options: #2>'] = rule_common_sequence_generator_options__2_
	rules['<common sequence generator options>'] = rule_common_sequence_generator_options_
	rules['<common value expression: #1>'] = rule_common_value_expression__1_
	rules['<common value expression: #2>'] = rule_common_value_expression__2_
	rules['<common value expression: #3>'] = rule_common_value_expression__3_
	rules['<common value expression>'] = rule_common_value_expression_
	rules['<comp op>'] = rule_comp_op_
	rules['<comparison predicate part 2: #1>'] = rule_comparison_predicate_part_2__1_
	rules['<comparison predicate part 2>'] = rule_comparison_predicate_part_2_
	rules['<comparison predicate: #1>'] = rule_comparison_predicate__1_
	rules['<comparison predicate>'] = rule_comparison_predicate_
	rules['<computational operation>'] = rule_computational_operation_
	rules['<concatenation operator>'] = rule_concatenation_operator_
	rules['<concatenation: #1>'] = rule_concatenation__1_
	rules['<concatenation>'] = rule_concatenation_
	rules['<contextually typed row value constructor element list: #1>'] = rule_contextually_typed_row_value_constructor_element_list__1_
	rules['<contextually typed row value constructor element list: #2>'] = rule_contextually_typed_row_value_constructor_element_list__2_
	rules['<contextually typed row value constructor element list>'] = rule_contextually_typed_row_value_constructor_element_list_
	rules['<contextually typed row value constructor element: #1>'] = rule_contextually_typed_row_value_constructor_element__1_
	rules['<contextually typed row value constructor element: #2>'] = rule_contextually_typed_row_value_constructor_element__2_
	rules['<contextually typed row value constructor element>'] = rule_contextually_typed_row_value_constructor_element_
	rules['<contextually typed row value constructor: #1>'] = rule_contextually_typed_row_value_constructor__1_
	rules['<contextually typed row value constructor: #2>'] = rule_contextually_typed_row_value_constructor__2_
	rules['<contextually typed row value constructor: #3>'] = rule_contextually_typed_row_value_constructor__3_
	rules['<contextually typed row value constructor: #4>'] = rule_contextually_typed_row_value_constructor__4_
	rules['<contextually typed row value constructor: #5>'] = rule_contextually_typed_row_value_constructor__5_
	rules['<contextually typed row value constructor>'] = rule_contextually_typed_row_value_constructor_
	rules['<contextually typed row value expression list: #1>'] = rule_contextually_typed_row_value_expression_list__1_
	rules['<contextually typed row value expression list: #2>'] = rule_contextually_typed_row_value_expression_list__2_
	rules['<contextually typed row value expression list>'] = rule_contextually_typed_row_value_expression_list_
	rules['<contextually typed row value expression>'] = rule_contextually_typed_row_value_expression_
	rules['<contextually typed table value constructor: #1>'] = rule_contextually_typed_table_value_constructor__1_
	rules['<contextually typed table value constructor>'] = rule_contextually_typed_table_value_constructor_
	rules['<contextually typed value specification>'] = rule_contextually_typed_value_specification_
	rules['<correlation name: #1>'] = rule_correlation_name__1_
	rules['<correlation name>'] = rule_correlation_name_
	rules['<correlation or recognition: #1>'] = rule_correlation_or_recognition__1_
	rules['<correlation or recognition: #2>'] = rule_correlation_or_recognition__2_
	rules['<correlation or recognition: #3>'] = rule_correlation_or_recognition__3_
	rules['<correlation or recognition: #4>'] = rule_correlation_or_recognition__4_
	rules['<correlation or recognition>'] = rule_correlation_or_recognition_
	rules['<current date value function: #1>'] = rule_current_date_value_function__1_
	rules['<current date value function>'] = rule_current_date_value_function_
	rules['<current local time value function: #1>'] = rule_current_local_time_value_function__1_
	rules['<current local time value function: #2>'] = rule_current_local_time_value_function__2_
	rules['<current local time value function>'] = rule_current_local_time_value_function_
	rules['<current local timestamp value function: #1>'] = rule_current_local_timestamp_value_function__1_
	rules['<current local timestamp value function: #2>'] = rule_current_local_timestamp_value_function__2_
	rules['<current local timestamp value function>'] = rule_current_local_timestamp_value_function_
	rules['<current time value function: #1>'] = rule_current_time_value_function__1_
	rules['<current time value function: #2>'] = rule_current_time_value_function__2_
	rules['<current time value function>'] = rule_current_time_value_function_
	rules['<current timestamp value function: #1>'] = rule_current_timestamp_value_function__1_
	rules['<current timestamp value function: #2>'] = rule_current_timestamp_value_function__2_
	rules['<current timestamp value function>'] = rule_current_timestamp_value_function_
	rules['<cursor specification: #1>'] = rule_cursor_specification__1_
	rules['<cursor specification>'] = rule_cursor_specification_
	rules['<data type or domain name>'] = rule_data_type_or_domain_name_
	rules['<data type>'] = rule_data_type_
	rules['<date literal: #1>'] = rule_date_literal__1_
	rules['<date literal>'] = rule_date_literal_
	rules['<date string>'] = rule_date_string_
	rules['<datetime factor>'] = rule_datetime_factor_
	rules['<datetime literal>'] = rule_datetime_literal_
	rules['<datetime primary: #1>'] = rule_datetime_primary__1_
	rules['<datetime primary: #2>'] = rule_datetime_primary__2_
	rules['<datetime primary>'] = rule_datetime_primary_
	rules['<datetime term>'] = rule_datetime_term_
	rules['<datetime type: #1>'] = rule_datetime_type__1_
	rules['<datetime type: #2>'] = rule_datetime_type__2_
	rules['<datetime type: #3>'] = rule_datetime_type__3_
	rules['<datetime type: #4>'] = rule_datetime_type__4_
	rules['<datetime type: #5>'] = rule_datetime_type__5_
	rules['<datetime type: #6>'] = rule_datetime_type__6_
	rules['<datetime type: #7>'] = rule_datetime_type__7_
	rules['<datetime type: #8>'] = rule_datetime_type__8_
	rules['<datetime type: #9>'] = rule_datetime_type__9_
	rules['<datetime type>'] = rule_datetime_type_
	rules['<datetime value expression>'] = rule_datetime_value_expression_
	rules['<datetime value function>'] = rule_datetime_value_function_
	rules['<delete statement: searched: #1>'] = rule_delete_statement_searched__1_
	rules['<delete statement: searched: #2>'] = rule_delete_statement_searched__2_
	rules['<delete statement: searched>'] = rule_delete_statement_searched_
	rules['<derived column list>'] = rule_derived_column_list_
	rules['<derived column: #1>'] = rule_derived_column__1_
	rules['<derived column: #2>'] = rule_derived_column__2_
	rules['<derived column>'] = rule_derived_column_
	rules['<derived table>'] = rule_derived_table_
	rules['<drop behavior>'] = rule_drop_behavior_
	rules['<drop schema statement: #1>'] = rule_drop_schema_statement__1_
	rules['<drop schema statement>'] = rule_drop_schema_statement_
	rules['<drop sequence generator statement: #1>'] = rule_drop_sequence_generator_statement__1_
	rules['<drop sequence generator statement>'] = rule_drop_sequence_generator_statement_
	rules['<drop table statement: #1>'] = rule_drop_table_statement__1_
	rules['<drop table statement>'] = rule_drop_table_statement_
	rules['<dynamic select statement>'] = rule_dynamic_select_statement_
	rules['<equals operator>'] = rule_equals_operator_
	rules['<exact numeric literal: #1>'] = rule_exact_numeric_literal__1_
	rules['<exact numeric literal: #2>'] = rule_exact_numeric_literal__2_
	rules['<exact numeric literal: #3>'] = rule_exact_numeric_literal__3_
	rules['<exact numeric literal: #4>'] = rule_exact_numeric_literal__4_
	rules['<exact numeric literal>'] = rule_exact_numeric_literal_
	rules['<exact numeric type: #1>'] = rule_exact_numeric_type__1_
	rules['<exact numeric type: #2>'] = rule_exact_numeric_type__2_
	rules['<exact numeric type: #3>'] = rule_exact_numeric_type__3_
	rules['<exact numeric type: #4>'] = rule_exact_numeric_type__4_
	rules['<exact numeric type>'] = rule_exact_numeric_type_
	rules['<explicit row value constructor: #1>'] = rule_explicit_row_value_constructor__1_
	rules['<explicit row value constructor: #2>'] = rule_explicit_row_value_constructor__2_
	rules['<explicit row value constructor>'] = rule_explicit_row_value_constructor_
	rules['<exponential function: #1>'] = rule_exponential_function__1_
	rules['<exponential function>'] = rule_exponential_function_
	rules['<factor: #2>'] = rule_factor__2_
	rules['<factor>'] = rule_factor_
	rules['<fetch first clause: #1>'] = rule_fetch_first_clause__1_
	rules['<fetch first clause>'] = rule_fetch_first_clause_
	rules['<fetch first quantity>'] = rule_fetch_first_quantity_
	rules['<fetch first row count>'] = rule_fetch_first_row_count_
	rules['<floor function: #1>'] = rule_floor_function__1_
	rules['<floor function>'] = rule_floor_function_
	rules['<fold: #1>'] = rule_fold__1_
	rules['<fold: #2>'] = rule_fold__2_
	rules['<fold>'] = rule_fold_
	rules['<from clause: #1>'] = rule_from_clause__1_
	rules['<from clause>'] = rule_from_clause_
	rules['<from constructor: #1>'] = rule_from_constructor__1_
	rules['<from constructor>'] = rule_from_constructor_
	rules['<general literal>'] = rule_general_literal_
	rules['<general set function: #1>'] = rule_general_set_function__1_
	rules['<general set function>'] = rule_general_set_function_
	rules['<general value specification: #2>'] = rule_general_value_specification__2_
	rules['<general value specification: #3>'] = rule_general_value_specification__3_
	rules['<general value specification>'] = rule_general_value_specification_
	rules['<greater than operator>'] = rule_greater_than_operator_
	rules['<greater than or equals operator>'] = rule_greater_than_or_equals_operator_
	rules['<group by clause: #1>'] = rule_group_by_clause__1_
	rules['<group by clause>'] = rule_group_by_clause_
	rules['<grouping column reference>'] = rule_grouping_column_reference_
	rules['<grouping element list: #1>'] = rule_grouping_element_list__1_
	rules['<grouping element list: #2>'] = rule_grouping_element_list__2_
	rules['<grouping element list>'] = rule_grouping_element_list_
	rules['<grouping element>'] = rule_grouping_element_
	rules['<host parameter name: #1>'] = rule_host_parameter_name__1_
	rules['<host parameter name>'] = rule_host_parameter_name_
	rules['<host parameter specification>'] = rule_host_parameter_specification_
	rules['<identifier body>'] = rule_identifier_body_
	rules['<identifier chain: #2>'] = rule_identifier_chain__2_
	rules['<identifier chain>'] = rule_identifier_chain_
	rules['<identifier start>'] = rule_identifier_start_
	rules['<identifier>'] = rule_identifier_
	rules['<implicitly typed value specification>'] = rule_implicitly_typed_value_specification_
	rules['<insert column list>'] = rule_insert_column_list_
	rules['<insert columns and source>'] = rule_insert_columns_and_source_
	rules['<insert statement: #1>'] = rule_insert_statement__1_
	rules['<insert statement>'] = rule_insert_statement_
	rules['<insertion target>'] = rule_insertion_target_
	rules['<is symmetric: #1>'] = rule_is_symmetric__1_
	rules['<is symmetric: #2>'] = rule_is_symmetric__2_
	rules['<is symmetric>'] = rule_is_symmetric_
	rules['<join condition: #1>'] = rule_join_condition__1_
	rules['<join condition>'] = rule_join_condition_
	rules['<join specification>'] = rule_join_specification_
	rules['<join type: #3>'] = rule_join_type__3_
	rules['<join type>'] = rule_join_type_
	rules['<joined table>'] = rule_joined_table_
	rules['<left paren>'] = rule_left_paren_
	rules['<length expression>'] = rule_length_expression_
	rules['<length>'] = rule_length_
	rules['<less than operator>'] = rule_less_than_operator_
	rules['<less than or equals operator>'] = rule_less_than_or_equals_operator_
	rules['<like predicate>'] = rule_like_predicate_
	rules['<literal>'] = rule_literal_
	rules['<local or schema qualified name: #2>'] = rule_local_or_schema_qualified_name__2_
	rules['<local or schema qualified name>'] = rule_local_or_schema_qualified_name_
	rules['<local or schema qualifier>'] = rule_local_or_schema_qualifier_
	rules['<minus sign>'] = rule_minus_sign_
	rules['<modulus expression: #1>'] = rule_modulus_expression__1_
	rules['<modulus expression>'] = rule_modulus_expression_
	rules['<natural logarithm: #1>'] = rule_natural_logarithm__1_
	rules['<natural logarithm>'] = rule_natural_logarithm_
	rules['<next value expression: #1>'] = rule_next_value_expression__1_
	rules['<next value expression>'] = rule_next_value_expression_
	rules['<non-reserved word>'] = rule_non_reserved_word_
	rules['<nonparenthesized value expression primary: #1>'] = rule_nonparenthesized_value_expression_primary__1_
	rules['<nonparenthesized value expression primary: #2>'] = rule_nonparenthesized_value_expression_primary__2_
	rules['<nonparenthesized value expression primary: #3>'] = rule_nonparenthesized_value_expression_primary__3_
	rules['<nonparenthesized value expression primary: #4>'] = rule_nonparenthesized_value_expression_primary__4_
	rules['<nonparenthesized value expression primary: #5>'] = rule_nonparenthesized_value_expression_primary__5_
	rules['<nonparenthesized value expression primary: #6>'] = rule_nonparenthesized_value_expression_primary__6_
	rules['<nonparenthesized value expression primary: #7>'] = rule_nonparenthesized_value_expression_primary__7_
	rules['<nonparenthesized value expression primary>'] = rule_nonparenthesized_value_expression_primary_
	rules['<not equals operator>'] = rule_not_equals_operator_
	rules['<null predicate part 2: #1>'] = rule_null_predicate_part_2__1_
	rules['<null predicate part 2: #2>'] = rule_null_predicate_part_2__2_
	rules['<null predicate part 2>'] = rule_null_predicate_part_2_
	rules['<null predicate: #1>'] = rule_null_predicate__1_
	rules['<null predicate>'] = rule_null_predicate_
	rules['<null specification: #1>'] = rule_null_specification__1_
	rules['<null specification>'] = rule_null_specification_
	rules['<numeric primary: #1>'] = rule_numeric_primary__1_
	rules['<numeric primary: #2>'] = rule_numeric_primary__2_
	rules['<numeric primary>'] = rule_numeric_primary_
	rules['<numeric type>'] = rule_numeric_type_
	rules['<numeric value expression base>'] = rule_numeric_value_expression_base_
	rules['<numeric value expression dividend>'] = rule_numeric_value_expression_dividend_
	rules['<numeric value expression divisor>'] = rule_numeric_value_expression_divisor_
	rules['<numeric value expression exponent>'] = rule_numeric_value_expression_exponent_
	rules['<numeric value expression: #1>'] = rule_numeric_value_expression__1_
	rules['<numeric value expression: #2>'] = rule_numeric_value_expression__2_
	rules['<numeric value expression: #3>'] = rule_numeric_value_expression__3_
	rules['<numeric value expression>'] = rule_numeric_value_expression_
	rules['<numeric value function>'] = rule_numeric_value_function_
	rules['<object column>'] = rule_object_column_
	rules['<octet length expression: #1>'] = rule_octet_length_expression__1_
	rules['<octet length expression>'] = rule_octet_length_expression_
	rules['<offset row count>'] = rule_offset_row_count_
	rules['<order by clause: #1>'] = rule_order_by_clause__1_
	rules['<order by clause>'] = rule_order_by_clause_
	rules['<ordering specification: #1>'] = rule_ordering_specification__1_
	rules['<ordering specification: #2>'] = rule_ordering_specification__2_
	rules['<ordering specification>'] = rule_ordering_specification_
	rules['<ordinary grouping set>'] = rule_ordinary_grouping_set_
	rules['<outer join type>'] = rule_outer_join_type_
	rules['<parenthesized boolean value expression: #1>'] = rule_parenthesized_boolean_value_expression__1_
	rules['<parenthesized boolean value expression>'] = rule_parenthesized_boolean_value_expression_
	rules['<parenthesized derived column list: #1>'] = rule_parenthesized_derived_column_list__1_
	rules['<parenthesized derived column list>'] = rule_parenthesized_derived_column_list_
	rules['<parenthesized value expression: #1>'] = rule_parenthesized_value_expression__1_
	rules['<parenthesized value expression>'] = rule_parenthesized_value_expression_
	rules['<period>'] = rule_period_
	rules['<plus sign>'] = rule_plus_sign_
	rules['<position expression>'] = rule_position_expression_
	rules['<power function: #1>'] = rule_power_function__1_
	rules['<power function>'] = rule_power_function_
	rules['<precision>'] = rule_precision_
	rules['<predefined type>'] = rule_predefined_type_
	rules['<predicate: #1>'] = rule_predicate__1_
	rules['<predicate: #2>'] = rule_predicate__2_
	rules['<predicate: #3>'] = rule_predicate__3_
	rules['<predicate: #4>'] = rule_predicate__4_
	rules['<predicate: #5>'] = rule_predicate__5_
	rules['<predicate>'] = rule_predicate_
	rules['<preparable SQL data statement>'] = rule_preparable_sql_data_statement_
	rules['<preparable SQL schema statement>'] = rule_preparable_sql_schema_statement_
	rules['<preparable SQL session statement>'] = rule_preparable_sql_session_statement_
	rules['<preparable SQL transaction statement>'] = rule_preparable_sql_transaction_statement_
	rules['<preparable statement>'] = rule_preparable_statement_
	rules['<qualified asterisk: #1>'] = rule_qualified_asterisk__1_
	rules['<qualified asterisk>'] = rule_qualified_asterisk_
	rules['<qualified identifier>'] = rule_qualified_identifier_
	rules['<qualified join: #1>'] = rule_qualified_join__1_
	rules['<qualified join: #2>'] = rule_qualified_join__2_
	rules['<qualified join>'] = rule_qualified_join_
	rules['<query expression body>'] = rule_query_expression_body_
	rules['<query expression: #1>'] = rule_query_expression__1_
	rules['<query expression: #2>'] = rule_query_expression__2_
	rules['<query expression: #3>'] = rule_query_expression__3_
	rules['<query expression: #4>'] = rule_query_expression__4_
	rules['<query expression: #5>'] = rule_query_expression__5_
	rules['<query expression: #6>'] = rule_query_expression__6_
	rules['<query expression: #7>'] = rule_query_expression__7_
	rules['<query expression: #8>'] = rule_query_expression__8_
	rules['<query expression>'] = rule_query_expression_
	rules['<query primary>'] = rule_query_primary_
	rules['<query specification: #1>'] = rule_query_specification__1_
	rules['<query specification>'] = rule_query_specification_
	rules['<query term>'] = rule_query_term_
	rules['<regular identifier: #2>'] = rule_regular_identifier__2_
	rules['<regular identifier>'] = rule_regular_identifier_
	rules['<result offset clause: #1>'] = rule_result_offset_clause__1_
	rules['<result offset clause>'] = rule_result_offset_clause_
	rules['<right paren>'] = rule_right_paren_
	rules['<rollback statement: #1>'] = rule_rollback_statement__1_
	rules['<rollback statement: #2>'] = rule_rollback_statement__2_
	rules['<rollback statement>'] = rule_rollback_statement_
	rules['<routine invocation: #1>'] = rule_routine_invocation__1_
	rules['<routine invocation>'] = rule_routine_invocation_
	rules['<routine name: #1>'] = rule_routine_name__1_
	rules['<routine name>'] = rule_routine_name_
	rules['<row or rows>'] = rule_row_or_rows_
	rules['<row subquery>'] = rule_row_subquery_
	rules['<row value constructor element list: #1>'] = rule_row_value_constructor_element_list__1_
	rules['<row value constructor element list: #2>'] = rule_row_value_constructor_element_list__2_
	rules['<row value constructor element list>'] = rule_row_value_constructor_element_list_
	rules['<row value constructor element>'] = rule_row_value_constructor_element_
	rules['<row value constructor predicand: #1>'] = rule_row_value_constructor_predicand__1_
	rules['<row value constructor predicand: #2>'] = rule_row_value_constructor_predicand__2_
	rules['<row value constructor predicand>'] = rule_row_value_constructor_predicand_
	rules['<row value constructor: #1>'] = rule_row_value_constructor__1_
	rules['<row value constructor: #2>'] = rule_row_value_constructor__2_
	rules['<row value constructor: #3>'] = rule_row_value_constructor__3_
	rules['<row value constructor>'] = rule_row_value_constructor_
	rules['<row value expression list: #1>'] = rule_row_value_expression_list__1_
	rules['<row value expression list: #2>'] = rule_row_value_expression_list__2_
	rules['<row value expression list>'] = rule_row_value_expression_list_
	rules['<row value predicand>'] = rule_row_value_predicand_
	rules['<schema definition: #1>'] = rule_schema_definition__1_
	rules['<schema definition>'] = rule_schema_definition_
	rules['<schema name characteristic: #1>'] = rule_schema_name_characteristic__1_
	rules['<schema name characteristic>'] = rule_schema_name_characteristic_
	rules['<schema name clause>'] = rule_schema_name_clause_
	rules['<schema name: #1>'] = rule_schema_name__1_
	rules['<schema name>'] = rule_schema_name_
	rules['<schema qualified name: #2>'] = rule_schema_qualified_name__2_
	rules['<schema qualified name>'] = rule_schema_qualified_name_
	rules['<search condition>'] = rule_search_condition_
	rules['<select list: #1>'] = rule_select_list__1_
	rules['<select list: #3>'] = rule_select_list__3_
	rules['<select list>'] = rule_select_list_
	rules['<select sublist: #1>'] = rule_select_sublist__1_
	rules['<select sublist: #2>'] = rule_select_sublist__2_
	rules['<select sublist>'] = rule_select_sublist_
	rules['<sequence generator cycle option: #1>'] = rule_sequence_generator_cycle_option__1_
	rules['<sequence generator cycle option: #2>'] = rule_sequence_generator_cycle_option__2_
	rules['<sequence generator cycle option>'] = rule_sequence_generator_cycle_option_
	rules['<sequence generator definition: #1>'] = rule_sequence_generator_definition__1_
	rules['<sequence generator definition: #2>'] = rule_sequence_generator_definition__2_
	rules['<sequence generator definition>'] = rule_sequence_generator_definition_
	rules['<sequence generator increment by option: #1>'] = rule_sequence_generator_increment_by_option__1_
	rules['<sequence generator increment by option>'] = rule_sequence_generator_increment_by_option_
	rules['<sequence generator increment>'] = rule_sequence_generator_increment_
	rules['<sequence generator max value>'] = rule_sequence_generator_max_value_
	rules['<sequence generator maxvalue option: #1>'] = rule_sequence_generator_maxvalue_option__1_
	rules['<sequence generator maxvalue option: #2>'] = rule_sequence_generator_maxvalue_option__2_
	rules['<sequence generator maxvalue option>'] = rule_sequence_generator_maxvalue_option_
	rules['<sequence generator min value>'] = rule_sequence_generator_min_value_
	rules['<sequence generator minvalue option: #1>'] = rule_sequence_generator_minvalue_option__1_
	rules['<sequence generator minvalue option: #2>'] = rule_sequence_generator_minvalue_option__2_
	rules['<sequence generator minvalue option>'] = rule_sequence_generator_minvalue_option_
	rules['<sequence generator name: #1>'] = rule_sequence_generator_name__1_
	rules['<sequence generator name>'] = rule_sequence_generator_name_
	rules['<sequence generator option>'] = rule_sequence_generator_option_
	rules['<sequence generator options>'] = rule_sequence_generator_options_
	rules['<sequence generator restart value>'] = rule_sequence_generator_restart_value_
	rules['<sequence generator start value>'] = rule_sequence_generator_start_value_
	rules['<sequence generator start with option: #1>'] = rule_sequence_generator_start_with_option__1_
	rules['<sequence generator start with option>'] = rule_sequence_generator_start_with_option_
	rules['<set catalog statement: #1>'] = rule_set_catalog_statement__1_
	rules['<set catalog statement>'] = rule_set_catalog_statement_
	rules['<set clause list: #2>'] = rule_set_clause_list__2_
	rules['<set clause list>'] = rule_set_clause_list_
	rules['<set clause: #1>'] = rule_set_clause__1_
	rules['<set clause>'] = rule_set_clause_
	rules['<set function specification>'] = rule_set_function_specification_
	rules['<set function type>'] = rule_set_function_type_
	rules['<set schema statement: #1>'] = rule_set_schema_statement__1_
	rules['<set schema statement>'] = rule_set_schema_statement_
	rules['<set target>'] = rule_set_target_
	rules['<sign>'] = rule_sign_
	rules['<signed numeric literal: #2>'] = rule_signed_numeric_literal__2_
	rules['<signed numeric literal>'] = rule_signed_numeric_literal_
	rules['<similar pattern>'] = rule_similar_pattern_
	rules['<similar predicate part 2: #1>'] = rule_similar_predicate_part_2__1_
	rules['<similar predicate part 2: #2>'] = rule_similar_predicate_part_2__2_
	rules['<similar predicate part 2>'] = rule_similar_predicate_part_2_
	rules['<similar predicate: #1>'] = rule_similar_predicate__1_
	rules['<similar predicate>'] = rule_similar_predicate_
	rules['<simple table>'] = rule_simple_table_
	rules['<simple value specification: #1>'] = rule_simple_value_specification__1_
	rules['<simple value specification: #2>'] = rule_simple_value_specification__2_
	rules['<simple value specification>'] = rule_simple_value_specification_
	rules['<solidus>'] = rule_solidus_
	rules['<sort key>'] = rule_sort_key_
	rules['<sort specification list: #1>'] = rule_sort_specification_list__1_
	rules['<sort specification list: #2>'] = rule_sort_specification_list__2_
	rules['<sort specification list>'] = rule_sort_specification_list_
	rules['<sort specification: #1>'] = rule_sort_specification__1_
	rules['<sort specification: #2>'] = rule_sort_specification__2_
	rules['<sort specification>'] = rule_sort_specification_
	rules['<SQL argument list: #1>'] = rule_sql_argument_list__1_
	rules['<SQL argument list: #2>'] = rule_sql_argument_list__2_
	rules['<SQL argument list: #3>'] = rule_sql_argument_list__3_
	rules['<SQL argument list>'] = rule_sql_argument_list_
	rules['<SQL argument>'] = rule_sql_argument_
	rules['<SQL schema definition statement>'] = rule_sql_schema_definition_statement_
	rules['<SQL schema manipulation statement: #3>'] = rule_sql_schema_manipulation_statement__3_
	rules['<SQL schema manipulation statement>'] = rule_sql_schema_manipulation_statement_
	rules['<SQL schema statement>'] = rule_sql_schema_statement_
	rules['<SQL session statement>'] = rule_sql_session_statement_
	rules['<SQL transaction statement>'] = rule_sql_transaction_statement_
	rules['<square root: #1>'] = rule_square_root__1_
	rules['<square root>'] = rule_square_root_
	rules['<start position>'] = rule_start_position_
	rules['<start transaction statement: #1>'] = rule_start_transaction_statement__1_
	rules['<start transaction statement>'] = rule_start_transaction_statement_
	rules['<string length>'] = rule_string_length_
	rules['<string value expression>'] = rule_string_value_expression_
	rules['<string value function>'] = rule_string_value_function_
	rules['<subquery: #1>'] = rule_subquery__1_
	rules['<subquery>'] = rule_subquery_
	rules['<table constraint definition>'] = rule_table_constraint_definition_
	rules['<table constraint>'] = rule_table_constraint_
	rules['<table contents source>'] = rule_table_contents_source_
	rules['<table definition: #1>'] = rule_table_definition__1_
	rules['<table definition>'] = rule_table_definition_
	rules['<table element list: #1>'] = rule_table_element_list__1_
	rules['<table element list>'] = rule_table_element_list_
	rules['<table element>'] = rule_table_element_
	rules['<table elements: #1>'] = rule_table_elements__1_
	rules['<table elements: #2>'] = rule_table_elements__2_
	rules['<table elements>'] = rule_table_elements_
	rules['<table expression: #1>'] = rule_table_expression__1_
	rules['<table expression: #2>'] = rule_table_expression__2_
	rules['<table expression: #3>'] = rule_table_expression__3_
	rules['<table expression: #4>'] = rule_table_expression__4_
	rules['<table expression>'] = rule_table_expression_
	rules['<table factor>'] = rule_table_factor_
	rules['<table name: #1>'] = rule_table_name__1_
	rules['<table name>'] = rule_table_name_
	rules['<table or query name>'] = rule_table_or_query_name_
	rules['<table primary: #1>'] = rule_table_primary__1_
	rules['<table primary: #3>'] = rule_table_primary__3_
	rules['<table primary>'] = rule_table_primary_
	rules['<table reference list>'] = rule_table_reference_list_
	rules['<table reference: #1>'] = rule_table_reference__1_
	rules['<table reference: #2>'] = rule_table_reference__2_
	rules['<table reference>'] = rule_table_reference_
	rules['<table row value expression>'] = rule_table_row_value_expression_
	rules['<table subquery>'] = rule_table_subquery_
	rules['<table value constructor: #1>'] = rule_table_value_constructor__1_
	rules['<table value constructor>'] = rule_table_value_constructor_
	rules['<target table>'] = rule_target_table_
	rules['<term: #1>'] = rule_term__1_
	rules['<term: #2>'] = rule_term__2_
	rules['<term: #3>'] = rule_term__3_
	rules['<term>'] = rule_term_
	rules['<time fractional seconds precision>'] = rule_time_fractional_seconds_precision_
	rules['<time literal: #1>'] = rule_time_literal__1_
	rules['<time literal>'] = rule_time_literal_
	rules['<time precision>'] = rule_time_precision_
	rules['<time string>'] = rule_time_string_
	rules['<timestamp literal: #1>'] = rule_timestamp_literal__1_
	rules['<timestamp literal>'] = rule_timestamp_literal_
	rules['<timestamp precision>'] = rule_timestamp_precision_
	rules['<timestamp string>'] = rule_timestamp_string_
	rules['<trigonometric function name>'] = rule_trigonometric_function_name_
	rules['<trigonometric function: #1>'] = rule_trigonometric_function__1_
	rules['<trigonometric function>'] = rule_trigonometric_function_
	rules['<trim character>'] = rule_trim_character_
	rules['<trim function: #1>'] = rule_trim_function__1_
	rules['<trim function>'] = rule_trim_function_
	rules['<trim operands: #1>'] = rule_trim_operands__1_
	rules['<trim operands: #2>'] = rule_trim_operands__2_
	rules['<trim operands: #3>'] = rule_trim_operands__3_
	rules['<trim operands: #4>'] = rule_trim_operands__4_
	rules['<trim operands: #5>'] = rule_trim_operands__5_
	rules['<trim operands>'] = rule_trim_operands_
	rules['<trim source>'] = rule_trim_source_
	rules['<trim specification>'] = rule_trim_specification_
	rules['<truth value: #1>'] = rule_truth_value__1_
	rules['<truth value: #2>'] = rule_truth_value__2_
	rules['<truth value: #3>'] = rule_truth_value__3_
	rules['<truth value>'] = rule_truth_value_
	rules['<unique column list>'] = rule_unique_column_list_
	rules['<unique constraint definition: #1>'] = rule_unique_constraint_definition__1_
	rules['<unique constraint definition>'] = rule_unique_constraint_definition_
	rules['<unique specification: #1>'] = rule_unique_specification__1_
	rules['<unique specification>'] = rule_unique_specification_
	rules['<unqualified schema name: #1>'] = rule_unqualified_schema_name__1_
	rules['<unqualified schema name>'] = rule_unqualified_schema_name_
	rules['<unsigned integer>'] = rule_unsigned_integer_
	rules['<unsigned literal>'] = rule_unsigned_literal_
	rules['<unsigned numeric literal>'] = rule_unsigned_numeric_literal_
	rules['<unsigned value specification: #1>'] = rule_unsigned_value_specification__1_
	rules['<unsigned value specification: #2>'] = rule_unsigned_value_specification__2_
	rules['<unsigned value specification>'] = rule_unsigned_value_specification_
	rules['<update source: #1>'] = rule_update_source__1_
	rules['<update source: #2>'] = rule_update_source__2_
	rules['<update source>'] = rule_update_source_
	rules['<update statement: searched: #1>'] = rule_update_statement_searched__1_
	rules['<update statement: searched: #2>'] = rule_update_statement_searched__2_
	rules['<update statement: searched>'] = rule_update_statement_searched_
	rules['<update target>'] = rule_update_target_
	rules['<value expression list: #1>'] = rule_value_expression_list__1_
	rules['<value expression list: #2>'] = rule_value_expression_list__2_
	rules['<value expression list>'] = rule_value_expression_list_
	rules['<value expression primary: #1>'] = rule_value_expression_primary__1_
	rules['<value expression primary: #2>'] = rule_value_expression_primary__2_
	rules['<value expression primary>'] = rule_value_expression_primary_
	rules['<value expression: #1>'] = rule_value_expression__1_
	rules['<value expression: #2>'] = rule_value_expression__2_
	rules['<value expression>'] = rule_value_expression_
	rules['<value specification: #1>'] = rule_value_specification__1_
	rules['<value specification: #2>'] = rule_value_specification__2_
	rules['<value specification>'] = rule_value_specification_
	rules['<where clause: #1>'] = rule_where_clause__1_
	rules['<where clause>'] = rule_where_clause_
	rules['<with or without time zone: #1>'] = rule_with_or_without_time_zone__1_
	rules['<with or without time zone: #2>'] = rule_with_or_without_time_zone__2_
	rules['<with or without time zone>'] = rule_with_or_without_time_zone_
	rules['^identifier'] = rule__identifier
	rules['^integer'] = rule__integer
	rules['^string'] = rule__string
	rules['A'] = rule_a
	rules['ABS'] = rule_abs
	rules['ABSOLUTE'] = rule_absolute
	rules['ACOS'] = rule_acos
	rules['ACTION'] = rule_action
	rules['ADA'] = rule_ada
	rules['ADD'] = rule_add
	rules['ADMIN'] = rule_admin
	rules['AFTER'] = rule_after
	rules['ALTER'] = rule_alter
	rules['ALWAYS'] = rule_always
	rules['AND'] = rule_and
	rules['AS'] = rule_as
	rules['ASC'] = rule_asc
	rules['ASIN'] = rule_asin
	rules['ASSERTION'] = rule_assertion
	rules['ASSIGNMENT'] = rule_assignment
	rules['ASYMMETRIC'] = rule_asymmetric
	rules['ATAN'] = rule_atan
	rules['ATTRIBUTE'] = rule_attribute
	rules['ATTRIBUTES'] = rule_attributes
	rules['AVG'] = rule_avg
	rules['BEFORE'] = rule_before
	rules['BERNOULLI'] = rule_bernoulli
	rules['BETWEEN'] = rule_between
	rules['BIGINT'] = rule_bigint
	rules['BOOLEAN'] = rule_boolean
	rules['BOTH'] = rule_both
	rules['BREADTH'] = rule_breadth
	rules['BY'] = rule_by
	rules['C'] = rule_c
	rules['CASCADE'] = rule_cascade
	rules['CAST'] = rule_cast
	rules['CATALOG'] = rule_catalog
	rules['CATALOG_NAME'] = rule_catalog_name
	rules['CEIL'] = rule_ceil
	rules['CEILING'] = rule_ceiling
	rules['CHAIN'] = rule_chain
	rules['CHAINING'] = rule_chaining
	rules['CHAR'] = rule_char
	rules['CHAR_LENGTH'] = rule_char_length
	rules['CHARACTER'] = rule_character
	rules['CHARACTER_LENGTH'] = rule_character_length
	rules['CHARACTER_SET_CATALOG'] = rule_character_set_catalog
	rules['CHARACTER_SET_NAME'] = rule_character_set_name
	rules['CHARACTER_SET_SCHEMA'] = rule_character_set_schema
	rules['CHARACTERISTICS'] = rule_characteristics
	rules['CHARACTERS'] = rule_characters
	rules['CLASS_ORIGIN'] = rule_class_origin
	rules['COALESCE'] = rule_coalesce
	rules['COBOL'] = rule_cobol
	rules['COLLATION'] = rule_collation
	rules['COLLATION_CATALOG'] = rule_collation_catalog
	rules['COLLATION_NAME'] = rule_collation_name
	rules['COLLATION_SCHEMA'] = rule_collation_schema
	rules['COLUMN_NAME'] = rule_column_name
	rules['COLUMNS'] = rule_columns
	rules['COMMAND_FUNCTION'] = rule_command_function
	rules['COMMAND_FUNCTION_CODE'] = rule_command_function_code
	rules['COMMIT'] = rule_commit
	rules['COMMITTED'] = rule_committed
	rules['CONDITION_NUMBER'] = rule_condition_number
	rules['CONDITIONAL'] = rule_conditional
	rules['CONNECTION'] = rule_connection
	rules['CONNECTION_NAME'] = rule_connection_name
	rules['CONSTRAINT_CATALOG'] = rule_constraint_catalog
	rules['CONSTRAINT_NAME'] = rule_constraint_name
	rules['CONSTRAINT_SCHEMA'] = rule_constraint_schema
	rules['CONSTRAINTS'] = rule_constraints
	rules['CONSTRUCTOR'] = rule_constructor
	rules['CONTINUE'] = rule_continue
	rules['COS'] = rule_cos
	rules['COSH'] = rule_cosh
	rules['COUNT'] = rule_count
	rules['CREATE'] = rule_create
	rules['CURRENT_CATALOG'] = rule_current_catalog
	rules['CURRENT_DATE'] = rule_current_date
	rules['CURRENT_SCHEMA'] = rule_current_schema
	rules['CURRENT_TIME'] = rule_current_time
	rules['CURRENT_TIMESTAMP'] = rule_current_timestamp
	rules['CURSOR_NAME'] = rule_cursor_name
	rules['CYCLE'] = rule_cycle
	rules['DATA'] = rule_data
	rules['DATE'] = rule_date
	rules['DATETIME_INTERVAL_CODE'] = rule_datetime_interval_code
	rules['DATETIME_INTERVAL_PRECISION'] = rule_datetime_interval_precision
	rules['DEFAULTS'] = rule_defaults
	rules['DEFERRABLE'] = rule_deferrable
	rules['DEFERRED'] = rule_deferred
	rules['DEFINED'] = rule_defined
	rules['DEFINER'] = rule_definer
	rules['DEGREE'] = rule_degree
	rules['DELETE'] = rule_delete
	rules['DEPTH'] = rule_depth
	rules['DERIVED'] = rule_derived
	rules['DESC'] = rule_desc
	rules['DESCRIBE_CATALOG'] = rule_describe_catalog
	rules['DESCRIBE_NAME'] = rule_describe_name
	rules['DESCRIBE_PROCEDURE_SPECIFIC_CATALOG'] = rule_describe_procedure_specific_catalog
	rules['DESCRIBE_PROCEDURE_SPECIFIC_NAME'] = rule_describe_procedure_specific_name
	rules['DESCRIBE_PROCEDURE_SPECIFIC_SCHEMA'] = rule_describe_procedure_specific_schema
	rules['DESCRIBE_SCHEMA'] = rule_describe_schema
	rules['DESCRIPTOR'] = rule_descriptor
	rules['DIAGNOSTICS'] = rule_diagnostics
	rules['DISPATCH'] = rule_dispatch
	rules['DOMAIN'] = rule_domain
	rules['DOUBLE'] = rule_double
	rules['DROP'] = rule_drop
	rules['DYNAMIC_FUNCTION'] = rule_dynamic_function
	rules['DYNAMIC_FUNCTION_CODE'] = rule_dynamic_function_code
	rules['ENCODING'] = rule_encoding
	rules['ENFORCED'] = rule_enforced
	rules['ERROR'] = rule_error
	rules['EXCLUDE'] = rule_exclude
	rules['EXCLUDING'] = rule_excluding
	rules['EXP'] = rule_exp
	rules['EXPRESSION'] = rule_expression
	rules['FALSE'] = rule_false
	rules['FETCH'] = rule_fetch
	rules['FINAL'] = rule_final
	rules['FINISH'] = rule_finish
	rules['FINISH_CATALOG'] = rule_finish_catalog
	rules['FINISH_NAME'] = rule_finish_name
	rules['FINISH_PROCEDURE_SPECIFIC_CATALOG'] = rule_finish_procedure_specific_catalog
	rules['FINISH_PROCEDURE_SPECIFIC_NAME'] = rule_finish_procedure_specific_name
	rules['FINISH_PROCEDURE_SPECIFIC_SCHEMA'] = rule_finish_procedure_specific_schema
	rules['FINISH_SCHEMA'] = rule_finish_schema
	rules['FIRST'] = rule_first
	rules['FLAG'] = rule_flag
	rules['FLOAT'] = rule_float
	rules['FLOOR'] = rule_floor
	rules['FOLLOWING'] = rule_following
	rules['FOR'] = rule_for
	rules['FORMAT'] = rule_format
	rules['FORTRAN'] = rule_fortran
	rules['FOUND'] = rule_found
	rules['FROM'] = rule_from
	rules['FULFILL'] = rule_fulfill
	rules['FULFILL_CATALOG'] = rule_fulfill_catalog
	rules['FULFILL_NAME'] = rule_fulfill_name
	rules['FULFILL_PROCEDURE_SPECIFIC_CATALOG'] = rule_fulfill_procedure_specific_catalog
	rules['FULFILL_PROCEDURE_SPECIFIC_NAME'] = rule_fulfill_procedure_specific_name
	rules['FULFILL_PROCEDURE_SPECIFIC_SCHEMA'] = rule_fulfill_procedure_specific_schema
	rules['FULFILL_SCHEMA'] = rule_fulfill_schema
	rules['G'] = rule_g
	rules['GENERAL'] = rule_general
	rules['GENERATED'] = rule_generated
	rules['GO'] = rule_go
	rules['GOTO'] = rule_goto
	rules['GRANTED'] = rule_granted
	rules['GROUP'] = rule_group
	rules['HAS_PASS_THROUGH_COLUMNS'] = rule_has_pass_through_columns
	rules['HAS_PASS_THRU_COLS'] = rule_has_pass_thru_cols
	rules['HIERARCHY'] = rule_hierarchy
	rules['IGNORE'] = rule_ignore
	rules['IMMEDIATE'] = rule_immediate
	rules['IMMEDIATELY'] = rule_immediately
	rules['IMPLEMENTATION'] = rule_implementation
	rules['IN'] = rule_in
	rules['INCLUDING'] = rule_including
	rules['INCREMENT'] = rule_increment
	rules['INITIALLY'] = rule_initially
	rules['INNER'] = rule_inner
	rules['INPUT'] = rule_input
	rules['INSERT'] = rule_insert
	rules['INSTANCE'] = rule_instance
	rules['INSTANTIABLE'] = rule_instantiable
	rules['INSTEAD'] = rule_instead
	rules['INT'] = rule_int
	rules['INTEGER'] = rule_integer
	rules['INTO'] = rule_into
	rules['INVOKER'] = rule_invoker
	rules['IS'] = rule_is
	rules['IS_PRUNABLE'] = rule_is_prunable
	rules['ISOLATION'] = rule_isolation
	rules['JOIN'] = rule_join
	rules['JSON'] = rule_json
	rules['K'] = rule_k
	rules['KEEP'] = rule_keep
	rules['KEY'] = rule_key
	rules['KEY_MEMBER'] = rule_key_member
	rules['KEY_TYPE'] = rule_key_type
	rules['KEYS'] = rule_keys
	rules['LAST'] = rule_last
	rules['LEADING'] = rule_leading
	rules['LEFT'] = rule_left
	rules['LENGTH'] = rule_length
	rules['LEVEL'] = rule_level
	rules['LIKE'] = rule_like
	rules['LN'] = rule_ln
	rules['LOCALTIME'] = rule_localtime
	rules['LOCALTIMESTAMP'] = rule_localtimestamp
	rules['LOCATOR'] = rule_locator
	rules['LOG10'] = rule_log10
	rules['LOWER'] = rule_lower
	rules['M'] = rule_m
	rules['MAP'] = rule_map
	rules['MATCHED'] = rule_matched
	rules['MAX'] = rule_max
	rules['MAXVALUE'] = rule_maxvalue
	rules['MESSAGE_LENGTH'] = rule_message_length
	rules['MESSAGE_OCTET_LENGTH'] = rule_message_octet_length
	rules['MESSAGE_TEXT'] = rule_message_text
	rules['MIN'] = rule_min
	rules['MINVALUE'] = rule_minvalue
	rules['MOD'] = rule_mod
	rules['MORE'] = rule_more
	rules['MUMPS'] = rule_mumps
	rules['NAME'] = rule_name
	rules['NAMES'] = rule_names
	rules['NESTED'] = rule_nested
	rules['NESTING'] = rule_nesting
	rules['NEXT'] = rule_next
	rules['NFC'] = rule_nfc
	rules['NFD'] = rule_nfd
	rules['NFKC'] = rule_nfkc
	rules['NFKD'] = rule_nfkd
	rules['NO'] = rule_no
	rules['NORMALIZED'] = rule_normalized
	rules['NOT'] = rule_not
	rules['NULL'] = rule_null
	rules['NULLABLE'] = rule_nullable
	rules['NULLIF'] = rule_nullif
	rules['NULLS'] = rule_nulls
	rules['NUMBER'] = rule_number
	rules['OBJECT'] = rule_object
	rules['OCTET_LENGTH'] = rule_octet_length
	rules['OCTETS'] = rule_octets
	rules['OFFSET'] = rule_offset
	rules['ON'] = rule_on
	rules['ONLY'] = rule_only
	rules['OPTION'] = rule_option
	rules['OPTIONS'] = rule_options
	rules['OR'] = rule_or
	rules['ORDER'] = rule_order
	rules['ORDERING'] = rule_ordering
	rules['ORDINALITY'] = rule_ordinality
	rules['OTHERS'] = rule_others
	rules['OUTER'] = rule_outer
	rules['OUTPUT'] = rule_output
	rules['OVERFLOW'] = rule_overflow
	rules['OVERRIDING'] = rule_overriding
	rules['P'] = rule_p
	rules['PAD'] = rule_pad
	rules['PARAMETER_MODE'] = rule_parameter_mode
	rules['PARAMETER_NAME'] = rule_parameter_name
	rules['PARAMETER_ORDINAL_POSITION'] = rule_parameter_ordinal_position
	rules['PARAMETER_SPECIFIC_CATALOG'] = rule_parameter_specific_catalog
	rules['PARAMETER_SPECIFIC_NAME'] = rule_parameter_specific_name
	rules['PARAMETER_SPECIFIC_SCHEMA'] = rule_parameter_specific_schema
	rules['PARTIAL'] = rule_partial
	rules['PASCAL'] = rule_pascal
	rules['PASS'] = rule_pass
	rules['PASSING'] = rule_passing
	rules['PAST'] = rule_past
	rules['PATH'] = rule_path
	rules['PLACING'] = rule_placing
	rules['PLAN'] = rule_plan
	rules['PLI'] = rule_pli
	rules['POSITION'] = rule_position
	rules['POWER'] = rule_power
	rules['PRECEDING'] = rule_preceding
	rules['PRECISION'] = rule_precision
	rules['PRESERVE'] = rule_preserve
	rules['PRIMARY'] = rule_primary
	rules['PRIOR'] = rule_prior
	rules['PRIVATE'] = rule_private
	rules['PRIVATE_PARAMETERS'] = rule_private_parameters
	rules['PRIVATE_PARAMS_S'] = rule_private_params_s
	rules['PRIVILEGES'] = rule_privileges
	rules['PRUNE'] = rule_prune
	rules['PUBLIC'] = rule_public
	rules['QUOTES'] = rule_quotes
	rules['READ'] = rule_read
	rules['REAL'] = rule_real
	rules['RELATIVE'] = rule_relative
	rules['REPEATABLE'] = rule_repeatable
	rules['RESPECT'] = rule_respect
	rules['RESTART'] = rule_restart
	rules['RESTRICT'] = rule_restrict
	rules['RET_ONLY_PASS_THRU'] = rule_ret_only_pass_thru
	rules['RETURNED_CARDINALITY'] = rule_returned_cardinality
	rules['RETURNED_LENGTH'] = rule_returned_length
	rules['RETURNED_OCTET_LENGTH'] = rule_returned_octet_length
	rules['RETURNED_SQLSTATE'] = rule_returned_sqlstate
	rules['RETURNING'] = rule_returning
	rules['RETURNS_ONLY_PASS_THROUGH'] = rule_returns_only_pass_through
	rules['RIGHT'] = rule_right
	rules['ROLE'] = rule_role
	rules['ROLLBACK'] = rule_rollback
	rules['ROUTINE'] = rule_routine
	rules['ROUTINE_CATALOG'] = rule_routine_catalog
	rules['ROUTINE_NAME'] = rule_routine_name
	rules['ROUTINE_SCHEMA'] = rule_routine_schema
	rules['ROW'] = rule_row
	rules['ROW_COUNT'] = rule_row_count
	rules['ROWS'] = rule_rows
	rules['SCALAR'] = rule_scalar
	rules['SCALE'] = rule_scale
	rules['SCHEMA'] = rule_schema
	rules['SCHEMA_NAME'] = rule_schema_name
	rules['SCOPE_CATALOG'] = rule_scope_catalog
	rules['SCOPE_NAME'] = rule_scope_name
	rules['SCOPE_SCHEMA'] = rule_scope_schema
	rules['SECTION'] = rule_section
	rules['SECURITY'] = rule_security
	rules['SELECT'] = rule_select
	rules['SELF'] = rule_self
	rules['SEQUENCE'] = rule_sequence
	rules['SERIALIZABLE'] = rule_serializable
	rules['SERVER_NAME'] = rule_server_name
	rules['SESSION'] = rule_session
	rules['SET'] = rule_set
	rules['SETS'] = rule_sets
	rules['SIMILAR'] = rule_similar
	rules['SIMPLE'] = rule_simple
	rules['SIN'] = rule_sin
	rules['SINH'] = rule_sinh
	rules['SIZE'] = rule_size
	rules['SMALLINT'] = rule_smallint
	rules['SOURCE'] = rule_source
	rules['SPACE'] = rule_space
	rules['SPECIFIC_NAME'] = rule_specific_name
	rules['SQRT'] = rule_sqrt
	rules['START'] = rule_start
	rules['START_CATALOG'] = rule_start_catalog
	rules['START_NAME'] = rule_start_name
	rules['START_PROCEDURE_SPECIFIC_CATALOG'] = rule_start_procedure_specific_catalog
	rules['START_PROCEDURE_SPECIFIC_NAME'] = rule_start_procedure_specific_name
	rules['START_PROCEDURE_SPECIFIC_SCHEMA'] = rule_start_procedure_specific_schema
	rules['START_SCHEMA'] = rule_start_schema
	rules['STATE'] = rule_state
	rules['STATEMENT'] = rule_statement
	rules['STRING'] = rule_string
	rules['STRUCTURE'] = rule_structure
	rules['STYLE'] = rule_style
	rules['SUBCLASS_ORIGIN'] = rule_subclass_origin
	rules['SUBSTRING'] = rule_substring
	rules['SUM'] = rule_sum
	rules['SYMMETRIC'] = rule_symmetric
	rules['T'] = rule_t
	rules['TABLE'] = rule_table
	rules['TABLE_NAME'] = rule_table_name
	rules['TABLE_SEMANTICS'] = rule_table_semantics
	rules['TAN'] = rule_tan
	rules['TANH'] = rule_tanh
	rules['TEMPORARY'] = rule_temporary
	rules['THROUGH'] = rule_through
	rules['TIES'] = rule_ties
	rules['TIME'] = rule_time
	rules['TIMESTAMP'] = rule_timestamp
	rules['TO'] = rule_to
	rules['TOP_LEVEL_COUNT'] = rule_top_level_count
	rules['TRAILING'] = rule_trailing
	rules['TRANSACTION'] = rule_transaction
	rules['TRANSACTION_ACTIVE'] = rule_transaction_active
	rules['TRANSACTIONS_COMMITTED'] = rule_transactions_committed
	rules['TRANSACTIONS_ROLLED_BACK'] = rule_transactions_rolled_back
	rules['TRANSFORM'] = rule_transform
	rules['TRANSFORMS'] = rule_transforms
	rules['TRIGGER_CATALOG'] = rule_trigger_catalog
	rules['TRIGGER_NAME'] = rule_trigger_name
	rules['TRIGGER_SCHEMA'] = rule_trigger_schema
	rules['TRIM'] = rule_trim
	rules['TRUE'] = rule_true
	rules['TYPE'] = rule_type
	rules['UNBOUNDED'] = rule_unbounded
	rules['UNCOMMITTED'] = rule_uncommitted
	rules['UNCONDITIONAL'] = rule_unconditional
	rules['UNDER'] = rule_under
	rules['UNKNOWN'] = rule_unknown
	rules['UNNAMED'] = rule_unnamed
	rules['UPDATE'] = rule_update
	rules['UPPER'] = rule_upper
	rules['USAGE'] = rule_usage
	rules['USER_DEFINED_TYPE_CATALOG'] = rule_user_defined_type_catalog
	rules['USER_DEFINED_TYPE_CODE'] = rule_user_defined_type_code
	rules['USER_DEFINED_TYPE_NAME'] = rule_user_defined_type_name
	rules['USER_DEFINED_TYPE_SCHEMA'] = rule_user_defined_type_schema
	rules['USING'] = rule_using
	rules['UTF16'] = rule_utf16
	rules['UTF32'] = rule_utf32
	rules['UTF8'] = rule_utf8
	rules['VALUE'] = rule_value
	rules['VALUES'] = rule_values
	rules['VARCHAR'] = rule_varchar
	rules['VARYING'] = rule_varying
	rules['VIEW'] = rule_view
	rules['WHERE'] = rule_where
	rules['WITH'] = rule_with
	rules['WITHOUT'] = rule_without
	rules['WORK'] = rule_work
	rules['WRAPPER'] = rule_wrapper
	rules['WRITE'] = rule_write
	rules['ZONE'] = rule_zone

	return rules
}

fn parse_ast(node &EarleyNode) ![]EarleyValue {
	if node.children.len == 0 {
		match node.value.name {
			'^integer' {
				return [EarleyValue(node.value.end_column.value)]
			}
			'^identifier' {
				return [EarleyValue(IdentifierChain{node.value.end_column.value})]
			}
			'^string' {
				// See ISO/IEC 9075-2:2016(E), "5.3 <literal>", #17
				return [EarleyValue(new_character_value(node.value.end_column.value))]
			}
			else {
				if node.value.name[0] == `<` {
					return [EarleyValue(node.value.end_column.value)]
				}

				if node.value.name.is_upper() {
					return [EarleyValue(node.value.name)]
				}

				panic(node.value.name)
				return []EarleyValue{}
			}
		}
	}

	mut children := []EarleyValue{}
	for child in node.children {
		for result in parse_ast(child)! {
			children << result
		}
	}

	return parse_ast_name(children, node.value.name)
}

fn parse_ast_name(children []EarleyValue, name string) ![]EarleyValue {
	match name {
		'<absolute value expression: #1>' {
			return [EarleyValue(parse_abs(children[2] as NumericValueExpression)!)]
		}
		'<aggregate function: #1>' {
			return [EarleyValue(parse_count_all(children[2] as string)!)]
		}
		'<alter sequence generator option: #1>' {
			return [
				EarleyValue(SequenceGeneratorOption(children[0] as SequenceGeneratorRestartOption)),
			]
		}
		'<alter sequence generator options: #1>' {
			return [
				EarleyValue(parse_sequence_generator_options_1(children[0] as SequenceGeneratorOption)!),
			]
		}
		'<alter sequence generator options: #2>' {
			return [
				EarleyValue(parse_sequence_generator_options_2(children[0] as []SequenceGeneratorOption,
					children[1] as SequenceGeneratorOption)!),
			]
		}
		'<alter sequence generator restart option: #1>' {
			return [EarleyValue(parse_sequence_generator_restart_option_1()!)]
		}
		'<alter sequence generator restart option: #2>' {
			return [
				EarleyValue(parse_sequence_generator_restart_option_2(children[2] as Value)!),
			]
		}
		'<alter sequence generator statement: #1>' {
			return [
				EarleyValue(parse_alter_sequence_generator_statement(children[2] as Identifier,
					children[3] as []SequenceGeneratorOption)!),
			]
		}
		'<approximate numeric type: #1>' {
			return [EarleyValue(parse_float()!)]
		}
		'<approximate numeric type: #2>' {
			return [EarleyValue(parse_float_n(children[2] as string)!)]
		}
		'<approximate numeric type: #3>' {
			return [EarleyValue(parse_real()!)]
		}
		'<approximate numeric type: #4>' {
			return [EarleyValue(parse_double_precision()!)]
		}
		'<as clause: #1>' {
			return [EarleyValue(parse_identifier(children[1] as Identifier)!)]
		}
		'<basic sequence generator option: #1>' {
			return [
				EarleyValue(SequenceGeneratorOption(children[0] as SequenceGeneratorIncrementByOption)),
			]
		}
		'<basic sequence generator option: #2>' {
			return [
				EarleyValue(SequenceGeneratorOption(children[0] as SequenceGeneratorMaxvalueOption)),
			]
		}
		'<basic sequence generator option: #3>' {
			return [
				EarleyValue(SequenceGeneratorOption(children[0] as SequenceGeneratorMinvalueOption)),
			]
		}
		'<basic sequence generator option: #4>' {
			return [
				EarleyValue(parse_basic_sequence_generator_option_4(children[0] as bool)!),
			]
		}
		'<between predicate part 1: #1>' {
			return [EarleyValue(parse_yes()!)]
		}
		'<between predicate part 1: #2>' {
			return [EarleyValue(parse_no()!)]
		}
		'<between predicate part 2: #1>' {
			return [
				EarleyValue(parse_between_1(children[0] as bool, children[1] as RowValueConstructorPredicand,
					children[3] as RowValueConstructorPredicand)!),
			]
		}
		'<between predicate part 2: #2>' {
			return [
				EarleyValue(parse_between_2(children[0] as bool, children[1] as bool,
					children[2] as RowValueConstructorPredicand, children[4] as RowValueConstructorPredicand)!),
			]
		}
		'<between predicate: #1>' {
			return [
				EarleyValue(parse_between(children[0] as RowValueConstructorPredicand,
					children[1] as BetweenPredicate)!),
			]
		}
		'<boolean factor: #2>' {
			return [
				EarleyValue(parse_boolean_factor_not(children[1] as BooleanTest)!),
			]
		}
		'<boolean literal: #1>' {
			return [EarleyValue(parse_true()!)]
		}
		'<boolean literal: #2>' {
			return [EarleyValue(parse_false()!)]
		}
		'<boolean literal: #3>' {
			return [EarleyValue(parse_unknown()!)]
		}
		'<boolean predicand: #1>' {
			return [
				EarleyValue(BooleanPredicand(children[0] as BooleanValueExpression)),
			]
		}
		'<boolean predicand: #2>' {
			return [
				EarleyValue(BooleanPredicand(children[0] as NonparenthesizedValueExpressionPrimary)),
			]
		}
		'<boolean primary: #1>' {
			return [EarleyValue(BooleanPrimary(children[0] as Predicate))]
		}
		'<boolean primary: #2>' {
			return [EarleyValue(BooleanPrimary(children[0] as BooleanPredicand))]
		}
		'<boolean term: #1>' {
			return [EarleyValue(parse_boolean_term_1(children[0] as BooleanTest)!)]
		}
		'<boolean term: #2>' {
			return [
				EarleyValue(parse_boolean_term_2(children[0] as BooleanTerm, children[2] as BooleanTest)!),
			]
		}
		'<boolean test: #1>' {
			return [
				EarleyValue(parse_boolean_test_1(children[0] as BooleanPrimary)!),
			]
		}
		'<boolean test: #2>' {
			return [
				EarleyValue(parse_boolean_test_2(children[0] as BooleanPrimary, children[2] as Value)!),
			]
		}
		'<boolean test: #3>' {
			return [
				EarleyValue(parse_boolean_test_3(children[0] as BooleanPrimary, children[3] as Value)!),
			]
		}
		'<boolean type: #1>' {
			return [EarleyValue(parse_boolean_type()!)]
		}
		'<boolean value expression: #1>' {
			return [
				EarleyValue(parse_boolean_value_expression_1(children[0] as BooleanTerm)!),
			]
		}
		'<boolean value expression: #2>' {
			return [
				EarleyValue(parse_boolean_value_expression_2(children[0] as BooleanValueExpression,
					children[2] as BooleanTerm)!),
			]
		}
		'<case abbreviation: #1>' {
			return [
				EarleyValue(parse_nullif(children[2] as ValueExpression, children[4] as ValueExpression)!),
			]
		}
		'<case abbreviation: #2>' {
			return [EarleyValue(parse_coalesce(children[2] as []ValueExpression)!)]
		}
		'<cast operand: #1>' {
			return [EarleyValue(CastOperand(children[0] as ValueExpression))]
		}
		'<cast operand: #2>' {
			return [EarleyValue(CastOperand(children[0] as NullSpecification))]
		}
		'<cast specification: #1>' {
			return [
				EarleyValue(parse_cast(children[2] as CastOperand, children[4] as Type)!),
			]
		}
		'<catalog name characteristic: #1>' {
			return [
				EarleyValue(parse_catalog_name_characteristic(children[1] as ValueSpecification)!),
			]
		}
		'<ceiling function: #1>' {
			return [
				EarleyValue(parse_ceiling(children[2] as NumericValueExpression)!),
			]
		}
		'<ceiling function: #2>' {
			return [
				EarleyValue(parse_ceiling(children[2] as NumericValueExpression)!),
			]
		}
		'<char length expression: #1>' {
			return [
				EarleyValue(parse_char_length(children[2] as CharacterValueExpression)!),
			]
		}
		'<char length expression: #2>' {
			return [
				EarleyValue(parse_char_length(children[2] as CharacterValueExpression)!),
			]
		}
		'<character like predicate part 2: #1>' {
			return [
				EarleyValue(parse_like(children[1] as CharacterValueExpression)!),
			]
		}
		'<character like predicate part 2: #2>' {
			return [
				EarleyValue(parse_not_like(children[2] as CharacterValueExpression)!),
			]
		}
		'<character like predicate: #1>' {
			return [
				EarleyValue(parse_like_pred(children[0] as RowValueConstructorPredicand,
					children[1] as CharacterLikePredicate)!),
			]
		}
		'<character position expression: #1>' {
			return [
				EarleyValue(parse_position(children[2] as CharacterValueExpression, children[4] as CharacterValueExpression)!),
			]
		}
		'<character primary: #1>' {
			return [
				EarleyValue(CharacterPrimary(children[0] as ValueExpressionPrimary)),
			]
		}
		'<character primary: #2>' {
			return [
				EarleyValue(CharacterPrimary(children[0] as CharacterValueFunction)),
			]
		}
		'<character string type: #1>' {
			return [EarleyValue(parse_character()!)]
		}
		'<character string type: #2>' {
			return [EarleyValue(parse_character_n(children[2] as string)!)]
		}
		'<character string type: #3>' {
			return [EarleyValue(parse_character()!)]
		}
		'<character string type: #4>' {
			return [EarleyValue(parse_character_n(children[2] as string)!)]
		}
		'<character string type: #5>' {
			return [EarleyValue(parse_varchar(children[3] as string)!)]
		}
		'<character string type: #6>' {
			return [EarleyValue(parse_varchar(children[3] as string)!)]
		}
		'<character string type: #7>' {
			return [EarleyValue(parse_varchar(children[2] as string)!)]
		}
		'<character substring function: #1>' {
			return [
				EarleyValue(parse_character_substring_function_1(children[2] as CharacterValueExpression,
					children[4] as NumericValueExpression)!),
			]
		}
		'<character substring function: #2>' {
			return [
				EarleyValue(parse_character_substring_function_2(children[2] as CharacterValueExpression,
					children[4] as NumericValueExpression, children[6] as NumericValueExpression)!),
			]
		}
		'<character substring function: #3>' {
			return [
				EarleyValue(parse_character_substring_function_3(children[2] as CharacterValueExpression,
					children[4] as NumericValueExpression, children[6] as string)!),
			]
		}
		'<character substring function: #4>' {
			return [
				EarleyValue(parse_character_substring_function_4(children[2] as CharacterValueExpression,
					children[4] as NumericValueExpression, children[6] as NumericValueExpression,
					children[8] as string)!),
			]
		}
		'<character value expression: #1>' {
			return [
				EarleyValue(CharacterValueExpression(children[0] as Concatenation)),
			]
		}
		'<character value expression: #2>' {
			return [
				EarleyValue(CharacterValueExpression(children[0] as CharacterPrimary)),
			]
		}
		'<character value function: #1>' {
			return [
				EarleyValue(CharacterValueFunction(children[0] as CharacterSubstringFunction)),
			]
		}
		'<character value function: #2>' {
			return [
				EarleyValue(CharacterValueFunction(children[0] as RoutineInvocation)),
			]
		}
		'<character value function: #3>' {
			return [EarleyValue(CharacterValueFunction(children[0] as TrimFunction))]
		}
		'<column constraint: #1>' {
			return [EarleyValue(parse_yes()!)]
		}
		'<column definition: #1>' {
			return [
				EarleyValue(parse_column_definition_1(children[0] as Identifier, children[1] as Type)!),
			]
		}
		'<column definition: #2>' {
			return [
				EarleyValue(parse_column_definition_2(children[0] as Identifier, children[1] as Type,
					children[2] as bool)!),
			]
		}
		'<column name list: #1>' {
			return [
				EarleyValue(parse_column_name_list_1(children[0] as Identifier)!),
			]
		}
		'<column name list: #2>' {
			return [
				EarleyValue(parse_column_name_list_2(children[0] as []Identifier, children[2] as Identifier)!),
			]
		}
		'<column name: #1>' {
			return [EarleyValue(parse_column_name(children[0] as IdentifierChain)!)]
		}
		'<column reference: #1>' {
			return [
				EarleyValue(parse_column_reference(children[0] as IdentifierChain)!),
			]
		}
		'<commit statement: #1>' {
			return [EarleyValue(parse_commit()!)]
		}
		'<commit statement: #2>' {
			return [EarleyValue(parse_commit()!)]
		}
		'<common logarithm: #1>' {
			return [EarleyValue(parse_log10(children[2] as NumericValueExpression)!)]
		}
		'<common sequence generator option: #1>' {
			return [
				EarleyValue(SequenceGeneratorOption(children[0] as SequenceGeneratorStartWithOption)),
			]
		}
		'<common sequence generator options: #1>' {
			return [
				EarleyValue(parse_sequence_generator_options_1(children[0] as SequenceGeneratorOption)!),
			]
		}
		'<common sequence generator options: #2>' {
			return [
				EarleyValue(parse_sequence_generator_options_2(children[0] as []SequenceGeneratorOption,
					children[1] as SequenceGeneratorOption)!),
			]
		}
		'<common value expression: #1>' {
			return [
				EarleyValue(CommonValueExpression(children[0] as NumericValueExpression)),
			]
		}
		'<common value expression: #2>' {
			return [
				EarleyValue(CommonValueExpression(children[0] as CharacterValueExpression)),
			]
		}
		'<common value expression: #3>' {
			return [
				EarleyValue(CommonValueExpression(children[0] as DatetimePrimary)),
			]
		}
		'<comparison predicate part 2: #1>' {
			return [
				EarleyValue(parse_comparison_part(children[0] as string, children[1] as RowValueConstructorPredicand)!),
			]
		}
		'<comparison predicate: #1>' {
			return [
				EarleyValue(parse_comparison(children[0] as RowValueConstructorPredicand,
					children[1] as ComparisonPredicatePart2)!),
			]
		}
		'<concatenation: #1>' {
			return [
				EarleyValue(parse_concatenation(children[0] as CharacterValueExpression,
					children[2] as CharacterPrimary)!),
			]
		}
		'<contextually typed row value constructor element list: #1>' {
			return [
				EarleyValue(parse_contextually_typed_row_value_constructor_element_list_1(children[0] as ContextuallyTypedRowValueConstructorElement)!),
			]
		}
		'<contextually typed row value constructor element list: #2>' {
			return [
				EarleyValue(parse_contextually_typed_row_value_constructor_element_list_2(children[0] as []ContextuallyTypedRowValueConstructorElement,
					children[2] as ContextuallyTypedRowValueConstructorElement)!),
			]
		}
		'<contextually typed row value constructor element: #1>' {
			return [
				EarleyValue(ContextuallyTypedRowValueConstructorElement(children[0] as ValueExpression)),
			]
		}
		'<contextually typed row value constructor element: #2>' {
			return [
				EarleyValue(ContextuallyTypedRowValueConstructorElement(children[0] as NullSpecification)),
			]
		}
		'<contextually typed row value constructor: #1>' {
			return [
				EarleyValue(ContextuallyTypedRowValueConstructor(children[0] as CommonValueExpression)),
			]
		}
		'<contextually typed row value constructor: #2>' {
			return [
				EarleyValue(ContextuallyTypedRowValueConstructor(children[0] as BooleanValueExpression)),
			]
		}
		'<contextually typed row value constructor: #3>' {
			return [
				EarleyValue(ContextuallyTypedRowValueConstructor(children[0] as NullSpecification)),
			]
		}
		'<contextually typed row value constructor: #4>' {
			return [
				EarleyValue(parse_contextually_typed_row_value_constructor_1(children[1] as NullSpecification)!),
			]
		}
		'<contextually typed row value constructor: #5>' {
			return [
				EarleyValue(parse_contextually_typed_row_value_constructor_2(children[1] as ContextuallyTypedRowValueConstructorElement,
					children[3] as []ContextuallyTypedRowValueConstructorElement)!),
			]
		}
		'<contextually typed row value expression list: #1>' {
			return [
				EarleyValue(parse_contextually_typed_row_value_expression_list_1(children[0] as ContextuallyTypedRowValueConstructor)!),
			]
		}
		'<contextually typed row value expression list: #2>' {
			return [
				EarleyValue(parse_contextually_typed_row_value_expression_list_2(children[0] as []ContextuallyTypedRowValueConstructor,
					children[2] as ContextuallyTypedRowValueConstructor)!),
			]
		}
		'<contextually typed table value constructor: #1>' {
			return [
				EarleyValue(parse_contextually_typed_table_value_constructor(children[1] as []ContextuallyTypedRowValueConstructor)!),
			]
		}
		'<correlation name: #1>' {
			return [
				EarleyValue(parse_correlation_name(children[0] as IdentifierChain)!),
			]
		}
		'<correlation or recognition: #1>' {
			return [EarleyValue(parse_correlation_1(children[0] as Identifier)!)]
		}
		'<correlation or recognition: #2>' {
			return [EarleyValue(parse_correlation_1(children[1] as Identifier)!)]
		}
		'<correlation or recognition: #3>' {
			return [
				EarleyValue(parse_correlation_2(children[0] as Identifier, children[1] as []Identifier)!),
			]
		}
		'<correlation or recognition: #4>' {
			return [
				EarleyValue(parse_correlation_2(children[1] as Identifier, children[2] as []Identifier)!),
			]
		}
		'<current date value function: #1>' {
			return [EarleyValue(parse_current_date()!)]
		}
		'<current local time value function: #1>' {
			return [EarleyValue(parse_localtime_1()!)]
		}
		'<current local time value function: #2>' {
			return [EarleyValue(parse_localtime_2(children[2] as string)!)]
		}
		'<current local timestamp value function: #1>' {
			return [EarleyValue(parse_localtimestamp_1()!)]
		}
		'<current local timestamp value function: #2>' {
			return [EarleyValue(parse_localtimestamp_2(children[2] as string)!)]
		}
		'<current time value function: #1>' {
			return [EarleyValue(parse_current_time_1()!)]
		}
		'<current time value function: #2>' {
			return [EarleyValue(parse_current_time_2(children[2] as string)!)]
		}
		'<current timestamp value function: #1>' {
			return [EarleyValue(parse_current_timestamp_1()!)]
		}
		'<current timestamp value function: #2>' {
			return [EarleyValue(parse_current_timestamp_2(children[2] as string)!)]
		}
		'<cursor specification: #1>' {
			return [EarleyValue(Stmt(children[0] as QueryExpression))]
		}
		'<date literal: #1>' {
			return [EarleyValue(parse_date_literal(children[1] as Value)!)]
		}
		'<datetime primary: #1>' {
			return [
				EarleyValue(DatetimePrimary(children[0] as ValueExpressionPrimary)),
			]
		}
		'<datetime primary: #2>' {
			return [
				EarleyValue(DatetimePrimary(children[0] as DatetimeValueFunction)),
			]
		}
		'<datetime type: #1>' {
			return [EarleyValue(parse_date_type()!)]
		}
		'<datetime type: #2>' {
			return [EarleyValue(parse_time_type()!)]
		}
		'<datetime type: #3>' {
			return [EarleyValue(parse_time_prec_type(children[2] as string)!)]
		}
		'<datetime type: #4>' {
			return [EarleyValue(parse_time_tz_type(children[1] as bool)!)]
		}
		'<datetime type: #5>' {
			return [
				EarleyValue(parse_time_prec_tz_type(children[2] as string, children[4] as bool)!),
			]
		}
		'<datetime type: #6>' {
			return [EarleyValue(parse_timestamp_type()!)]
		}
		'<datetime type: #7>' {
			return [EarleyValue(parse_timestamp_prec_type(children[2] as string)!)]
		}
		'<datetime type: #8>' {
			return [EarleyValue(parse_timestamp_tz_type(children[1] as bool)!)]
		}
		'<datetime type: #9>' {
			return [
				EarleyValue(parse_timestamp_prec_tz_type(children[2] as string, children[4] as bool)!),
			]
		}
		'<delete statement: searched: #1>' {
			return [EarleyValue(parse_delete_statement(children[2] as Identifier)!)]
		}
		'<delete statement: searched: #2>' {
			return [
				EarleyValue(parse_delete_statement_where(children[2] as Identifier, children[4] as BooleanValueExpression)!),
			]
		}
		'<derived column: #1>' {
			return [
				EarleyValue(parse_derived_column(children[0] as ValueExpression)!),
			]
		}
		'<derived column: #2>' {
			return [
				EarleyValue(parse_derived_column_as(children[0] as ValueExpression, children[1] as Identifier)!),
			]
		}
		'<drop schema statement: #1>' {
			return [
				EarleyValue(parse_drop_schema_statement(children[2] as Identifier, children[3] as string)!),
			]
		}
		'<drop sequence generator statement: #1>' {
			return [
				EarleyValue(parse_drop_sequence_generator_statement(children[2] as Identifier)!),
			]
		}
		'<drop table statement: #1>' {
			return [
				EarleyValue(parse_drop_table_statement(children[2] as Identifier)!),
			]
		}
		'<exact numeric literal: #1>' {
			return [EarleyValue(parse_int_value(children[0] as string)!)]
		}
		'<exact numeric literal: #2>' {
			return [EarleyValue(parse_int_value(children[0] as string)!)]
		}
		'<exact numeric literal: #3>' {
			return [
				EarleyValue(parse_exact_numeric_literal_1(children[0] as string, children[2] as string)!),
			]
		}
		'<exact numeric literal: #4>' {
			return [
				EarleyValue(parse_exact_numeric_literal_2(children[1] as string)!),
			]
		}
		'<exact numeric type: #1>' {
			return [EarleyValue(parse_smallint()!)]
		}
		'<exact numeric type: #2>' {
			return [EarleyValue(parse_integer()!)]
		}
		'<exact numeric type: #3>' {
			return [EarleyValue(parse_integer()!)]
		}
		'<exact numeric type: #4>' {
			return [EarleyValue(parse_bigint()!)]
		}
		'<explicit row value constructor: #1>' {
			return [
				EarleyValue(parse_explicit_row_value_constructor_1(children[2] as []ValueExpression)!),
			]
		}
		'<explicit row value constructor: #2>' {
			return [
				EarleyValue(ExplicitRowValueConstructor(children[0] as QueryExpression)),
			]
		}
		'<exponential function: #1>' {
			return [EarleyValue(parse_exp(children[2] as NumericValueExpression)!)]
		}
		'<factor: #2>' {
			return [
				EarleyValue(parse_factor_2(children[0] as string, children[1] as NumericPrimary)!),
			]
		}
		'<fetch first clause: #1>' {
			return [
				EarleyValue(parse_fetch_first_clause(children[2] as ValueSpecification)!),
			]
		}
		'<floor function: #1>' {
			return [EarleyValue(parse_floor(children[2] as NumericValueExpression)!)]
		}
		'<fold: #1>' {
			return [
				EarleyValue(parse_upper(children[2] as CharacterValueExpression)!),
			]
		}
		'<fold: #2>' {
			return [
				EarleyValue(parse_lower(children[2] as CharacterValueExpression)!),
			]
		}
		'<from clause: #1>' {
			return [EarleyValue(parse_from_clause(children[1] as TableReference)!)]
		}
		'<from constructor: #1>' {
			return [
				EarleyValue(parse_from_constructor(children[1] as []Identifier, children[3] as []ContextuallyTypedRowValueConstructor)!),
			]
		}
		'<general set function: #1>' {
			return [
				EarleyValue(parse_general_set_function(children[0] as string, children[2] as ValueExpression)!),
			]
		}
		'<general value specification: #2>' {
			return [EarleyValue(parse_current_catalog()!)]
		}
		'<general value specification: #3>' {
			return [EarleyValue(parse_current_schema()!)]
		}
		'<group by clause: #1>' {
			return [EarleyValue(parse_group_by_clause(children[2] as []Identifier)!)]
		}
		'<grouping element list: #1>' {
			return [
				EarleyValue(parse_grouping_element_list_1(children[0] as Identifier)!),
			]
		}
		'<grouping element list: #2>' {
			return [
				EarleyValue(parse_grouping_element_list_2(children[0] as []Identifier,
					children[2] as Identifier)!),
			]
		}
		'<host parameter name: #1>' {
			return [
				EarleyValue(parse_host_parameter_name(children[1] as IdentifierChain)!),
			]
		}
		'<identifier chain: #2>' {
			return [
				EarleyValue(parse_identifier_chain(children[0] as IdentifierChain, children[2] as IdentifierChain)!),
			]
		}
		'<insert statement: #1>' {
			return [
				EarleyValue(parse_insert_statement(children[2] as Identifier, children[3] as InsertStatement)!),
			]
		}
		'<is symmetric: #1>' {
			return [EarleyValue(parse_yes()!)]
		}
		'<is symmetric: #2>' {
			return [EarleyValue(parse_no()!)]
		}
		'<join condition: #1>' {
			return [
				EarleyValue(parse_join_condition(children[1] as BooleanValueExpression)!),
			]
		}
		'<join type: #3>' {
			return [EarleyValue(parse_string(children[0] as string)!)]
		}
		'<local or schema qualified name: #2>' {
			return [
				EarleyValue(parse_local_or_schema_qualified_name2(children[0] as Identifier,
					children[2] as IdentifierChain)!),
			]
		}
		'<modulus expression: #1>' {
			return [
				EarleyValue(parse_mod(children[2] as NumericValueExpression, children[4] as NumericValueExpression)!),
			]
		}
		'<natural logarithm: #1>' {
			return [EarleyValue(parse_ln(children[2] as NumericValueExpression)!)]
		}
		'<next value expression: #1>' {
			return [
				EarleyValue(parse_next_value_expression(children[3] as Identifier)!),
			]
		}
		'<nonparenthesized value expression primary: #1>' {
			return [
				EarleyValue(NonparenthesizedValueExpressionPrimary(children[0] as ValueSpecification)),
			]
		}
		'<nonparenthesized value expression primary: #2>' {
			return [
				EarleyValue(NonparenthesizedValueExpressionPrimary(children[0] as Identifier)),
			]
		}
		'<nonparenthesized value expression primary: #3>' {
			return [
				EarleyValue(NonparenthesizedValueExpressionPrimary(children[0] as AggregateFunction)),
			]
		}
		'<nonparenthesized value expression primary: #4>' {
			return [
				EarleyValue(NonparenthesizedValueExpressionPrimary(children[0] as RoutineInvocation)),
			]
		}
		'<nonparenthesized value expression primary: #5>' {
			return [
				EarleyValue(NonparenthesizedValueExpressionPrimary(children[0] as CaseExpression)),
			]
		}
		'<nonparenthesized value expression primary: #6>' {
			return [
				EarleyValue(NonparenthesizedValueExpressionPrimary(children[0] as CastSpecification)),
			]
		}
		'<nonparenthesized value expression primary: #7>' {
			return [
				EarleyValue(NonparenthesizedValueExpressionPrimary(children[0] as NextValueExpression)),
			]
		}
		'<null predicate part 2: #1>' {
			return [EarleyValue(parse_yes()!)]
		}
		'<null predicate part 2: #2>' {
			return [EarleyValue(parse_no()!)]
		}
		'<null predicate: #1>' {
			return [
				EarleyValue(parse_null_predicate(children[0] as RowValueConstructorPredicand,
					children[1] as bool)!),
			]
		}
		'<null specification: #1>' {
			return [EarleyValue(parse_null_specification()!)]
		}
		'<numeric primary: #1>' {
			return [
				EarleyValue(NumericPrimary(children[0] as ValueExpressionPrimary)),
			]
		}
		'<numeric primary: #2>' {
			return [EarleyValue(NumericPrimary(children[0] as RoutineInvocation))]
		}
		'<numeric value expression: #1>' {
			return [
				EarleyValue(parse_numeric_value_expression_1(children[0] as Term)!),
			]
		}
		'<numeric value expression: #2>' {
			return [
				EarleyValue(parse_numeric_value_expression_2(children[0] as NumericValueExpression,
					children[1] as string, children[2] as Term)!),
			]
		}
		'<numeric value expression: #3>' {
			return [
				EarleyValue(parse_numeric_value_expression_2(children[0] as NumericValueExpression,
					children[1] as string, children[2] as Term)!),
			]
		}
		'<octet length expression: #1>' {
			return [
				EarleyValue(parse_octet_length(children[2] as CharacterValueExpression)!),
			]
		}
		'<order by clause: #1>' {
			return [EarleyValue(parse_order_by(children[2] as []SortSpecification)!)]
		}
		'<ordering specification: #1>' {
			return [EarleyValue(parse_yes()!)]
		}
		'<ordering specification: #2>' {
			return [EarleyValue(parse_no()!)]
		}
		'<parenthesized boolean value expression: #1>' {
			return [
				EarleyValue(parse_parenthesized_boolean_value_expression(children[1] as BooleanValueExpression)!),
			]
		}
		'<parenthesized derived column list: #1>' {
			return [
				EarleyValue(parse_parenthesized_derived_column_list(children[1] as []Identifier)!),
			]
		}
		'<parenthesized value expression: #1>' {
			return [
				EarleyValue(parse_parenthesized_value_expression(children[1] as ValueExpression)!),
			]
		}
		'<power function: #1>' {
			return [
				EarleyValue(parse_power(children[2] as NumericValueExpression, children[4] as NumericValueExpression)!),
			]
		}
		'<predicate: #1>' {
			return [EarleyValue(Predicate(children[0] as ComparisonPredicate))]
		}
		'<predicate: #2>' {
			return [EarleyValue(Predicate(children[0] as BetweenPredicate))]
		}
		'<predicate: #3>' {
			return [EarleyValue(Predicate(children[0] as CharacterLikePredicate))]
		}
		'<predicate: #4>' {
			return [EarleyValue(Predicate(children[0] as SimilarPredicate))]
		}
		'<predicate: #5>' {
			return [EarleyValue(Predicate(children[0] as NullPredicate))]
		}
		'<qualified asterisk: #1>' {
			return [
				EarleyValue(parse_qualified_asterisk(children[0] as IdentifierChain, children[2] as string)!),
			]
		}
		'<qualified join: #1>' {
			return [
				EarleyValue(parse_qualified_join_1(children[0] as TableReference, children[2] as TableReference,
					children[3] as BooleanValueExpression)!),
			]
		}
		'<qualified join: #2>' {
			return [
				EarleyValue(parse_qualified_join_2(children[0] as TableReference, children[1] as string,
					children[3] as TableReference, children[4] as BooleanValueExpression)!),
			]
		}
		'<query expression: #1>' {
			return [EarleyValue(parse_query_expression(children[0] as SimpleTable)!)]
		}
		'<query expression: #2>' {
			return [
				EarleyValue(parse_query_expression_order(children[0] as SimpleTable, children[1] as []SortSpecification)!),
			]
		}
		'<query expression: #3>' {
			return [
				EarleyValue(parse_query_expression_offset(children[0] as SimpleTable,
					children[1] as ValueSpecification)!),
			]
		}
		'<query expression: #4>' {
			return [
				EarleyValue(parse_query_expression_order_offset(children[0] as SimpleTable,
					children[1] as []SortSpecification, children[2] as ValueSpecification)!),
			]
		}
		'<query expression: #5>' {
			return [
				EarleyValue(parse_query_expression_fetch(children[0] as SimpleTable, children[1] as ValueSpecification)!),
			]
		}
		'<query expression: #6>' {
			return [
				EarleyValue(parse_query_expression_order_fetch(children[0] as SimpleTable,
					children[1] as []SortSpecification, children[2] as ValueSpecification)!),
			]
		}
		'<query expression: #7>' {
			return [
				EarleyValue(parse_query_expression_order_offset_fetch(children[0] as SimpleTable,
					children[1] as []SortSpecification, children[2] as ValueSpecification,
					children[3] as ValueSpecification)!),
			]
		}
		'<query expression: #8>' {
			return [
				EarleyValue(parse_query_expression_offset_fetch(children[0] as SimpleTable,
					children[1] as ValueSpecification, children[2] as ValueSpecification)!),
			]
		}
		'<query specification: #1>' {
			return [
				EarleyValue(parse_query_specification(children[1] as SelectList, children[2] as TableExpression)!),
			]
		}
		'<regular identifier: #2>' {
			return [EarleyValue(parse_string_identifier(children[0] as string)!)]
		}
		'<result offset clause: #1>' {
			return [
				EarleyValue(parse_result_offset_clause(children[1] as ValueSpecification)!),
			]
		}
		'<rollback statement: #1>' {
			return [EarleyValue(parse_rollback()!)]
		}
		'<rollback statement: #2>' {
			return [EarleyValue(parse_rollback()!)]
		}
		'<routine invocation: #1>' {
			return [
				EarleyValue(parse_routine_invocation(children[0] as Identifier, children[1] as []ValueExpression)!),
			]
		}
		'<routine name: #1>' {
			return [EarleyValue(parse_routine_name(children[0] as IdentifierChain)!)]
		}
		'<row value constructor element list: #1>' {
			return [
				EarleyValue(parse_row_value_constructor_element_list_1(children[0] as ValueExpression)!),
			]
		}
		'<row value constructor element list: #2>' {
			return [
				EarleyValue(parse_row_value_constructor_element_list_2(children[0] as []ValueExpression,
					children[2] as ValueExpression)!),
			]
		}
		'<row value constructor predicand: #1>' {
			return [
				EarleyValue(RowValueConstructorPredicand(children[0] as CommonValueExpression)),
			]
		}
		'<row value constructor predicand: #2>' {
			return [
				EarleyValue(RowValueConstructorPredicand(children[0] as BooleanPredicand)),
			]
		}
		'<row value constructor: #1>' {
			return [
				EarleyValue(RowValueConstructor(children[0] as CommonValueExpression)),
			]
		}
		'<row value constructor: #2>' {
			return [
				EarleyValue(RowValueConstructor(children[0] as BooleanValueExpression)),
			]
		}
		'<row value constructor: #3>' {
			return [
				EarleyValue(RowValueConstructor(children[0] as ExplicitRowValueConstructor)),
			]
		}
		'<row value expression list: #1>' {
			return [
				EarleyValue(parse_row_value_expression_list_1(children[0] as RowValueConstructor)!),
			]
		}
		'<row value expression list: #2>' {
			return [
				EarleyValue(parse_row_value_expression_list_2(children[0] as []RowValueConstructor,
					children[2] as RowValueConstructor)!),
			]
		}
		'<schema definition: #1>' {
			return [EarleyValue(parse_schema_definition(children[2] as Identifier)!)]
		}
		'<schema name characteristic: #1>' {
			return [
				EarleyValue(parse_schema_name_characteristic(children[1] as ValueSpecification)!),
			]
		}
		'<schema name: #1>' {
			return [
				EarleyValue(parse_schema_name_1(children[0] as IdentifierChain, children[2] as Identifier)!),
			]
		}
		'<schema qualified name: #2>' {
			return [
				EarleyValue(parse_schema_qualified_name_2(children[0] as Identifier, children[2] as IdentifierChain)!),
			]
		}
		'<select list: #1>' {
			return [EarleyValue(parse_asterisk(children[0] as string)!)]
		}
		'<select list: #3>' {
			return [
				EarleyValue(parse_select_list_2(children[0] as SelectList, children[2] as SelectList)!),
			]
		}
		'<select sublist: #1>' {
			return [
				EarleyValue(parse_select_sublist_1(children[0] as DerivedColumn)!),
			]
		}
		'<select sublist: #2>' {
			return [EarleyValue(SelectList(children[0] as QualifiedAsteriskExpr))]
		}
		'<sequence generator cycle option: #1>' {
			return [EarleyValue(parse_yes()!)]
		}
		'<sequence generator cycle option: #2>' {
			return [EarleyValue(parse_no()!)]
		}
		'<sequence generator definition: #1>' {
			return [
				EarleyValue(parse_sequence_generator_definition_1(children[2] as Identifier)!),
			]
		}
		'<sequence generator definition: #2>' {
			return [
				EarleyValue(parse_sequence_generator_definition_2(children[2] as Identifier,
					children[3] as []SequenceGeneratorOption)!),
			]
		}
		'<sequence generator increment by option: #1>' {
			return [
				EarleyValue(parse_sequence_generator_increment_by_option(children[2] as Value)!),
			]
		}
		'<sequence generator maxvalue option: #1>' {
			return [
				EarleyValue(parse_sequence_generator_maxvalue_option_1(children[1] as Value)!),
			]
		}
		'<sequence generator maxvalue option: #2>' {
			return [EarleyValue(parse_sequence_generator_maxvalue_option_2()!)]
		}
		'<sequence generator minvalue option: #1>' {
			return [
				EarleyValue(parse_sequence_generator_minvalue_option_1(children[1] as Value)!),
			]
		}
		'<sequence generator minvalue option: #2>' {
			return [EarleyValue(parse_sequence_generator_minvalue_option_2()!)]
		}
		'<sequence generator name: #1>' {
			return [
				EarleyValue(parse_sequence_generator_name(children[0] as IdentifierChain)!),
			]
		}
		'<sequence generator start with option: #1>' {
			return [
				EarleyValue(parse_sequence_generator_start_with_option(children[2] as Value)!),
			]
		}
		'<set catalog statement: #1>' {
			return [
				EarleyValue(parse_set_catalog_stmt(children[1] as ValueSpecification)!),
			]
		}
		'<set clause list: #2>' {
			return [
				EarleyValue(parse_set_clause_append(children[0] as map[string]UpdateSource,
					children[2] as map[string]UpdateSource)!),
			]
		}
		'<set clause: #1>' {
			return [
				EarleyValue(parse_set_clause(children[0] as Identifier, children[2] as UpdateSource)!),
			]
		}
		'<set schema statement: #1>' {
			return [
				EarleyValue(parse_set_schema_stmt(children[1] as ValueSpecification)!),
			]
		}
		'<signed numeric literal: #2>' {
			return [
				EarleyValue(parse_signed_numeric_literal_2(children[0] as string, children[1] as Value)!),
			]
		}
		'<similar predicate part 2: #1>' {
			return [
				EarleyValue(parse_similar(children[2] as CharacterValueExpression)!),
			]
		}
		'<similar predicate part 2: #2>' {
			return [
				EarleyValue(parse_not_similar(children[3] as CharacterValueExpression)!),
			]
		}
		'<similar predicate: #1>' {
			return [
				EarleyValue(parse_similar_pred(children[0] as RowValueConstructorPredicand,
					children[1] as SimilarPredicate)!),
			]
		}
		'<simple value specification: #1>' {
			return [EarleyValue(ValueSpecification(children[0] as Value))]
		}
		'<simple value specification: #2>' {
			return [
				EarleyValue(ValueSpecification(children[0] as GeneralValueSpecification)),
			]
		}
		'<sort specification list: #1>' {
			return [
				EarleyValue(parse_sort_list_1(children[0] as SortSpecification)!),
			]
		}
		'<sort specification list: #2>' {
			return [
				EarleyValue(parse_sort_list_2(children[0] as []SortSpecification, children[2] as SortSpecification)!),
			]
		}
		'<sort specification: #1>' {
			return [EarleyValue(parse_sort_1(children[0] as ValueExpression)!)]
		}
		'<sort specification: #2>' {
			return [
				EarleyValue(parse_sort_2(children[0] as ValueExpression, children[1] as bool)!),
			]
		}
		'<SQL argument list: #1>' {
			return [EarleyValue(parse_sql_argument_list_1()!)]
		}
		'<SQL argument list: #2>' {
			return [
				EarleyValue(parse_sql_argument_list_2(children[1] as ValueExpression)!),
			]
		}
		'<SQL argument list: #3>' {
			return [
				EarleyValue(parse_sql_argument_list_3(children[1] as []ValueExpression,
					children[3] as ValueExpression)!),
			]
		}
		'<SQL schema manipulation statement: #3>' {
			return [EarleyValue(Stmt(children[0] as AlterSequenceGeneratorStatement))]
		}
		'<square root: #1>' {
			return [EarleyValue(parse_sqrt(children[2] as NumericValueExpression)!)]
		}
		'<start transaction statement: #1>' {
			return [EarleyValue(parse_start_transaction_statement()!)]
		}
		'<subquery: #1>' {
			return [EarleyValue(parse_subquery(children[1] as QueryExpression)!)]
		}
		'<table definition: #1>' {
			return [
				EarleyValue(parse_table_definition(children[2] as Identifier, children[3] as []TableElement)!),
			]
		}
		'<table element list: #1>' {
			return [
				EarleyValue(parse_table_element_list(children[1] as []TableElement)!),
			]
		}
		'<table elements: #1>' {
			return [
				EarleyValue(parse_table_elements_1(children[0] as TableElement)!),
			]
		}
		'<table elements: #2>' {
			return [
				EarleyValue(parse_table_elements_2(children[0] as []TableElement, children[2] as TableElement)!),
			]
		}
		'<table expression: #1>' {
			return [
				EarleyValue(parse_table_expression(children[0] as TableReference)!),
			]
		}
		'<table expression: #2>' {
			return [
				EarleyValue(parse_table_expression_where(children[0] as TableReference,
					children[1] as BooleanValueExpression)!),
			]
		}
		'<table expression: #3>' {
			return [
				EarleyValue(parse_table_expression_group(children[0] as TableReference,
					children[1] as []Identifier)!),
			]
		}
		'<table expression: #4>' {
			return [
				EarleyValue(parse_table_expression_where_group(children[0] as TableReference,
					children[1] as BooleanValueExpression, children[2] as []Identifier)!),
			]
		}
		'<table name: #1>' {
			return [EarleyValue(parse_table_name(children[0] as IdentifierChain)!)]
		}
		'<table primary: #1>' {
			return [
				EarleyValue(parse_table_primary_identifier(children[0] as Identifier)!),
			]
		}
		'<table primary: #3>' {
			return [
				EarleyValue(parse_table_primary_derived_2(children[0] as TablePrimary,
					children[1] as Correlation)!),
			]
		}
		'<table reference: #1>' {
			return [EarleyValue(TableReference(children[0] as TablePrimary))]
		}
		'<table reference: #2>' {
			return [EarleyValue(TableReference(children[0] as QualifiedJoin))]
		}
		'<table value constructor: #1>' {
			return [
				EarleyValue(parse_table_value_constructor(children[1] as []RowValueConstructor)!),
			]
		}
		'<term: #1>' {
			return [EarleyValue(parse_term_1(children[0] as NumericPrimary)!)]
		}
		'<term: #2>' {
			return [
				EarleyValue(parse_term_2(children[0] as Term, children[1] as string, children[2] as NumericPrimary)!),
			]
		}
		'<term: #3>' {
			return [
				EarleyValue(parse_term_2(children[0] as Term, children[1] as string, children[2] as NumericPrimary)!),
			]
		}
		'<time literal: #1>' {
			return [EarleyValue(parse_time_literal(children[1] as Value)!)]
		}
		'<timestamp literal: #1>' {
			return [EarleyValue(parse_timestamp_literal(children[1] as Value)!)]
		}
		'<trigonometric function: #1>' {
			return [
				EarleyValue(parse_trig_func(children[0] as string, children[2] as NumericValueExpression)!),
			]
		}
		'<trim function: #1>' {
			return [EarleyValue(parse_trim_function(children[2] as TrimFunction)!)]
		}
		'<trim operands: #1>' {
			return [
				EarleyValue(parse_trim_operands_1(children[0] as CharacterValueExpression)!),
			]
		}
		'<trim operands: #2>' {
			return [
				EarleyValue(parse_trim_operands_1(children[1] as CharacterValueExpression)!),
			]
		}
		'<trim operands: #3>' {
			return [
				EarleyValue(parse_trim_operands_2(children[0] as string, children[2] as CharacterValueExpression)!),
			]
		}
		'<trim operands: #4>' {
			return [
				EarleyValue(parse_trim_operands_3(children[0] as CharacterValueExpression,
					children[2] as CharacterValueExpression)!),
			]
		}
		'<trim operands: #5>' {
			return [
				EarleyValue(parse_trim_operands_4(children[0] as string, children[1] as CharacterValueExpression,
					children[3] as CharacterValueExpression)!),
			]
		}
		'<truth value: #1>' {
			return [EarleyValue(parse_true()!)]
		}
		'<truth value: #2>' {
			return [EarleyValue(parse_false()!)]
		}
		'<truth value: #3>' {
			return [EarleyValue(parse_unknown()!)]
		}
		'<unique constraint definition: #1>' {
			return [
				EarleyValue(parse_unique_constraint_definition(children[2] as []Identifier)!),
			]
		}
		'<unique specification: #1>' {
			return [EarleyValue(parse_ignore()!)]
		}
		'<unqualified schema name: #1>' {
			return [
				EarleyValue(parse_unqualified_schema_name(children[0] as IdentifierChain)!),
			]
		}
		'<unsigned value specification: #1>' {
			return [EarleyValue(ValueSpecification(children[0] as Value))]
		}
		'<unsigned value specification: #2>' {
			return [
				EarleyValue(ValueSpecification(children[0] as GeneralValueSpecification)),
			]
		}
		'<update source: #1>' {
			return [EarleyValue(UpdateSource(children[0] as ValueExpression))]
		}
		'<update source: #2>' {
			return [EarleyValue(UpdateSource(children[0] as NullSpecification))]
		}
		'<update statement: searched: #1>' {
			return [
				EarleyValue(parse_update_statement_searched_1(children[1] as Identifier,
					children[3] as map[string]UpdateSource)!),
			]
		}
		'<update statement: searched: #2>' {
			return [
				EarleyValue(parse_update_statement_searched_2(children[1] as Identifier,
					children[3] as map[string]UpdateSource, children[5] as BooleanValueExpression)!),
			]
		}
		'<value expression list: #1>' {
			return [
				EarleyValue(parse_value_expression_list_1(children[0] as ValueExpression)!),
			]
		}
		'<value expression list: #2>' {
			return [
				EarleyValue(parse_value_expression_list_2(children[0] as []ValueExpression,
					children[2] as ValueExpression)!),
			]
		}
		'<value expression primary: #1>' {
			return [
				EarleyValue(ValueExpressionPrimary(children[0] as ParenthesizedValueExpression)),
			]
		}
		'<value expression primary: #2>' {
			return [
				EarleyValue(ValueExpressionPrimary(children[0] as NonparenthesizedValueExpressionPrimary)),
			]
		}
		'<value expression: #1>' {
			return [
				EarleyValue(ValueExpression(children[0] as CommonValueExpression)),
			]
		}
		'<value expression: #2>' {
			return [
				EarleyValue(ValueExpression(children[0] as BooleanValueExpression)),
			]
		}
		'<value specification: #1>' {
			return [EarleyValue(ValueSpecification(children[0] as Value))]
		}
		'<value specification: #2>' {
			return [
				EarleyValue(ValueSpecification(children[0] as GeneralValueSpecification)),
			]
		}
		'<where clause: #1>' {
			return [
				EarleyValue(parse_where_clause(children[1] as BooleanValueExpression)!),
			]
		}
		'<with or without time zone: #1>' {
			return [EarleyValue(parse_yes()!)]
		}
		'<with or without time zone: #2>' {
			return [EarleyValue(parse_no()!)]
		}
		else {
			return children
		}
	}
}
