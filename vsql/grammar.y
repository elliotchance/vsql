%{

module vsql

import math

%}

// non-reserved words
%token A
%token ABSOLUTE
%token ACTION
%token ADA
%token ADD
%token ADMIN
%token AFTER
%token ALWAYS
%token ASC
%token ASSERTION
%token ASSIGNMENT
%token ATTRIBUTE
%token ATTRIBUTES
%token BEFORE
%token BERNOULLI
%token BREADTH
%token C
%token CASCADE
%token CATALOG
%token CATALOG_NAME
%token CHAIN
%token CHAINING
%token CHARACTER_SET_CATALOG
%token CHARACTER_SET_NAME
%token CHARACTER_SET_SCHEMA
%token CHARACTERISTICS
%token CHARACTERS
%token CLASS_ORIGIN
%token COBOL
%token COLLATION
%token COLLATION_CATALOG
%token COLLATION_NAME
%token COLLATION_SCHEMA
%token COLUMNS
%token COLUMN_NAME
%token COMMAND_FUNCTION
%token COMMAND_FUNCTION_CODE
%token COMMITTED
%token CONDITIONAL
%token CONDITION_NUMBER
%token CONNECTION
%token CONNECTION_NAME
%token CONSTRAINT_CATALOG
%token CONSTRAINT_NAME
%token CONSTRAINT_SCHEMA
%token CONSTRAINTS
%token CONSTRUCTOR
%token CONTINUE
%token CURSOR_NAME
%token DATA
%token DATETIME_INTERVAL_CODE
%token DATETIME_INTERVAL_PRECISION
%token DEFAULTS
%token DEFERRABLE
%token DEFERRED
%token DEFINED
%token DEFINER
%token DEGREE
%token DEPTH
%token DERIVED
%token DESC
%token DESCRIBE_CATALOG
%token DESCRIBE_NAME
%token DESCRIBE_PROCEDURE_SPECIFIC_CATALOG
%token DESCRIBE_PROCEDURE_SPECIFIC_NAME
%token DESCRIBE_PROCEDURE_SPECIFIC_SCHEMA
%token DESCRIBE_SCHEMA
%token DESCRIPTOR
%token DIAGNOSTICS
%token DISPATCH
%token DOMAIN
%token DYNAMIC_FUNCTION
%token DYNAMIC_FUNCTION_CODE
%token ENCODING
%token ENFORCED
%token ERROR
%token EXCLUDE
%token EXCLUDING
%token EXPRESSION
%token FINAL
%token FINISH
%token FINISH_CATALOG
%token FINISH_NAME
%token FINISH_PROCEDURE_SPECIFIC_CATALOG
%token FINISH_PROCEDURE_SPECIFIC_NAME
%token FINISH_PROCEDURE_SPECIFIC_SCHEMA
%token FINISH_SCHEMA
%token FIRST
%token FLAG
%token FOLLOWING
%token FORMAT
%token FORTRAN
%token FOUND
%token FULFILL
%token FULFILL_CATALOG
%token FULFILL_NAME
%token FULFILL_PROCEDURE_SPECIFIC_CATALOG
%token FULFILL_PROCEDURE_SPECIFIC_NAME
%token FULFILL_PROCEDURE_SPECIFIC_SCHEMA
%token FULFILL_SCHEMA
%token G
%token GENERAL
%token GENERATED
%token GO
%token GOTO
%token GRANTED
%token HAS_PASS_THROUGH_COLUMNS
%token HAS_PASS_THRU_COLS
%token HIERARCHY
%token IGNORE
%token IMMEDIATE
%token IMMEDIATELY
%token IMPLEMENTATION
%token INCLUDING
%token INCREMENT
%token INITIALLY
%token INPUT
%token INSTANCE
%token INSTANTIABLE
%token INSTEAD
%token INVOKER
%token ISOLATION
%token IS_PRUNABLE
%token JSON
%token K
%token KEEP
%token KEY
%token KEYS
%token KEY_MEMBER
%token KEY_TYPE
%token LAST
%token LENGTH
%token LEVEL
%token LOCATOR
%token M
%token MAP
%token MATCHED
%token MAXVALUE
%token MESSAGE_LENGTH
%token MESSAGE_OCTET_LENGTH
%token MESSAGE_TEXT
%token MINVALUE
%token MORE
%token MUMPS
%token NAME
%token NAMES
%token NESTED
%token NESTING
%token NEXT
%token NFC
%token NFD
%token NFKC
%token NFKD
%token NORMALIZED
%token NULLABLE
%token NULLS
%token NUMBER
%token OBJECT
%token OCTETS
%token OPTION
%token OPTIONS
%token ORDERING
%token ORDINALITY
%token OTHERS
%token OUTPUT
%token OVERFLOW
%token OVERRIDING
%token P
%token PAD
%token PARAMETER_MODE
%token PARAMETER_NAME
%token PARAMETER_ORDINAL_POSITION
%token PARAMETER_SPECIFIC_CATALOG
%token PARAMETER_SPECIFIC_NAME
%token PARAMETER_SPECIFIC_SCHEMA
%token PARTIAL
%token PASCAL
%token PASS
%token PASSING
%token PAST
%token PATH
%token PLACING
%token PLAN
%token PLI
%token PRECEDING
%token PRESERVE
%token PRIOR
%token PRIVATE
%token PRIVATE_PARAMETERS
%token PRIVATE_PARAMS_S
%token PRIVILEGES
%token PRUNE
%token PUBLIC
%token QUOTES
%token READ
%token RELATIVE
%token REPEATABLE
%token RESPECT
%token RESTART
%token RESTRICT
%token RETURNED_CARDINALITY
%token RETURNED_LENGTH
%token RETURNED_OCTET_LENGTH
%token RETURNED_SQLSTATE
%token RETURNING
%token RETURNS_ONLY_PASS_THROUGH
%token RET_ONLY_PASS_THRU
%token ROLE
%token ROUTINE
%token ROUTINE_CATALOG
%token ROUTINE_NAME
%token ROUTINE_SCHEMA
%token ROW_COUNT
%token SCALAR
%token SCALE
%token SCHEMA
%token SCHEMA_NAME
%token SCOPE_CATALOG
%token SCOPE_NAME
%token SCOPE_SCHEMA
%token SECTION
%token SECURITY
%token SELF
%token SEQUENCE
%token SERIALIZABLE
%token SERVER_NAME
%token SESSION
%token SETS
%token SIMPLE
%token SIZE
%token SOURCE
%token SPACE
%token SPECIFIC_NAME
%token START_CATALOG
%token START_NAME
%token START_PROCEDURE_SPECIFIC_CATALOG
%token START_PROCEDURE_SPECIFIC_NAME
%token START_PROCEDURE_SPECIFIC_SCHEMA
%token START_SCHEMA
%token STATE
%token STATEMENT
%token STRING
%token STRUCTURE
%token STYLE
%token SUBCLASS_ORIGIN
%token T
%token TABLE_NAME
%token TABLE_SEMANTICS
%token TEMPORARY
%token THROUGH
%token TIES
%token TOP_LEVEL_COUNT
%token TRANSACTION
%token TRANSACTION_ACTIVE
%token TRANSACTIONS_COMMITTED
%token TRANSACTIONS_ROLLED_BACK
%token TRANSFORM
%token TRANSFORMS
%token TRIGGER_CATALOG
%token TRIGGER_NAME
%token TRIGGER_SCHEMA
%token TYPE
%token UNBOUNDED
%token UNCOMMITTED
%token UNCONDITIONAL
%token UNDER
%token UNNAMED
%token USAGE
%token USER_DEFINED_TYPE_CATALOG
%token USER_DEFINED_TYPE_CODE
%token USER_DEFINED_TYPE_NAME
%token USER_DEFINED_TYPE_SCHEMA
%token UTF16
%token UTF32
%token UTF8
%token VIEW
%token WORK
%token WRAPPER
%token WRITE
%token ZONE

// reserved words
%token ABS
%token ACOS
%token ALL
%token ALLOCATE
%token ALTER
%token AND
%token ANY
%token ARE
%token ARRAY
%token ARRAY_AGG
%token ARRAY_MAX_CARDINALITY
%token AS
%token ASENSITIVE
%token ASIN
%token ASYMMETRIC
%token AT
%token ATAN
%token ATOMIC
%token AUTHORIZATION
%token AVG
%token BEGIN
%token BEGIN_FRAME
%token BEGIN_PARTITION
%token BETWEEN
%token BIGINT
%token BINARY
%token BLOB
%token BOOLEAN
%token BOTH
%token BY
%token CALL
%token CALLED
%token CARDINALITY
%token CASCADED
%token CASE
%token CAST
%token CEIL
%token CEILING
%token CHAR
%token CHAR_LENGTH
%token CHARACTER
%token CHARACTER_LENGTH
%token CHECK
%token CLASSIFIER
%token CLOB
%token CLOSE
%token COALESCE
%token COLLATE
%token COLLECT
%token COLUMN
%token COMMIT
%token CONDITION
%token CONNECT
%token CONSTRAINT
%token CONTAINS
%token CONVERT
%token COPY
%token CORR
%token CORRESPONDING
%token COS
%token COSH
%token COUNT
%token COVAR_POP
%token COVAR_SAMP
%token CREATE
%token CROSS
%token CUBE
%token CUME_DIST
%token CURRENT
%token CURRENT_CATALOG
%token CURRENT_DATE
%token CURRENT_DEFAULT_TRANSFORM_GROUP
%token CURRENT_PATH
%token CURRENT_ROLE
%token CURRENT_ROW
%token CURRENT_SCHEMA
%token CURRENT_TIME
%token CURRENT_TIMESTAMP
%token CURRENT_PATH
%token CURRENT_ROLE
%token CURRENT_TRANSFORM_GROUP_FOR_TYPE
%token CURRENT_USER
%token CURSOR
%token CYCLE
%token DATE
%token DAY
%token DEALLOCATE
%token DEC
%token DECIMAL
%token DECFLOAT
%token DECLARE
%token DEFAULT
%token DEFINE
%token DELETE
%token DENSE_RANK
%token DEREF
%token DESCRIBE
%token DETERMINISTIC
%token DISCONNECT
%token DISTINCT
%token DOUBLE
%token DROP
%token DYNAMIC
%token EACH
%token ELEMENT
%token ELSE
%token EMPTY
%token END
%token END_FRAME
%token END_PARTITION
//%token END-EXEC
%token EQUALS
%token ESCAPE
%token EVERY
%token EXCEPT
%token EXEC
%token EXECUTE
%token EXISTS
%token EXP
%token EXTERNAL
%token EXTRACT
%token FALSE
%token FETCH
%token FILTER
%token FIRST_VALUE
%token FLOAT
%token FLOOR
%token FOR
%token FOREIGN
%token FRAME_ROW
%token FREE
%token FROM
%token FULL
%token FUNCTION
%token FUSION
%token GET
%token GLOBAL
%token GRANT
%token GROUP
%token GROUPING
%token GROUPS
%token HAVING
%token HOLD
%token HOUR
%token IDENTITY
%token IN
%token INDICATOR
%token INITIAL
%token INNER
%token INOUT
%token INSENSITIVE
%token INSERT
%token INT
%token INTEGER
%token INTERSECT
%token INTERSECTION
%token INTERVAL
%token INTO
%token IS
%token JOIN
%token JSON_ARRAY
%token JSON_ARRAYAGG
%token JSON_EXISTS
%token JSON_OBJECT
%token JSON_OBJECTAGG
%token JSON_QUERY
%token JSON_TABLE
%token JSON_TABLE_PRIMITIVE
%token JSON_VALUE
%token LAG
%token LANGUAGE
%token LARGE
%token LAST_VALUE
%token LATERAL
%token LEAD
%token LEADING
%token LEFT
%token LIKE
%token LIKE_REGEX
%token LISTAGG
%token LN
%token LOCAL
%token LOCALTIME
%token LOCALTIMESTAMP
%token LOG
%token LOG10
%token LOWER
%token MATCH
%token MATCH_NUMBER
%token MATCH_RECOGNIZE
%token MATCHES
%token MAX
%token MEMBER
%token MERGE
%token METHOD
%token MIN
%token MINUTE
%token MOD
%token MODIFIES
%token MODULE
%token MONTH
%token MULTISET
%token NATIONAL
%token NATURAL
%token NCHAR
%token NCLOB
%token NEW
%token NO
%token NONE
%token NORMALIZE
%token NOT
%token NTH_VALUE
%token NTILE
%token NULL
%token NULLIF
%token NUMERIC
%token OCTET_LENGTH
%token OCCURRENCES_REGEX
%token OF
%token OFFSET
%token OLD
%token OMIT
%token ON
%token ONE
%token ONLY
%token OPEN
%token OR
%token ORDER
%token OUT
%token OUTER
%token OVER
%token OVERLAPS
%token OVERLAY
%token PARAMETER
%token PARTITION
%token PATTERN
%token PER
%token PERCENT
%token PERCENT_RANK
%token PERCENTILE_CONT
%token PERCENTILE_DISC
%token PERIOD
%token PORTION
%token POSITION
%token POSITION_REGEX
%token POWER
%token PRECEDES
%token PRECISION
%token PREPARE
%token PRIMARY
%token PROCEDURE
%token PTF
%token RANGE
%token RANK
%token READS
%token REAL
%token RECURSIVE
%token REF
%token REFERENCES
%token REFERENCING
%token REGR_AVGX
%token REGR_AVGY
%token REGR_COUNT
%token REGR_INTERCEPT
%token REGR_R2
%token REGR_SLOPE
%token REGR_SXX
%token REGR_SXY
%token REGR_SYY
%token RELEASE
%token RESULT
%token RETURN
%token RETURNS
%token REVOKE
%token RIGHT
%token ROLLBACK
%token ROLLUP
%token ROW
%token ROW_NUMBER
%token ROWS
%token RUNNING
%token SAVEPOINT
%token SCOPE
%token SCROLL
%token SEARCH
%token SECOND
%token SEEK
%token SELECT
%token SENSITIVE
%token SESSION_USER
%token SET
%token SHOW
%token SIMILAR
%token SIN
%token SINH
%token SKIP
%token SMALLINT
%token SOME
%token SPECIFIC
%token SPECIFICTYPE
%token SQL
%token SQLEXCEPTION
%token SQLSTATE
%token SQLWARNING
%token SQRT
%token START
%token STATIC
%token STDDEV_POP
%token STDDEV_SAMP
%token SUBMULTISET
%token SUBSET
%token SUBSTRING
%token SUBSTRING_REGEX
%token SUCCEEDS
%token SUM
%token SYMMETRIC
%token SYSTEM
%token SYSTEM_TIME
%token SYSTEM_USER
%token TABLE
%token TABLESAMPLE
%token TAN
%token TANH
%token THEN
%token TIME
%token TIMESTAMP
%token TIMEZONE_HOUR
%token TIMEZONE_MINUTE
%token TO
%token TRAILING
%token TRANSLATE
%token TRANSLATE_REGEX
%token TRANSLATION
%token TREAT
%token TRIGGER
%token TRIM
%token TRIM_ARRAY
%token TRUE
%token TRUNCATE
%token UESCAPE
%token UNION
%token UNIQUE
%token UNKNOWN
%token UNNEST
%token UPDATE 
%token UPPER
%token USER
%token USING
%token VALUE
%token VALUES
%token VALUE_OF
%token VAR_POP
%token VAR_SAMP
%token VARBINARY
%token VARCHAR
%token VARYING
%token VERSIONING
%token WHEN
%token WHENEVER
%token WHERE
%token WIDTH_BUCKET
%token WINDOW
%token WITH
%token WITHIN
%token WITHOUT
%token YEAR

// operators
%token OPERATOR_EQUALS OPERATOR_LEFT_PAREN OPERATOR_RIGHT_PAREN;
%token OPERATOR_ASTERISK OPERATOR_COMMA OPERATOR_PLUS OPERATOR_MINUS;
%token OPERATOR_PERIOD OPERATOR_SOLIDUS OPERATOR_COLON OPERATOR_LESS_THAN;
%token OPERATOR_GREATER_THAN OPERATOR_DOUBLE_PIPE OPERATOR_NOT_EQUALS;
%token OPERATOR_GREATER_EQUALS OPERATOR_LESS_EQUALS OPERATOR_SEMICOLON;

%token OPERATOR_PERIOD_ASTERISK OPERATOR_LEFT_PAREN_ASTERISK;

// literals
%token LITERAL_IDENTIFIER LITERAL_STRING LITERAL_NUMBER;
%token E

// pseudo keywords
%token IS_TRUE IS_FALSE IS_UNKNOWN IS_NOT_TRUE IS_NOT_FALSE IS_NOT_UNKNOWN;

%start start;

%%

// This is a special case that uses `yyrcvr.lval` to make sure the parser
// captures the final result.
start:
  preparable_statement { yyrcvr.lval.v = $1.v as Stmt }

// 7.3 <table value constructor>

table_value_constructor:
  VALUES row_value_expression_list {
    $$.v = SimpleTable($2.v as []RowValueConstructor)
  }

row_value_expression_list:
  table_row_value_expression { $$.v = [$1.v as RowValueConstructor] }
| row_value_expression_list comma table_row_value_expression {
    $$.v = append_list($1.v as []RowValueConstructor,
      $3.v as RowValueConstructor)
  }

contextually_typed_table_value_constructor:
  VALUES contextually_typed_row_value_expression_list {
    $$.v = $2.v as []ContextuallyTypedRowValueConstructor
  }

contextually_typed_row_value_expression_list:
  contextually_typed_row_value_expression {
    $$.v = [$1.v as ContextuallyTypedRowValueConstructor]
  }
| contextually_typed_row_value_expression_list comma
  contextually_typed_row_value_expression {
    $$.v = append_list($1.v as []ContextuallyTypedRowValueConstructor,
      $3.v as ContextuallyTypedRowValueConstructor)
  }

// 11.74 <drop sequence generator statement>

drop_sequence_generator_statement:
  DROP SEQUENCE sequence_generator_name {
    $$.v = Stmt(DropSequenceGeneratorStatement{$3.v as Identifier})
  }

// 14.8 <delete statement: positioned>

target_table:
  table_name { $$.v = $1.v as Identifier }

// 20.7 <prepare statement>

preparable_statement:
  preparable_sql_data_statement { $$.v = $1.v as Stmt }
| preparable_sql_schema_statement { $$.v = $1.v as Stmt }
| preparable_sql_transaction_statement { $$.v = $1.v as Stmt }
| preparable_sql_session_statement { $$.v = $1.v as Stmt }

preparable_sql_data_statement:
  delete_statement_searched { $$.v = $1.v as Stmt }
| insert_statement { $$.v = $1.v as Stmt }
| dynamic_select_statement { $$.v = $1.v as Stmt }
| update_statement_searched { $$.v = $1.v as Stmt }

preparable_sql_schema_statement:
  sql_schema_statement { $$.v = $1.v as Stmt }

preparable_sql_transaction_statement:
  sql_transaction_statement { $$.v = $1.v as Stmt }

preparable_sql_session_statement:
  sql_session_statement { $$.v = $1.v as Stmt }

// 6.12 <case expression>

case_expression /* CaseExpression */ :
    case_abbreviation { $$.v = $1.v as CaseExpression }

case_abbreviation /* CaseExpression */ :
  NULLIF left_paren value_expression comma value_expression right_paren {
    $$.v = CaseExpression(CaseExpressionNullIf{$3.v as ValueExpression, $5.v as ValueExpression})
  }
| COALESCE left_paren value_expression_list right_paren {
    $$.v = CaseExpression(CaseExpressionCoalesce{$3.v as []ValueExpression})
  }

value_expression_list:
  value_expression { $$.v = [$1.v as ValueExpression] }
| value_expression_list comma value_expression {
    $$.v = append_list($1.v as []ValueExpression, $3.v as ValueExpression)
  }

// 11.73 <alter sequence generator statement>

alter_sequence_generator_statement:
  ALTER SEQUENCE sequence_generator_name alter_sequence_generator_options {
    $$.v = AlterSequenceGeneratorStatement{
      name:    $3.v as Identifier
      options: $4.v as []SequenceGeneratorOption
    }
  }

alter_sequence_generator_options:
  alter_sequence_generator_option { $$.v = [$1.v as SequenceGeneratorOption] }
| alter_sequence_generator_options alter_sequence_generator_option {
    $$.v = append_list($1.v as []SequenceGeneratorOption, $2.v as SequenceGeneratorOption)
  }

alter_sequence_generator_option:
  alter_sequence_generator_restart_option {
    $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorRestartOption)
  }
| basic_sequence_generator_option { $$.v = $1.v as SequenceGeneratorOption }

alter_sequence_generator_restart_option:
  RESTART { $$.v = SequenceGeneratorRestartOption{} }
| RESTART WITH sequence_generator_restart_value {
    $$.v = SequenceGeneratorRestartOption{
      restart_value: $3.v as Value
    }
  }

sequence_generator_restart_value /* Value */ :
  signed_numeric_literal { $$.v = $1.v as Value }

commit_statement:
  COMMIT { $$.v = Stmt(CommitStatement{}) }
| COMMIT WORK { $$.v = Stmt(CommitStatement{}) }

sort_specification_list:
  sort_specification { $$.v = [$1.v as SortSpecification] }
| sort_specification_list comma sort_specification {
    $$.v = append_list($1.v as []SortSpecification, $3.v as SortSpecification)
  }

sort_specification:
  sort_key { $$.v = SortSpecification{$1.v as ValueExpression, true} }
| sort_key ordering_specification {
    $$.v = SortSpecification{$1.v as ValueExpression, $2.v as bool}
  }

sort_key /* ValueExpression */ :
    value_expression { $$.v = $1.v as ValueExpression }

ordering_specification:
  ASC { $$.v = true }
| DESC { $$.v = false }

row_subquery /* QueryExpression */ :
    subquery { $$.v = $1.v as QueryExpression }

table_subquery /* TablePrimary */ :
    subquery { $$.v = $1.v as TablePrimary }

subquery:
  left_paren query_expression right_paren {
    $$.v = TablePrimary{
      body: $2.v as QueryExpression
    }
  }

set_clause_list:
  set_clause { $$.v = $1.v as map[string]UpdateSource }
| set_clause_list comma set_clause {
    $$.v = merge_maps($1.v as map[string]UpdateSource, $3.v as map[string]UpdateSource)
  }

set_clause:
  set_target equals_operator update_source {
    $$.v = {
      ($1.v as Identifier).str(): $3.v as UpdateSource
    }
  }

set_target:
  update_target { $$.v = $1.v as Identifier }

update_target:
  object_column { $$.v = $1.v as Identifier }

update_source:
  value_expression { $$.v = UpdateSource($1.v as ValueExpression) }
| contextually_typed_value_specification {
    $$.v = UpdateSource($1.v as NullSpecification)
  }

object_column:
  column_name { $$.v = $1.v as Identifier }

delete_statement_searched:
  DELETE FROM target_table {
    $$.v = Stmt(DeleteStatementSearched{$3.v as Identifier, none})
  }
| DELETE FROM target_table WHERE search_condition {
    $$.v = Stmt(DeleteStatementSearched{$3.v as Identifier, $5.v as BooleanValueExpression})  
  }

table_definition:
  CREATE TABLE table_name table_contents_source {
    $$.v = Stmt(TableDefinition{$3.v as Identifier, $4.v as []TableElement})
  }

table_contents_source:
  table_element_list { $$.v = $1.v as []TableElement }

table_element_list:
  left_paren table_elements right_paren { $$.v = $2.v as []TableElement }

table_element /* TableElement */ :
    column_definition { $$.v = $1.v as TableElement }
  | table_constraint_definition { $$.v = $1.v as TableElement }

table_elements:
  table_element { $$.v = [$1.v as TableElement] }
| table_elements comma table_element {
    $$.v = append_list($1.v as []TableElement, $3.v as TableElement)
  }

dynamic_select_statement:
  cursor_specification { $$.v = $1.v as Stmt }

schema_definition:
  CREATE SCHEMA schema_name_clause {
    $$.v = Stmt(SchemaDefinition{$3.v as Identifier})
  }

schema_name_clause:
  schema_name { $$.v = $1.v as Identifier }

cursor_specification:
  query_expression { $$.v = Stmt($1.v as QueryExpression) }

datetime_value_expression /* DatetimePrimary */ :
    datetime_term { $$.v = $1.v as DatetimePrimary }

datetime_term /* DatetimePrimary */ :
    datetime_factor { $$.v = $1.v as DatetimePrimary }

datetime_factor /* DatetimePrimary */ :
    datetime_primary { $$.v = $1.v as DatetimePrimary }

datetime_primary:
  value_expression_primary {
    $$.v = DatetimePrimary($1.v as ValueExpressionPrimary)
  }
| datetime_value_function {
    $$.v = DatetimePrimary($1.v as DatetimeValueFunction)
  }

update_statement_searched:
  UPDATE target_table SET set_clause_list {
	  $$.v = Stmt(UpdateStatementSearched{$2.v as Identifier,
      $4.v as map[string]UpdateSource, none})
  }
| UPDATE target_table SET set_clause_list WHERE search_condition {
    $$.v = Stmt(UpdateStatementSearched{$2.v as Identifier,
      $4.v as map[string]UpdateSource, $6.v as BooleanValueExpression})
  }

identifier_chain:
  identifier { $$.v = $1.v as IdentifierChain }
| identifier period identifier {
    $$.v = IdentifierChain{
      ($1.v as IdentifierChain).identifier + '.' + ($3.v as IdentifierChain).identifier
    }
  }

basic_identifier_chain /* IdentifierChain */ :
  identifier_chain { $$.v = $1.v as IdentifierChain }

cast_specification:
  CAST left_paren cast_operand AS cast_target right_paren {
	  $$.v = CastSpecification{$3.v as CastOperand, $5.v as Type}
  }

cast_operand:
  value_expression { $$.v = CastOperand($1.v as ValueExpression) }
| implicitly_typed_value_specification {
    $$.v = CastOperand($1.v as NullSpecification)
  }

cast_target /* Type */ :
  data_type { $$.v = $1.v as Type }

rollback_statement:
  ROLLBACK { $$.v = Stmt(RollbackStatement{}) }
| ROLLBACK WORK { $$.v = Stmt(RollbackStatement{}) }

next_value_expression:
  NEXT VALUE FOR sequence_generator_name {
    $$.v = NextValueExpression{
      name: $4.v as Identifier
    }
  }

where_clause:
  WHERE search_condition { $$.v = $2.v as BooleanValueExpression }

literal:
    signed_numeric_literal { $$.v = $1.v as Value }
  | general_literal { $$.v = $1.v as Value }

unsigned_literal:
    unsigned_numeric_literal { $$.v = $1.v as Value }
  | general_literal { $$.v = $1.v as Value }

general_literal:
    character_string_literal { $$.v = $1.v as Value }
  | datetime_literal { $$.v = $1.v as Value }
  | boolean_literal { $$.v = $1.v as Value }

character_string_literal /* Value */ :
    LITERAL_STRING { $$.v = $1.v as Value }

signed_numeric_literal:
  unsigned_numeric_literal { $$.v = $1.v as Value }
| sign unsigned_numeric_literal {
    $$.v = numeric_literal($1.v as string + ($2.v as Value).str())!
  }

unsigned_numeric_literal /* Value */ :
    exact_numeric_literal { $$.v = $1.v as Value }
  | approximate_numeric_literal { $$.v = $1.v as Value }

exact_numeric_literal:
  unsigned_integer { $$.v = numeric_literal($1.v as string)! }
| unsigned_integer period { $$.v = numeric_literal(($1.v as string) + '.')! }
| unsigned_integer period unsigned_integer {
    $$.v = numeric_literal(($1.v as string) + '.' + ($3.v as string))!
  }
| period unsigned_integer { $$.v = numeric_literal('0.' + ($2.v as string))! }

sign /* string */ :
  plus_sign { $$.v = $1.v as string }
| minus_sign { $$.v = $1.v as string }

approximate_numeric_literal:
  mantissa E exponent {
    $$.v = new_double_precision_value(
      ($1.v as Value).as_f64()! * math.pow(10, ($3.v as Value).as_f64()!))
  }

mantissa /* Value */ :
  exact_numeric_literal { $$.v = $1.v as Value }

exponent /* Value */ :
  signed_integer { $$.v = $1.v as Value }

signed_integer:
  unsigned_integer { $$.v = new_numeric_value($1.v as string) }
| sign unsigned_integer {
    $$.v = if $1.v as string == '-' {
      new_numeric_value('-' + ($2.v as string))
    } else {
      new_numeric_value($2.v as string)
    }
  }

unsigned_integer:
  LITERAL_NUMBER { $$.v = $1.v as string }

datetime_literal /* Value */ :
    date_literal { $$.v = $1.v as Value }
  | time_literal { $$.v = $1.v as Value }
  | timestamp_literal { $$.v = $1.v as Value }

date_literal:
  DATE date_string { $$.v = new_date_value(($2.v as Value).string_value())! }

time_literal:
  TIME time_string { $$.v = new_time_value(($2.v as Value).string_value())! }

timestamp_literal:
  TIMESTAMP timestamp_string {
    $$.v = new_timestamp_value(($2.v as Value).string_value())!
  }

date_string /* Value */ :
    LITERAL_STRING { $$.v = $1.v as Value }

time_string /* Value */ :
    LITERAL_STRING { $$.v = $1.v as Value }

timestamp_string /* Value */ :
    LITERAL_STRING { $$.v = $1.v as Value }

boolean_literal:
  TRUE { $$.v = new_boolean_value(true) }
| FALSE { $$.v = new_boolean_value(false) }
| UNKNOWN { $$.v = new_unknown_value() }

contextually_typed_value_specification /* NullSpecification */ :
    implicitly_typed_value_specification { $$.v = $1.v as NullSpecification }

implicitly_typed_value_specification /* NullSpecification */ :
    null_specification { $$.v = $1.v as NullSpecification }

null_specification:
  NULL { $$.v = NullSpecification{} }

from_clause /* TableReference */ :
    FROM table_reference_list { $$.v = $2.v as TableReference }

table_reference_list /* TableReference */ :
    table_reference { $$.v = $1.v as TableReference }

between_predicate:
  row_value_predicand between_predicate_part_2 {
    between := $2.v as BetweenPredicate
    $$.v = BetweenPredicate{
      not:       between.not
      symmetric: between.symmetric
      expr:      $1.v as RowValueConstructorPredicand
      left:      between.left
      right:     between.right
    }
  }

between_predicate_part_2:
  between_predicate_part_1 row_value_predicand AND row_value_predicand {
    $$.v = BetweenPredicate{
      not:       !($1.v as bool)
      symmetric: false
      left:      $2.v as RowValueConstructorPredicand
      right:     $4.v as RowValueConstructorPredicand
    }
  }
| between_predicate_part_1 is_symmetric row_value_predicand AND
  row_value_predicand {
    $$.v = BetweenPredicate{
      not:       !($1.v as bool)
      symmetric: $2.v as bool
      left:      $3.v as RowValueConstructorPredicand
      right:     $5.v as RowValueConstructorPredicand
    }
  }

between_predicate_part_1:
    BETWEEN       { $$.v = true }
  | NOT BETWEEN   { $$.v = false }

is_symmetric:
    SYMMETRIC    { $$.v = true }
  | ASYMMETRIC   { $$.v = false }

identifier /* IdentifierChain */ :
    actual_identifier { $$.v = $1.v as IdentifierChain }

actual_identifier /* IdentifierChain */ :
    regular_identifier { $$.v = $1.v as IdentifierChain }

table_name /* Identifier */ :
    local_or_schema_qualified_name   { $$.v = new_table_identifier(($1.v as IdentifierChain).identifier)! }

schema_name /* Identifier */ :
    catalog_name period unqualified_schema_name   {
      $$.v = new_schema_identifier(($1.v as IdentifierChain).str() + '.' + ($3.v as Identifier).str())!
    }
  | unqualified_schema_name { $$.v = $1.v as Identifier }

unqualified_schema_name /* Identifier */ :
    identifier   { $$.v = new_schema_identifier(($1.v as IdentifierChain).identifier)! }

catalog_name /* IdentifierChain */ :
    identifier { $$.v = $1.v as IdentifierChain }

schema_qualified_name /* IdentifierChain */ :
    qualified_identifier { $$.v = $1.v as IdentifierChain }
  | schema_name period qualified_identifier   {
    $$.v = IdentifierChain{($1.v as Identifier).schema_name + '.' + ($3.v as IdentifierChain).str()}
    }

local_or_schema_qualified_name /* IdentifierChain */ :
    qualified_identifier { $$.v = $1.v as IdentifierChain }
  | local_or_schema_qualifier period
    qualified_identifier                 {
    $$.v = IdentifierChain{($1.v as Identifier).str() + '.' + ($3.v as IdentifierChain).str()}
    }

local_or_schema_qualifier /* Identifier */ :
    schema_name { $$.v = $1.v as Identifier }

qualified_identifier /* IdentifierChain */ :
    identifier { $$.v = $1.v as IdentifierChain }

column_name /* Identifier */ :
    identifier   { $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)! }

host_parameter_name:
    colon identifier   { $$.v = GeneralValueSpecification(HostParameterName{($2.v as IdentifierChain).identifier}) }

correlation_name /* Identifier */ :
    identifier   { $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)! }

sequence_generator_name /* Identifier */ :
    schema_qualified_name   { $$.v = new_table_identifier(($1.v as IdentifierChain).identifier)! }

drop_schema_statement /* Stmt */ :
    DROP SCHEMA schema_name drop_behavior   { $$.v = Stmt(DropSchemaStatement{$3.v as Identifier, $4.v as string}) }

drop_behavior /* string */ :
    CASCADE { $$.v = $1.v as string }
  | RESTRICT { $$.v = $1.v as string }

numeric_value_function /* RoutineInvocation */ :
    position_expression { $$.v = $1.v as RoutineInvocation }
  | length_expression { $$.v = $1.v as RoutineInvocation }
  | absolute_value_expression { $$.v = $1.v as RoutineInvocation }
  | modulus_expression { $$.v = $1.v as RoutineInvocation }
  | trigonometric_function { $$.v = $1.v as RoutineInvocation }
  | common_logarithm { $$.v = $1.v as RoutineInvocation }
  | natural_logarithm { $$.v = $1.v as RoutineInvocation }
  | exponential_function { $$.v = $1.v as RoutineInvocation }
  | power_function { $$.v = $1.v as RoutineInvocation }
  | square_root { $$.v = $1.v as RoutineInvocation }
  | floor_function { $$.v = $1.v as RoutineInvocation }
  | ceiling_function { $$.v = $1.v as RoutineInvocation }

position_expression /* RoutineInvocation */ :
    character_position_expression { $$.v = $1.v as RoutineInvocation }

character_position_expression /* RoutineInvocation */ :
    POSITION left_paren character_value_expression_1 IN
    character_value_expression_2 right_paren              {
      $$.v = RoutineInvocation{'POSITION', [
        ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
        ValueExpression(CommonValueExpression($5.v as CharacterValueExpression)),
      ]} }

character_value_expression_1 /* CharacterValueExpression */ :
    character_value_expression { $$.v = $1.v as CharacterValueExpression }

character_value_expression_2 /* CharacterValueExpression */ :
    character_value_expression { $$.v = $1.v as CharacterValueExpression }

length_expression /* RoutineInvocation */ :
    char_length_expression { $$.v = $1.v as RoutineInvocation }
  | octet_length_expression { $$.v = $1.v as RoutineInvocation }

char_length_expression /* RoutineInvocation */ :
    CHAR_LENGTH
    left_paren character_value_expression right_paren   { $$.v = RoutineInvocation{'CHAR_LENGTH', [
		ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
	]} }
  | CHARACTER_LENGTH
    left_paren character_value_expression right_paren   { $$.v = RoutineInvocation{'CHAR_LENGTH', [
		ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
	]} }

octet_length_expression /* RoutineInvocation */ :
    OCTET_LENGTH
    left_paren string_value_expression right_paren   { $$.v = RoutineInvocation{'OCTET_LENGTH', [
		ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
	]} }

absolute_value_expression /* RoutineInvocation */ :
    ABS left_paren numeric_value_expression right_paren   {
      $$.v = RoutineInvocation{'ABS', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]} }

modulus_expression /* RoutineInvocation */ :
    MOD left_paren numeric_value_expression_dividend comma
    numeric_value_expression_divisor right_paren               { 
      $$.v = RoutineInvocation{'MOD', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
		ValueExpression(CommonValueExpression($5.v as NumericValueExpression))]}
     }

numeric_value_expression_dividend /* NumericValueExpression */ :
    numeric_value_expression { $$.v = $1.v as NumericValueExpression }

numeric_value_expression_divisor /* NumericValueExpression */ :
    numeric_value_expression { $$.v = $1.v as NumericValueExpression }

trigonometric_function /* RoutineInvocation */ :
    trigonometric_function_name
    left_paren numeric_value_expression
    right_paren                             {
      $$.v = RoutineInvocation{$1.v as string, [
        ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
      ]}
  }

trigonometric_function_name:
  SIN { $$.v = $1.v as string }
| COS { $$.v = $1.v as string }
| TAN { $$.v = $1.v as string }
| SINH { $$.v = $1.v as string }
| COSH { $$.v = $1.v as string }
| TANH { $$.v = $1.v as string }
| ASIN { $$.v = $1.v as string }
| ACOS { $$.v = $1.v as string }
| ATAN { $$.v = $1.v as string }

common_logarithm /* RoutineInvocation */ :
    LOG10 left_paren numeric_value_expression right_paren   {
      $$.v = RoutineInvocation{'LOG10', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]}
      }

natural_logarithm /* RoutineInvocation */ :
    LN left_paren numeric_value_expression right_paren   {
      $$.v = RoutineInvocation{'LN', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]}
      }

exponential_function /* RoutineInvocation */ :
    EXP left_paren numeric_value_expression right_paren   {
      $$.v = RoutineInvocation{'EXP', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]}
      }

power_function /* RoutineInvocation */ :
    POWER left_paren numeric_value_expression_base comma
    numeric_value_expression_exponent right_paren            {
      $$.v = RoutineInvocation{'POWER', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
		ValueExpression(CommonValueExpression($5.v as NumericValueExpression))]}
    }

numeric_value_expression_base /* NumericValueExpression */ :
    numeric_value_expression { $$.v = $1.v as NumericValueExpression }

numeric_value_expression_exponent /* NumericValueExpression */ :
    numeric_value_expression { $$.v = $1.v as NumericValueExpression }

square_root /* RoutineInvocation */ :
    SQRT left_paren numeric_value_expression right_paren   { 
      $$.v = RoutineInvocation{'SQRT', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]}
      }

floor_function /* RoutineInvocation */ :
    FLOOR left_paren numeric_value_expression right_paren   { 
      $$.v = RoutineInvocation{'FLOOR', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]}
       }

ceiling_function /* RoutineInvocation */ :
    CEIL left_paren numeric_value_expression right_paren      { 
      $$.v = RoutineInvocation{'CEILING', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]}
       }
  | CEILING left_paren numeric_value_expression right_paren   { 
      $$.v = RoutineInvocation{'CEILING', [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]}
       }

concatenation_operator:
  OPERATOR_DOUBLE_PIPE

regular_identifier:
    identifier_body { $$.v = $1.v as IdentifierChain }
  | non_reserved_word   { $$.v = IdentifierChain{$1.v as string} }

identifier_body /* IdentifierChain */ :
    identifier_start { $$.v = $1.v as IdentifierChain }

identifier_start /* IdentifierChain */ :
    LITERAL_IDENTIFIER { $$.v = $1.v as IdentifierChain }

not_equals_operator : OPERATOR_NOT_EQUALS

greater_than_or_equals_operator : OPERATOR_GREATER_EQUALS

less_than_or_equals_operator : OPERATOR_LESS_EQUALS

non_reserved_word:
  A
| ABSOLUTE
| ACTION
| ADA
| ADD
| ADMIN
| AFTER
| ALWAYS
| ASC
| ASSERTION
| ASSIGNMENT
| ATTRIBUTE
| ATTRIBUTES
| BEFORE
| BERNOULLI
| BREADTH
| C
| CASCADE
| CATALOG
| CATALOG_NAME
| CHAIN
| CHAINING
| CHARACTER_SET_CATALOG
| CHARACTER_SET_NAME
| CHARACTER_SET_SCHEMA
| CHARACTERISTICS
| CHARACTERS
| CLASS_ORIGIN
| COBOL
| COLLATION
| COLLATION_CATALOG
| COLLATION_NAME
| COLLATION_SCHEMA
| COLUMNS
| COLUMN_NAME
| COMMAND_FUNCTION
| COMMAND_FUNCTION_CODE
| COMMITTED
| CONDITIONAL
| CONDITION_NUMBER
| CONNECTION
| CONNECTION_NAME
| CONSTRAINT_CATALOG
| CONSTRAINT_NAME
| CONSTRAINT_SCHEMA
| CONSTRAINTS
| CONSTRUCTOR
| CONTINUE
| CURSOR_NAME
| DATA
| DATETIME_INTERVAL_CODE
| DATETIME_INTERVAL_PRECISION
| DEFAULTS
| DEFERRABLE
| DEFERRED
| DEFINED
| DEFINER
| DEGREE
| DEPTH
| DERIVED
| DESC
| DESCRIBE_CATALOG
| DESCRIBE_NAME
| DESCRIBE_PROCEDURE_SPECIFIC_CATALOG
| DESCRIBE_PROCEDURE_SPECIFIC_NAME
| DESCRIBE_PROCEDURE_SPECIFIC_SCHEMA
| DESCRIBE_SCHEMA
| DESCRIPTOR
| DIAGNOSTICS
| DISPATCH
| DOMAIN
| DYNAMIC_FUNCTION
| DYNAMIC_FUNCTION_CODE
| ENCODING
| ENFORCED
| ERROR
| EXCLUDE
| EXCLUDING
| EXPRESSION
| FINAL
| FINISH
| FINISH_CATALOG
| FINISH_NAME
| FINISH_PROCEDURE_SPECIFIC_CATALOG
| FINISH_PROCEDURE_SPECIFIC_NAME
| FINISH_PROCEDURE_SPECIFIC_SCHEMA
| FINISH_SCHEMA
| FIRST
| FLAG
| FOLLOWING
| FORMAT
| FORTRAN
| FOUND
| FULFILL
| FULFILL_CATALOG
| FULFILL_NAME
| FULFILL_PROCEDURE_SPECIFIC_CATALOG
| FULFILL_PROCEDURE_SPECIFIC_NAME
| FULFILL_PROCEDURE_SPECIFIC_SCHEMA
| FULFILL_SCHEMA
| G
| GENERAL
| GENERATED
| GO
| GOTO
| GRANTED
| HAS_PASS_THROUGH_COLUMNS
| HAS_PASS_THRU_COLS
| HIERARCHY
| IGNORE
| IMMEDIATE
| IMMEDIATELY
| IMPLEMENTATION
| INCLUDING
| INCREMENT
| INITIALLY
| INPUT
| INSTANCE
| INSTANTIABLE
| INSTEAD
| INVOKER
| ISOLATION
| IS_PRUNABLE
| JSON
| K
| KEEP
| KEY
| KEYS
| KEY_MEMBER
| KEY_TYPE
| LAST
| LENGTH
| LEVEL
| LOCATOR
| M
| MAP
| MATCHED
| MAXVALUE
| MESSAGE_LENGTH
| MESSAGE_OCTET_LENGTH
| MESSAGE_TEXT
| MINVALUE
| MORE
| MUMPS
| NAME
| NAMES
| NESTED
| NESTING
| NEXT
| NFC
| NFD
| NFKC
| NFKD
| NORMALIZED
| NULLABLE
| NULLS
| NUMBER
| OBJECT
| OCTETS
| OPTION
| OPTIONS
| ORDERING
| ORDINALITY
| OTHERS
| OUTPUT
| OVERFLOW
| OVERRIDING
| P
| PAD
| PARAMETER_MODE
| PARAMETER_NAME
| PARAMETER_ORDINAL_POSITION
| PARAMETER_SPECIFIC_CATALOG
| PARAMETER_SPECIFIC_NAME
| PARAMETER_SPECIFIC_SCHEMA
| PARTIAL
| PASCAL
| PASS
| PASSING
| PAST
| PATH
| PLACING
| PLAN
| PLI
| PRECEDING
| PRESERVE
| PRIOR
| PRIVATE
| PRIVATE_PARAMETERS
| PRIVATE_PARAMS_S
| PRIVILEGES
| PRUNE
| PUBLIC
| QUOTES
| READ
| RELATIVE
| REPEATABLE
| RESPECT
| RESTART
| RESTRICT
| RETURNED_CARDINALITY
| RETURNED_LENGTH
| RETURNED_OCTET_LENGTH
| RETURNED_SQLSTATE
| RETURNING
| RETURNS_ONLY_PASS_THROUGH
| RET_ONLY_PASS_THRU
| ROLE
| ROUTINE
| ROUTINE_CATALOG
| ROUTINE_NAME
| ROUTINE_SCHEMA
| ROW_COUNT
| SCALAR
| SCALE
| SCHEMA
| SCHEMA_NAME
| SCOPE_CATALOG
| SCOPE_NAME
| SCOPE_SCHEMA
| SECTION
| SECURITY
| SELF
| SEQUENCE
| SERIALIZABLE
| SERVER_NAME
| SESSION
| SETS
| SIMPLE
| SIZE
| SOURCE
| SPACE
| SPECIFIC_NAME
| START_CATALOG
| START_NAME
| START_PROCEDURE_SPECIFIC_CATALOG
| START_PROCEDURE_SPECIFIC_NAME
| START_PROCEDURE_SPECIFIC_SCHEMA
| START_SCHEMA
| STATE
| STATEMENT
| STRING
| STRUCTURE
| STYLE
| SUBCLASS_ORIGIN
| T
| TABLE_NAME
| TABLE_SEMANTICS
| TEMPORARY
| THROUGH
| TIES
| TOP_LEVEL_COUNT
| TRANSACTION
| TRANSACTION_ACTIVE
| TRANSACTIONS_COMMITTED
| TRANSACTIONS_ROLLED_BACK
| TRANSFORM
| TRANSFORMS
| TRIGGER_CATALOG
| TRIGGER_NAME
| TRIGGER_SCHEMA
| TYPE
| UNBOUNDED
| UNCOMMITTED
| UNCONDITIONAL
| UNDER
| UNNAMED
| USAGE
| USER_DEFINED_TYPE_CATALOG
| USER_DEFINED_TYPE_CODE
| USER_DEFINED_TYPE_NAME
| USER_DEFINED_TYPE_SCHEMA
| UTF16
| UTF32
| UTF8
| VIEW
| WORK
| WRAPPER
| WRITE
| ZONE

data_type /* Type */ :
    predefined_type { $$.v = $1.v as Type }

predefined_type /* Type */ :
    character_string_type { $$.v = $1.v as Type }
  | numeric_type { $$.v = $1.v as Type }
  | boolean_type { $$.v = $1.v as Type }
  | datetime_type { $$.v = $1.v as Type }

character_string_type /* Type */ :
    CHARACTER                                                         { $$.v = new_type('CHARACTER', 1, 0) }
  | CHARACTER left_paren character_length right_paren           { $$.v = new_type('CHARACTER', ($3.v as string).int(), 0) }
  | CHAR                                                              { $$.v = new_type('CHARACTER', 1, 0) }
  | CHAR left_paren character_length right_paren                { $$.v = new_type('CHARACTER', ($3.v as string).int(), 0) }
  | CHARACTER VARYING left_paren character_length right_paren   { $$.v = new_type('CHARACTER VARYING', ($4.v as string).int(), 0) }
  | CHAR VARYING left_paren character_length right_paren        { $$.v = new_type('CHARACTER VARYING', ($4.v as string).int(), 0) }
  | VARCHAR left_paren character_length right_paren             { $$.v = new_type('CHARACTER VARYING', ($3.v as string).int(), 0) }

numeric_type /* Type */ :
    exact_numeric_type { $$.v = $1.v as Type }
  | approximate_numeric_type { $$.v = $1.v as Type }

exact_numeric_type /* Type */ :
    NUMERIC                                                          { $$.v = new_type('NUMERIC', 0, 0) }
  | NUMERIC left_paren precision right_paren                   { $$.v = new_type('NUMERIC', ($3.v as string).int(), 0) }
  | NUMERIC left_paren precision comma scale right_paren   { $$.v = new_type('NUMERIC', ($3.v as string).int(), ($5.v as string).i16()) }
  | DECIMAL                                                          { $$.v = new_type('DECIMAL', 0, 0) }
  | DECIMAL left_paren precision right_paren                   { $$.v = new_type('DECIMAL', ($3.v as string).int(), 0) }
  | DECIMAL left_paren precision comma scale right_paren   { $$.v = new_type('DECIMAL', ($3.v as string).int(), ($5.v as string).i16()) }
  | SMALLINT                                                         { $$.v = new_type('SMALLINT', 0, 0) }
  | INTEGER                                                          { $$.v = new_type('INTEGER', 0, 0) }
  | INT                                                              { $$.v = new_type('INTEGER', 0, 0) }
  | BIGINT                                                           { $$.v = new_type('BIGINT', 0, 0) }

approximate_numeric_type /* Type */ :
    FLOAT                                          { $$.v = new_type('FLOAT', 0, 0) }
  | FLOAT left_paren precision right_paren   { $$.v = new_type('FLOAT', ($3.v as string).int(), 0) }
  | REAL                                           { $$.v = new_type('REAL', 0, 0) }
  | DOUBLE PRECISION                               { $$.v = new_type('DOUBLE PRECISION', 0, 0) }

length:
  unsigned_integer { $$.v = $1.v as string }

character_length:
  length { $$.v = $1.v as string }

char_length_units /* string */ :
    CHARACTERS { $$.v = $1.v as string }
  | OCTETS { $$.v = $1.v as string }

precision /* string */ :
    unsigned_integer { $$.v = $1.v as string }

scale /* string */ :
    unsigned_integer { $$.v = $1.v as string }

boolean_type /* Type */ :
    BOOLEAN   { $$.v = new_type('BOOLEAN', 0, 0) }

datetime_type /* Type */ :
    DATE                                               { $$.v = new_type('DATE', 0, 0) }
  | TIME                                               { $$.v = parse_time_prec_tz_type('0', false)! }
  | TIME left_paren time_precision right_paren   { $$.v = parse_time_prec_tz_type($3.v as string, false)! }
  | TIME with_or_without_time_zone                   { $$.v = parse_time_prec_tz_type('0', $2.v as bool)! }
  | TIME left_paren time_precision right_paren
    with_or_without_time_zone                        { $$.v = parse_time_prec_tz_type($3.v as string, $5.v as bool)! }
  | TIMESTAMP                                          { $$.v = parse_timestamp_prec_tz_type('0', false)! }
  | TIMESTAMP
    left_paren timestamp_precision right_paren   { $$.v = parse_timestamp_prec_tz_type($3.v as string, false)! }
  | TIMESTAMP with_or_without_time_zone              {
    // ISO/IEC 9075-2:2016(E), 6.1, 36) If <timestamp precision> is not
    // specified, then 6 is implicit.
    $$.v = parse_timestamp_prec_tz_type('6', $2.v as bool)!
  }
  | TIMESTAMP
    left_paren timestamp_precision right_paren
    with_or_without_time_zone                        { $$.v = parse_timestamp_prec_tz_type($3.v as string, $5.v as bool)! }

with_or_without_time_zone:
    WITH TIME ZONE      { $$.v = true }
  | WITHOUT TIME ZONE   { $$.v = false }

time_precision /* string */ :
    time_fractional_seconds_precision { $$.v = $1.v as string }

timestamp_precision /* string */ :
    time_fractional_seconds_precision { $$.v = $1.v as string }

time_fractional_seconds_precision /* string */ :
    unsigned_integer { $$.v = $1.v as string }

like_predicate /* CharacterLikePredicate */ :
    character_like_predicate { $$.v = $1.v as CharacterLikePredicate }

character_like_predicate /* CharacterLikePredicate */ :
    row_value_predicand character_like_predicate_part_2   {
      like := $2.v as CharacterLikePredicate
      $$.v = CharacterLikePredicate{$1.v as RowValueConstructorPredicand, like.right, like.not}
      }

character_like_predicate_part_2 /* CharacterLikePredicate */ :
    LIKE character_pattern       { $$.v = CharacterLikePredicate{none, $2.v as CharacterValueExpression, false} }
  | NOT LIKE character_pattern   { $$.v = CharacterLikePredicate{none, $3.v as CharacterValueExpression, true} }

character_pattern /* CharacterValueExpression */ :
    character_value_expression { $$.v = $1.v as CharacterValueExpression }

comparison_predicate /* ComparisonPredicate */ :
    row_value_predicand comparison_predicate_part_2   {
      comp := $2.v as ComparisonPredicatePart2
        $$.v = ComparisonPredicate{$1.v as RowValueConstructorPredicand, comp.op, comp.expr}
      }

comparison_predicate_part_2 /* ComparisonPredicatePart2 */ :
    comp_op row_value_predicand   { $$.v = ComparisonPredicatePart2{$1.v as string, $2.v as RowValueConstructorPredicand} }

comp_op /* string */ :
    equals_operator { $$.v = $1.v as string }
  | not_equals_operator { $$.v = $1.v as string }
  | less_than_operator { $$.v = $1.v as string }
  | greater_than_operator { $$.v = $1.v as string }
  | less_than_or_equals_operator { $$.v = $1.v as string }
  | greater_than_or_equals_operator { $$.v = $1.v as string }

row_value_constructor:
    common_value_expression          { $$.v = RowValueConstructor($1.v as CommonValueExpression) }
  | boolean_value_expression { $$.v = RowValueConstructor($1.v as BooleanValueExpression) }
  | explicit_row_value_constructor   { $$.v = RowValueConstructor($1.v as ExplicitRowValueConstructor) }

explicit_row_value_constructor:
    ROW left_paren row_value_constructor_element_list
    right_paren                                           { $$.v = ExplicitRowValueConstructor(ExplicitRowValueConstructorRow{$3.v as []ValueExpression}) }
  | row_subquery                                          { $$.v = ExplicitRowValueConstructor($1.v as QueryExpression) }

row_value_constructor_element_list /* []ValueExpression */ :
    row_value_constructor_element                { $$.v = [$1.v as ValueExpression] }
  | row_value_constructor_element_list comma
    row_value_constructor_element                { $$.v = append_list($1.v as []ValueExpression, $3.v as ValueExpression) }

row_value_constructor_element:
    value_expression { $$.v = $1.v as ValueExpression }

contextually_typed_row_value_constructor /* ContextuallyTypedRowValueConstructor */ :
    common_value_expression                        { $$.v = ContextuallyTypedRowValueConstructor($1.v as CommonValueExpression) }
  | boolean_value_expression                       { $$.v = ContextuallyTypedRowValueConstructor($1.v as BooleanValueExpression) }
  | contextually_typed_value_specification         { $$.v = ContextuallyTypedRowValueConstructor($1.v as NullSpecification) }
  | left_paren contextually_typed_value_specification
    right_paren                                    { $$.v = ContextuallyTypedRowValueConstructor($2.v as NullSpecification) }
  | left_paren
    contextually_typed_row_value_constructor_element comma
    contextually_typed_row_value_constructor_element_list
    right_paren                                    { $$.v = ContextuallyTypedRowValueConstructor(push_list($2.v as ContextuallyTypedRowValueConstructorElement, $4.v as []ContextuallyTypedRowValueConstructorElement)) }

contextually_typed_row_value_constructor_element_list /* []ContextuallyTypedRowValueConstructorElement */ :
    contextually_typed_row_value_constructor_element        { $$.v = [$1.v as ContextuallyTypedRowValueConstructorElement] }
  | contextually_typed_row_value_constructor_element_list
    comma
    contextually_typed_row_value_constructor_element        { $$.v = append_list($1.v as []ContextuallyTypedRowValueConstructorElement, $3.v as ContextuallyTypedRowValueConstructorElement) }

contextually_typed_row_value_constructor_element /* ContextuallyTypedRowValueConstructorElement */ :
    value_expression                         { $$.v = ContextuallyTypedRowValueConstructorElement($1.v as ValueExpression) }
  | contextually_typed_value_specification   { $$.v = ContextuallyTypedRowValueConstructorElement($1.v as NullSpecification) }

row_value_constructor_predicand /* RowValueConstructorPredicand */ :
    common_value_expression   { $$.v = RowValueConstructorPredicand($1.v as CommonValueExpression) }
  | boolean_predicand         { $$.v = RowValueConstructorPredicand($1.v as BooleanPredicand) }

query_specification:
  SELECT select_list table_expression {
    $$.v = QuerySpecification{
      exprs:            $2.v as SelectList
      table_expression: $3.v as TableExpression
    }
  }

select_list:
    asterisk                               { $$.v = SelectList(AsteriskExpr(true)) }
  | select_sublist { $$.v = $1.v as SelectList }
  | select_list comma select_sublist   {
    mut new_select_list := (($1.v as SelectList) as []DerivedColumn).clone()
    new_select_list << (($3.v as SelectList) as []DerivedColumn)[0]
    $$.v = SelectList(new_select_list)
  }

select_sublist /* SelectList */ :
    derived_column       { $$.v = SelectList([$1.v as DerivedColumn]) }
  | qualified_asterisk   { $$.v = SelectList($1.v as QualifiedAsteriskExpr) }

// was: asterisked_identifier_chain period asterisk
qualified_asterisk /* QualifiedAsteriskExpr */ :
    asterisked_identifier_chain OPERATOR_PERIOD_ASTERISK   {
      $$.v = QualifiedAsteriskExpr{new_column_identifier(($1.v as IdentifierChain).identifier)!}
      }

asterisked_identifier_chain:
  asterisked_identifier { $$.v = $1.v as IdentifierChain }

asterisked_identifier:
  identifier { $$.v = $1.v as IdentifierChain }

derived_column /* DerivedColumn */ :
    value_expression               { $$.v = DerivedColumn{$1.v as ValueExpression, Identifier{}} }
  | value_expression as_clause   { $$.v = DerivedColumn{$1.v as ValueExpression, $2.v as Identifier} }

as_clause /* Identifier */ :
    AS column_name { $$.v = $2.v as Identifier }
  | column_name { $$.v = $1.v as Identifier }

string_value_expression /* CharacterValueExpression */ :
    character_value_expression { $$.v = $1.v as CharacterValueExpression }

character_value_expression /* CharacterValueExpression */ :
    concatenation      { $$.v = CharacterValueExpression($1.v as Concatenation) }
  | character_factor   { $$.v = CharacterValueExpression($1.v as CharacterPrimary) }

concatenation /* Concatenation */ :
    character_value_expression
    concatenation_operator
    character_factor             { $$.v = Concatenation{$1.v as CharacterValueExpression, $3.v as CharacterPrimary} }

character_factor /* CharacterPrimary */ :
    character_primary { $$.v = $1.v as CharacterPrimary }

character_primary /* CharacterPrimary */ :
    value_expression_primary   { $$.v = CharacterPrimary($1.v as ValueExpressionPrimary) }
  | string_value_function      { $$.v = CharacterPrimary($1.v as CharacterValueFunction) }

set_function_specification /* AggregateFunction */ :
    aggregate_function { $$.v = $1.v as AggregateFunction }

table_reference /* TableReference */ :
    table_factor   { $$.v = TableReference($1.v as TablePrimary) }
  | joined_table   { $$.v = TableReference($1.v as QualifiedJoin) }

qualified_join /* QualifiedJoin */ :
    table_reference
    JOIN table_reference join_specification   {
      $$.v = QualifiedJoin{$1.v as TableReference, 'INNER', $3.v as TableReference, $4.v as BooleanValueExpression}
    }
  | table_reference join_type
    JOIN table_reference join_specification   {
      $$.v = QualifiedJoin{$1.v as TableReference, $2.v as string, $4.v as TableReference, $5.v as BooleanValueExpression}
    }

table_factor /* TablePrimary */ :
    table_primary { $$.v = $1.v as TablePrimary }

table_primary /* TablePrimary */ :
    table_or_query_name { 
      $$.v = TablePrimary{
        body: $1.v as Identifier
      }
     }
  | derived_table { $$.v = $1.v as TablePrimary }
  | derived_table correlation_or_recognition {
    $$.v = TablePrimary{
      body:        ($1.v as TablePrimary).body
      correlation: $2.v as Correlation
    }
  }

correlation_or_recognition /* Correlation */ :
    correlation_name                    {
      $$.v = Correlation{
        name: $1.v as Identifier
      }
    }
  | AS correlation_name                 {
    $$.v = Correlation{
      name: $2.v as Identifier
    }
  }
  | correlation_name
    parenthesized_derived_column_list   {
      $$.v = Correlation{
        name:    $1.v as Identifier
        columns: $2.v as []Identifier
      }
    }
  | AS correlation_name
    parenthesized_derived_column_list   {
      $$.v = Correlation{
        name:    $2.v as Identifier
        columns: $3.v as []Identifier
      }
    }

derived_table /* TablePrimary */ :
    table_subquery { $$.v = $1.v as TablePrimary }

table_or_query_name /* Identifier */ :
    table_name { $$.v = $1.v as Identifier }

derived_column_list /* []Identifier */ :
    column_name_list { $$.v = $1.v as []Identifier }

column_name_list /* []Identifier */ :
    column_name                              { $$.v = [$1.v as Identifier] }
  | column_name_list comma column_name   { $$.v = append_list($1.v as []Identifier, $3.v as Identifier) }

parenthesized_derived_column_list /* []Identifier */ :
    left_paren derived_column_list
    right_paren                        { $$.v = $2.v }

sequence_generator_definition /* Stmt */ :
    CREATE SEQUENCE
    sequence_generator_name                   {
      $$.v = SequenceGeneratorDefinition{
        name: $3.v as Identifier
      }
    }
  | CREATE SEQUENCE sequence_generator_name
    sequence_generator_options                {
      $$.v = SequenceGeneratorDefinition{
        name:    $3.v as Identifier
        options: $4.v as []SequenceGeneratorOption
      }
    }

sequence_generator_options /* []SequenceGeneratorOption */ :
    sequence_generator_option { $$.v = $1.v as []SequenceGeneratorOption }
  | sequence_generator_options sequence_generator_option { $$.v = $1.v as []SequenceGeneratorOption }

sequence_generator_option /* []SequenceGeneratorOption */ :
    common_sequence_generator_options { $$.v = $1.v as []SequenceGeneratorOption }

common_sequence_generator_options /* []SequenceGeneratorOption */ :
    common_sequence_generator_option    { $$.v = [$1.v as SequenceGeneratorOption] }
  | common_sequence_generator_options
    common_sequence_generator_option    { $$.v = append_list($1.v as []SequenceGeneratorOption, $2.v as SequenceGeneratorOption) }

common_sequence_generator_option /* SequenceGeneratorOption */ :
    sequence_generator_start_with_option   { $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorStartWithOption) }
  | basic_sequence_generator_option { $$.v = $1.v as SequenceGeneratorOption }

basic_sequence_generator_option /* SequenceGeneratorOption */ :
    sequence_generator_increment_by_option   { $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorIncrementByOption) }
  | sequence_generator_maxvalue_option       { $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorMaxvalueOption) }
  | sequence_generator_minvalue_option       { $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorMinvalueOption) }
  | sequence_generator_cycle_option          { $$.v = SequenceGeneratorOption(SequenceGeneratorCycleOption{$1.v as bool}) }

sequence_generator_start_with_option /* SequenceGeneratorStartWithOption */ :
    START WITH
    sequence_generator_start_value   {
      $$.v = SequenceGeneratorStartWithOption{
		start_value: $3.v as Value
	}
    }

sequence_generator_start_value /* Value */ :
    signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_increment_by_option /* SequenceGeneratorIncrementByOption */ :
    INCREMENT BY
    sequence_generator_increment   {
      $$.v = SequenceGeneratorIncrementByOption{
		increment_by: $3.v as Value
	}
    }

sequence_generator_increment /* Value */ :
    signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_maxvalue_option /* SequenceGeneratorMaxvalueOption */ :
    MAXVALUE
    sequence_generator_max_value   {
      $$.v = SequenceGeneratorMaxvalueOption{
        max_value: $2.v as Value
      }
    }
  | NO MAXVALUE                      { $$.v = SequenceGeneratorMaxvalueOption{} }

sequence_generator_max_value /* Value */ :
    signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_minvalue_option /* SequenceGeneratorMinvalueOption */ :
    MINVALUE
    sequence_generator_min_value   { $$.v = SequenceGeneratorMinvalueOption{
		min_value: $2.v as Value
	} }
  | NO MINVALUE                      { $$.v = SequenceGeneratorMinvalueOption{} }

sequence_generator_min_value /* Value */ :
    signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_cycle_option /* bool */ :
    CYCLE      { $$.v = true }
  | NO CYCLE   { $$.v = false }

search_condition /* BooleanValueExpression */ :
    boolean_value_expression { $$.v = $1.v as BooleanValueExpression }

value_expression:
    common_value_expression { $$.v = ValueExpression($1.v as CommonValueExpression) }
  | boolean_value_expression   { $$.v = ValueExpression($1.v as BooleanValueExpression) }

common_value_expression:
    numeric_value_expression { $$.v = CommonValueExpression($1.v as NumericValueExpression) }
  | string_value_expression     { $$.v = CommonValueExpression($1.v as CharacterValueExpression) }
  | datetime_value_expression   { $$.v = CommonValueExpression($1.v as DatetimePrimary) }

table_expression /* TableExpression */ :
    from_clause                                    { $$.v = TableExpression{$1.v as TableReference, none, []Identifier{}} }
  | from_clause where_clause                     { $$.v = TableExpression{$1.v as TableReference, $2.v as BooleanValueExpression, []Identifier{}} }
  | from_clause group_by_clause                  { $$.v = TableExpression{$1.v as TableReference, none, $2.v as []Identifier} }
  | from_clause where_clause group_by_clause   { $$.v = TableExpression{$1.v as TableReference, $2.v as BooleanValueExpression, $3.v as []Identifier} }

group_by_clause /* []Identifier */ :
    GROUP BY grouping_element_list   { $$.v = $3.v }

grouping_element_list /* []Identifier */ :
    grouping_element                                   { $$.v = [$1.v as Identifier] }
  | grouping_element_list comma grouping_element   { $$.v = append_list($1.v as []Identifier, $3.v as Identifier) }

grouping_element /* Identifier */ :
    ordinary_grouping_set { $$.v = $1.v as Identifier }

ordinary_grouping_set /* Identifier */ :
    grouping_column_reference { $$.v = $1.v as Identifier }

grouping_column_reference /* Identifier */ :
    column_reference { $$.v = $1.v as Identifier }

boolean_value_expression:
  boolean_term { $$.v = BooleanValueExpression{term: $1.v as BooleanTerm} }
| boolean_value_expression OR boolean_term {
    expr := $1.v as BooleanValueExpression
    $$.v = BooleanValueExpression{&expr, $3.v as BooleanTerm}
  }

boolean_term:
    boolean_factor { $$.v = BooleanTerm{factor: $1.v as BooleanTest} }
  | boolean_term AND boolean_factor   { 
    term := $1.v as BooleanTerm
    $$.v = BooleanTerm{&term, $3.v as BooleanTest}
    }

boolean_factor:
  boolean_test { $$.v = $1.v as BooleanTest }
| NOT boolean_test   {
    b := $2.v as BooleanTest
    $$.v = BooleanTest{b.expr, b.not, b.value, !b.inverse}
  }

boolean_test:
    boolean_primary { $$.v = BooleanTest{expr: $1.v as BooleanPrimary} }
  | boolean_primary IS_TRUE       { $$.v = BooleanTest{$1.v as BooleanPrimary, false, new_boolean_value(true), false} }
  | boolean_primary IS_FALSE       { $$.v = BooleanTest{$1.v as BooleanPrimary, false, new_boolean_value(false), false} }
  | boolean_primary IS_UNKNOWN       { $$.v = BooleanTest{$1.v as BooleanPrimary, false, new_unknown_value(), false} }
  | boolean_primary IS_NOT_TRUE   { $$.v = BooleanTest{$1.v as BooleanPrimary, true, new_boolean_value(true), false} }
  | boolean_primary IS_NOT_FALSE       { $$.v = BooleanTest{$1.v as BooleanPrimary, true, new_boolean_value(false), false} }
  | boolean_primary IS_NOT_UNKNOWN       { $$.v = BooleanTest{$1.v as BooleanPrimary, true, new_unknown_value(), false} }

boolean_primary:
    predicate           { $$.v = BooleanPrimary($1.v as Predicate) }
  | boolean_predicand { $$.v = BooleanPrimary($1.v as BooleanPredicand) }

boolean_predicand:
    parenthesized_boolean_value_expression      { $$.v = BooleanPredicand($1.v as BooleanValueExpression) }
  | nonparenthesized_value_expression_primary {
      $$.v = BooleanPredicand($1.v as NonparenthesizedValueExpressionPrimary)
    }

parenthesized_boolean_value_expression /* BooleanValueExpression */ :
    left_paren boolean_value_expression right_paren   { $$.v = $2.v }

unique_constraint_definition /* TableElement */ :
  unique_specification left_paren
  unique_column_list right_paren    { $$.v = UniqueConstraintDefinition{$3.v as []Identifier} }

unique_specification:
  PRIMARY KEY

unique_column_list /* []Identifier */ :
  column_name_list { $$.v = $1.v as []Identifier }

table_row_value_expression:
    row_value_constructor { $$.v = $1.v as RowValueConstructor }

contextually_typed_row_value_expression /* ContextuallyTypedRowValueConstructor */ :
  contextually_typed_row_value_constructor { $$.v = $1.v as ContextuallyTypedRowValueConstructor }

row_value_predicand /* RowValueConstructorPredicand */ :
  row_value_constructor_predicand { $$.v = $1.v as RowValueConstructorPredicand }

sql_schema_statement /* Stmt */ :
    sql_schema_definition_statement { $$.v = $1.v as Stmt }
  | sql_schema_manipulation_statement { $$.v = $1.v as Stmt }

sql_schema_definition_statement /* Stmt */ :
    schema_definition { $$.v = $1.v as Stmt }
  | table_definition { $$.v = $1.v as Stmt }
  | sequence_generator_definition { $$.v = Stmt($1.v as SequenceGeneratorDefinition) }

sql_schema_manipulation_statement /* Stmt */ :
    drop_schema_statement { $$.v = $1.v as Stmt }
  | drop_table_statement { $$.v = $1.v as Stmt }
  | alter_sequence_generator_statement { $$.v = Stmt($1.v as AlterSequenceGeneratorStatement) }
  | drop_sequence_generator_statement { $$.v = $1.v as Stmt }

sql_transaction_statement /* Stmt */ :
    start_transaction_statement { $$.v = $1.v as Stmt }
  | commit_statement { $$.v = $1.v as Stmt }
  | rollback_statement { $$.v = $1.v as Stmt }

sql_session_statement /* Stmt */ :
    set_schema_statement { $$.v = Stmt($1.v as SetSchemaStatement) }
  | set_catalog_statement { $$.v = $1.v as Stmt }

datetime_value_function /* DatetimeValueFunction */ :
    current_date_value_function { $$.v = DatetimeValueFunction($1.v as CurrentDate) }
  | current_time_value_function { $$.v = DatetimeValueFunction($1.v as CurrentTime) }
  | current_timestamp_value_function { $$.v = DatetimeValueFunction($1.v as CurrentTimestamp) }
  | current_local_time_value_function { $$.v = DatetimeValueFunction($1.v as LocalTime) }
  | current_local_timestamp_value_function { $$.v = DatetimeValueFunction($1.v as LocalTimestamp) }

current_date_value_function /* DatetimeValueFunction */ :
    CURRENT_DATE   { $$.v = CurrentDate{} }

current_time_value_function /* DatetimeValueFunction */ :
    CURRENT_TIME                                               { $$.v = CurrentTime{default_time_precision} }
  | CURRENT_TIME left_paren time_precision right_paren   { $$.v = CurrentTime{($3.v as string).int()} }

current_local_time_value_function /* DatetimeValueFunction */ :
    LOCALTIME                                               { $$.v = LocalTime{0} }
  | LOCALTIME left_paren time_precision right_paren   { $$.v = LocalTime{($3.v as string).int()} }

current_timestamp_value_function /* DatetimeValueFunction */ :
    CURRENT_TIMESTAMP                                  { $$.v = CurrentTimestamp{default_timestamp_precision} }
  | CURRENT_TIMESTAMP
    left_paren timestamp_precision right_paren   { $$.v = CurrentTimestamp{($3.v as string).int()} }

current_local_timestamp_value_function /* DatetimeValueFunction */ :
    LOCALTIMESTAMP                                     { $$.v = LocalTimestamp{6} }
  | LOCALTIMESTAMP
    left_paren timestamp_precision right_paren   { $$.v = LocalTimestamp{($3.v as string).int()} }

joined_table /* QualifiedJoin */ :
    qualified_join { $$.v = $1.v as QualifiedJoin }

join_specification /* BooleanValueExpression */ :
    join_condition { $$.v = $1.v as BooleanValueExpression }

join_condition /* BooleanValueExpression */ :
    ON search_condition   { $$.v = $2.v }

join_type /* string */ :
    INNER
  | outer_join_type { $$.v = $1.v as string }
  | outer_join_type OUTER   { $$.v = $1.v as string }

outer_join_type /* string */ :
    LEFT { $$.v = $1.v as string }
  | RIGHT { $$.v = $1.v as string }

null_predicate /* NullPredicate */ :
    row_value_predicand null_predicate_part_2   { $$.v = NullPredicate{$1.v as RowValueConstructorPredicand, !($2.v as bool)} }

null_predicate_part_2:
  IS NULL { $$.v = true }
| IS NOT NULL { $$.v = false }

predicate /* Predicate */ :
    comparison_predicate   { $$.v = Predicate($1.v as ComparisonPredicate) }
  | between_predicate      { $$.v = Predicate($1.v as BetweenPredicate) }
  | like_predicate         { $$.v = Predicate($1.v as CharacterLikePredicate) }
  | similar_predicate      { $$.v = Predicate($1.v as SimilarPredicate) }
  | null_predicate         { $$.v = Predicate($1.v as NullPredicate) }

start_transaction_statement /* Stmt */ :
  START TRANSACTION   { $$.v = Stmt(StartTransactionStatement{}) }

query_expression:
    query_expression_body { $$.v = QueryExpression{body: $1.v as SimpleTable} }
  | query_expression_body order_by_clause   { 
      $$.v = QueryExpression{
        body:  $1.v as SimpleTable
        order: $2.v as []SortSpecification
      }
   }
  | query_expression_body
    result_offset_clause                      {
      $$.v = QueryExpression{
        body:   $1.v as SimpleTable
        offset: $2.v as ValueSpecification
      }
    }
  | query_expression_body order_by_clause
    result_offset_clause                      {
      $$.v = QueryExpression{
        body:   $1.v as SimpleTable
        offset: $3.v as ValueSpecification
        order:  $2.v as []SortSpecification
      }
    }
  | query_expression_body
    fetch_first_clause                        {
      $$.v = QueryExpression{
        body:  $1.v as SimpleTable
        fetch: $2.v as ValueSpecification
      }
    }
  | query_expression_body order_by_clause
    fetch_first_clause                        {
      $$.v = QueryExpression{
        body:  $1.v as SimpleTable
        fetch: $3.v as ValueSpecification
        order: $2.v as []SortSpecification
      }
    }
  | query_expression_body order_by_clause
    result_offset_clause
    fetch_first_clause                        {
      $$.v = QueryExpression{
        body:   $1.v as SimpleTable
        offset: $3.v as ValueSpecification
        fetch:  $4.v as ValueSpecification
        order:  $2.v as []SortSpecification
      }
    }
  | query_expression_body
    result_offset_clause
    fetch_first_clause                        {
      $$.v = QueryExpression{
        body:   $1.v as SimpleTable
        offset: $2.v as ValueSpecification
        fetch:  $3.v as ValueSpecification
      }
    }

query_expression_body:
    query_term { $$.v = $1.v as SimpleTable }

query_term:
  query_primary { $$.v = $1.v as SimpleTable }

query_primary:
  simple_table { $$.v = $1.v as SimpleTable }

simple_table:
    query_specification { $$.v = SimpleTable($1.v as QuerySpecification) }
  | table_value_constructor { $$.v = $1.v as SimpleTable }

order_by_clause /* []SortSpecification */ :
    ORDER BY sort_specification_list   { $$.v = $3.v }

result_offset_clause /* ValueSpecification */ :
    OFFSET offset_row_count row_or_rows   { $$.v = $2.v }

fetch_first_clause /* ValueSpecification */ :
    FETCH FIRST
    fetch_first_quantity
    row_or_rows
    ONLY                     { $$.v = $3.v }

fetch_first_quantity /* ValueSpecification */ :
    fetch_first_row_count { $$.v = $1.v as ValueSpecification }

offset_row_count /* ValueSpecification */ :
    simple_value_specification { $$.v = $1.v as ValueSpecification }

fetch_first_row_count /* ValueSpecification */ :
    simple_value_specification { $$.v = $1.v as ValueSpecification }

row_or_rows :
    ROW
  | ROWS

similar_predicate /* SimilarPredicate */ :
  row_value_predicand similar_predicate_part_2 {
    like := $2.v as SimilarPredicate
    $$.v = SimilarPredicate{$1.v as RowValueConstructorPredicand, like.right, like.not}
  }

similar_predicate_part_2 /* SimilarPredicate */ :
    SIMILAR TO similar_pattern       { $$.v = SimilarPredicate{none, $3.v as CharacterValueExpression, false} }
  | NOT SIMILAR TO similar_pattern   { $$.v = SimilarPredicate{none, $4.v as CharacterValueExpression, true} }

similar_pattern /* CharacterValueExpression */ :
    character_value_expression { $$.v = $1.v as CharacterValueExpression }

left_paren : OPERATOR_LEFT_PAREN

right_paren : OPERATOR_RIGHT_PAREN

asterisk /* string */ : OPERATOR_ASTERISK { $$.v = $1.v as string }

plus_sign /* string */ : OPERATOR_PLUS { $$.v = $1.v as string }

comma : OPERATOR_COMMA

minus_sign /* string */ : OPERATOR_MINUS { $$.v = $1.v as string }

period : OPERATOR_PERIOD

solidus /* string */ : OPERATOR_SOLIDUS { $$.v = $1.v as string }

colon : OPERATOR_COLON

less_than_operator : OPERATOR_LESS_THAN

equals_operator : OPERATOR_EQUALS

greater_than_operator : OPERATOR_GREATER_THAN

table_constraint_definition /* TableElement */ :
  table_constraint { $$.v = $1.v as TableElement }

table_constraint /* TableElement */ :
  unique_constraint_definition { $$.v = TableElement($1.v as UniqueConstraintDefinition) }

column_definition /* TableElement */ :
    column_name data_type_or_domain_name   { $$.v = TableElement(Column{$1.v as Identifier, $2.v as Type, false}) }
  | column_name data_type_or_domain_name
    column_constraint_definition             { $$.v = TableElement(Column{$1.v as Identifier, $2.v as Type, $3.v as bool}) }

data_type_or_domain_name /* Type */ :
    data_type { $$.v = $1.v as Type }

column_constraint_definition /* bool */ :
    column_constraint { $$.v = $1.v as bool }

column_constraint /* bool */ :
    NOT NULL   { $$.v = true }

set_schema_statement /* Stmt */ :
    SET schema_name_characteristic   { $$.v = SetSchemaStatement{$2.v as ValueSpecification} }

schema_name_characteristic /* ValueSpecification */ :
    SCHEMA value_specification   { $$.v = $2.v }

// was: COUNT left_paren asterisk right_paren
aggregate_function /* AggregateFunction */ :
    COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren   { $$.v = AggregateFunction(AggregateFunctionCount{}) }
  | general_set_function { $$.v = $1.v as AggregateFunction }

general_set_function /* AggregateFunction */ :
    set_function_type left_paren
    value_expression right_paren   { $$.v = AggregateFunction(RoutineInvocation{$1.v as string, [$3.v as ValueExpression]}) }

set_function_type /* string */ :
    computational_operation { $$.v = $1.v as string }

computational_operation /* string */ :
    AVG { $$.v = $1.v as string }
  | MAX { $$.v = $1.v as string }
  | MIN { $$.v = $1.v as string }
  | SUM { $$.v = $1.v as string }
  | COUNT { $$.v = $1.v as string }

set_catalog_statement:
  SET catalog_name_characteristic {
    $$.v = Stmt(SetCatalogStatement{$2.v as ValueSpecification})
  }

catalog_name_characteristic /* ValueSpecification */ :
  CATALOG value_specification { $$.v = $2.v as ValueSpecification }

drop_table_statement /* Stmt */ :
    DROP TABLE table_name   { $$.v = Stmt(DropTableStatement{$3.v as Identifier}) }

value_specification:
  literal { $$.v = ValueSpecification($1.v as Value) }
| general_value_specification { $$.v = ValueSpecification($1.v as GeneralValueSpecification) }

unsigned_value_specification:
  unsigned_literal { $$.v = ValueSpecification($1.v as Value) }
| general_value_specification   { $$.v = ValueSpecification($1.v as GeneralValueSpecification) }

general_value_specification:
    host_parameter_specification { $$.v = $1.v as GeneralValueSpecification }
  | CURRENT_CATALOG                  { $$.v = GeneralValueSpecification(CurrentCatalog{}) }
  | CURRENT_SCHEMA                   { $$.v = GeneralValueSpecification(CurrentSchema{}) }

simple_value_specification:
  literal               { $$.v = ValueSpecification($1.v as Value) }
| host_parameter_name   { $$.v = ValueSpecification($1.v as GeneralValueSpecification) }

host_parameter_specification /* GeneralValueSpecification */ :
    host_parameter_name { $$.v = $1.v as GeneralValueSpecification }

insert_statement:
  INSERT INTO insertion_target insert_columns_and_source {
    stmt := $4.v as InsertStatement
    $$.v = Stmt(InsertStatement{$3.v as Identifier, stmt.columns, stmt.values})
  }

insertion_target /* Identifier */ :
    table_name { $$.v = $1.v as Identifier }

insert_columns_and_source /* InsertStatement */ :
  from_constructor { $$.v = $1.v as InsertStatement }

from_constructor:
  left_paren insert_column_list right_paren
  contextually_typed_table_value_constructor {
    $$.v = InsertStatement{
      columns: $2.v as []Identifier
      values:  $4.v as []ContextuallyTypedRowValueConstructor
    }
  }

insert_column_list /* []Identifier */ :
    column_name_list { $$.v = $1.v as []Identifier }

value_expression_primary:
  parenthesized_value_expression {
    $$.v = ValueExpressionPrimary($1.v as ParenthesizedValueExpression)
  }
| nonparenthesized_value_expression_primary { $$.v = ValueExpressionPrimary($1.v as NonparenthesizedValueExpressionPrimary) }

parenthesized_value_expression:
  left_paren value_expression right_paren {
    $$.v = ParenthesizedValueExpression{$2.v as ValueExpression}
  }

nonparenthesized_value_expression_primary:
    unsigned_value_specification {
      $$.v = NonparenthesizedValueExpressionPrimary($1.v as ValueSpecification)
    }
  | column_reference {
      $$.v = NonparenthesizedValueExpressionPrimary($1.v as Identifier)
    }
  | set_function_specification {
      $$.v = NonparenthesizedValueExpressionPrimary($1.v as AggregateFunction)
    }
  | routine_invocation {
      $$.v = NonparenthesizedValueExpressionPrimary($1.v as RoutineInvocation)
    }
  | case_expression {
      $$.v = NonparenthesizedValueExpressionPrimary($1.v as CaseExpression)
    }
  | cast_specification {
      $$.v = NonparenthesizedValueExpressionPrimary($1.v as CastSpecification)
    }
  | next_value_expression {
      $$.v = NonparenthesizedValueExpressionPrimary($1.v as NextValueExpression)
    }

string_value_function /* CharacterValueFunction */ :
    character_value_function { $$.v = $1.v as CharacterValueFunction }

character_value_function:
  character_substring_function   { $$.v = CharacterValueFunction($1.v as CharacterSubstringFunction) }
| fold                           { $$.v = CharacterValueFunction($1.v as RoutineInvocation) }
| trim_function                  { $$.v = CharacterValueFunction($1.v as TrimFunction) }

character_substring_function:
  SUBSTRING left_paren character_value_expression FROM start_position
  right_paren {
    $$.v = CharacterSubstringFunction{$3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, none, 'CHARACTERS'}
  }
| SUBSTRING left_paren character_value_expression FROM start_position FOR
  string_length right_paren {
    $$.v = CharacterSubstringFunction{$3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, $7.v as NumericValueExpression,
      'CHARACTERS'}
  }
| SUBSTRING left_paren character_value_expression FROM start_position USING
  char_length_units right_paren {
    $$.v = CharacterSubstringFunction{$3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, none, $7.v as string}
  }
| SUBSTRING left_paren character_value_expression FROM start_position FOR
  string_length USING char_length_units right_paren {
    $$.v = CharacterSubstringFunction{$3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, $7.v as NumericValueExpression,
      $9.v as string}
  }

fold:
  UPPER left_paren character_value_expression right_paren {
    $$.v = RoutineInvocation{'UPPER',
      [ValueExpression(CommonValueExpression($3.v as CharacterValueExpression))]}
  }
| LOWER left_paren character_value_expression right_paren {
    $$.v = RoutineInvocation{'LOWER',
      [ValueExpression(CommonValueExpression($3.v as CharacterValueExpression))]}
  }

trim_function:
  TRIM left_paren trim_operands right_paren { $$.v = $3.v as TrimFunction }

trim_operands:
  trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = TrimFunction{'BOTH', space, $1.v as CharacterValueExpression}
  }
| FROM trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = TrimFunction{'BOTH', space, $2.v as CharacterValueExpression}
  }
| trim_specification FROM trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = TrimFunction{$1.v as string, space, $3.v as CharacterValueExpression}
  }
| trim_character FROM trim_source {
    $$.v = TrimFunction{'BOTH', $1.v as CharacterValueExpression, $3.v as CharacterValueExpression}
  }
| trim_specification trim_character FROM trim_source   {
    $$.v = TrimFunction{$1.v as string, $2.v as CharacterValueExpression, $4.v as CharacterValueExpression}
  }

trim_source /* CharacterValueExpression */ :
    character_value_expression { $$.v = $1.v as CharacterValueExpression }

trim_specification /* string */ :
    LEADING { $$.v = $1.v as string }
  | TRAILING { $$.v = $1.v as string }
  | BOTH { $$.v = $1.v as string }

trim_character /* CharacterValueExpression */ :
    character_value_expression { $$.v = $1.v as CharacterValueExpression }

start_position /* NumericValueExpression */ :
    numeric_value_expression { $$.v = $1.v as NumericValueExpression }

string_length /* NumericValueExpression */ :
    numeric_value_expression { $$.v = $1.v as NumericValueExpression }

numeric_value_expression:
  term { $$.v = NumericValueExpression{term: $1.v as Term} }
| numeric_value_expression plus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = NumericValueExpression{&n, '+', $3.v as Term}
  }
| numeric_value_expression minus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = NumericValueExpression{&n, '-', $3.v as Term}
  }

term:
  factor { $$.v = Term{factor: $1.v as NumericPrimary} }
| term asterisk factor {
    t := $1.v as Term
    $$.v = Term{&t, '*', $3.v as NumericPrimary}
  }
| term solidus factor {
    t := $1.v as Term
    $$.v = Term{&t, '/', $3.v as NumericPrimary}
  }

factor:
  numeric_primary { $$.v = $1.v as NumericPrimary }
| sign numeric_primary {
    $$.v = parse_factor_2($1.v as string, $2.v as NumericPrimary)!
  }

numeric_primary:
  value_expression_primary {
    $$.v = NumericPrimary($1.v as ValueExpressionPrimary)
  }
| numeric_value_function { $$.v = NumericPrimary($1.v as RoutineInvocation) }

routine_invocation:
  routine_name sql_argument_list {
    $$.v = RoutineInvocation{($1.v as Identifier).entity_name, $2.v as []ValueExpression}
  }

routine_name:
  qualified_identifier {
    $$.v = new_function_identifier(($1.v as IdentifierChain).identifier)!
  }

sql_argument_list:
  left_paren right_paren { $$.v = []ValueExpression{} }
| left_paren sql_argument right_paren { $$.v = [$2.v as ValueExpression] }
| left_paren sql_argument_list comma sql_argument right_paren {
    $$.v = append_list($2.v as []ValueExpression, $4.v as ValueExpression)
  }

sql_argument /* ValueExpression */ :
    value_expression { $$.v = $1.v as ValueExpression }

%%

fn yy_error(err IError) {
  println("yy_error: $err")
}

pub fn main_()! {
  // println(tokenize2("SELECT 'foo' FROM bar WHERE \"baz\" = 12.3"))
  tokens := tokenize2('SELECT bar.* FROM foo')
  println(tokens)

  mut lexer := Lexer{
    tokens: tokens
  }
	mut parser := yy_new_parser()
  parser.parse(mut lexer)!
  println((parser as YYParserImpl).lval.v)
  // value := ((parser as YYParserImpl).lval.v as Stmt)
  // println(value.pstr(map[string]Value{}))
}
