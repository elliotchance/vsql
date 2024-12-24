%{

module vsql

%}

// keywords
%token A ABSOLUTE ACTION ADA ADD ADMIN AFTER ALWAYS ASC ASSERTION ASSIGNMENT;
%token ATTRIBUTE ATTRIBUTES BEFORE BERNOULLI BREADTH C CASCADE CATALOG;
%token CATALOG_NAME CHAIN CHAINING CHARACTER_SET_CATALOG CHARACTER_SET_NAME;
%token CHARACTER_SET_SCHEMA CHARACTERISTICS CHARACTERS CLASS_ORIGIN COBOL;
%token COLLATION COLLATION_CATALOG COLLATION_NAME COLLATION_SCHEMA COLUMNS
%token COLUMN_NAME COMMAND_FUNCTION COMMAND_FUNCTION_CODE COMMITTED CONDITIONAL;
%token CONDITION_NUMBER CONNECTION CONNECTION_NAME CONSTRAINT_CATALOG;
%token CONSTRAINT_NAME CONSTRAINT_SCHEMA CONSTRAINTS CONSTRUCTOR CONTINUE;
%token CURSOR_NAME DATA DATETIME_INTERVAL_CODE DATETIME_INTERVAL_PRECISION;
%token DEFAULTS DEFERRABLE DEFERRED DEFINED DEFINER DEGREE DEPTH DERIVED DESC;
%token DESCRIBE_CATALOG DESCRIBE_NAME DESCRIBE_PROCEDURE_SPECIFIC_CATALOG;
%token DESCRIBE_PROCEDURE_SPECIFIC_NAME DESCRIBE_PROCEDURE_SPECIFIC_SCHEMA;
%token DESCRIBE_SCHEMA DESCRIPTOR DIAGNOSTICS DISPATCH DOMAIN DYNAMIC_FUNCTION;
%token DYNAMIC_FUNCTION_CODE ENCODING ENFORCED ERROR EXCLUDE EXCLUDING;
%token EXPRESSION FINAL FINISH FINISH_CATALOG FINISH_NAME;
%token FINISH_PROCEDURE_SPECIFIC_CATALOG FINISH_PROCEDURE_SPECIFIC_NAME;
%token FINISH_PROCEDURE_SPECIFIC_SCHEMA FINISH_SCHEMA FIRST FLAG FOLLOWING;
%token FORMAT FORTRAN FOUND FULFILL FULFILL_CATALOG FULFILL_NAME;
%token FULFILL_PROCEDURE_SPECIFIC_CATALOG FULFILL_PROCEDURE_SPECIFIC_NAME;
%token FULFILL_PROCEDURE_SPECIFIC_SCHEMA FULFILL_SCHEMA G GENERAL GENERATED GO;
%token GOTO GRANTED HAS_PASS_THROUGH_COLUMNS HAS_PASS_THRU_COLS HIERARCHY;
%token IGNORE IMMEDIATE IMMEDIATELY IMPLEMENTATION INCLUDING INCREMENT;
%token INITIALLY INPUT INSTANCE INSTANTIABLE INSTEAD INVOKER ISOLATION;
%token IS_PRUNABLE JSON K KEEP KEY KEYS KEY_MEMBER KEY_TYPE LAST LENGTH LEVEL;
%token LOCATOR M MAP MATCHED MAXVALUE MESSAGE_LENGTH MESSAGE_OCTET_LENGTH;
%token MESSAGE_TEXT MINVALUE MORE MUMPS NAME NAMES NESTED NESTING NEXT NFC NFD;
%token NFKC NFKD NORMALIZED NULLABLE NULLS NUMBER OBJECT OCTETS OPTION OPTIONS;
%token ORDERING ORDINALITY OTHERS OUTPUT OVERFLOW OVERRIDING P PAD;
%token PARAMETER_MODE PARAMETER_NAME PARAMETER_ORDINAL_POSITION;
%token PARAMETER_SPECIFIC_CATALOG PARAMETER_SPECIFIC_NAME;
%token PARAMETER_SPECIFIC_SCHEMA PARTIAL PASCAL PASS PASSING PAST PATH PLACING;
%token PLAN PLI PRECEDING PRESERVE PRIOR PRIVATE PRIVATE_PARAMETERS;
%token PRIVATE_PARAMS_S PRIVILEGES PRUNE PUBLIC QUOTES READ RELATIVE REPEATABLE;
%token RESPECT RESTART RESTRICT RETURNED_CARDINALITY RETURNED_LENGTH;
%token RETURNED_OCTET_LENGTH RETURNED_SQLSTATE RETURNING;
%token RETURNS_ONLY_PASS_THROUGH RET_ONLY_PASS_THRU ROLE ROUTINE;
%token ROUTINE_CATALOG ROUTINE_NAME ROUTINE_SCHEMA ROW_COUNT SCALAR SCALE;
%token SCHEMA SCHEMA_NAME SCOPE_CATALOG SCOPE_NAME SCOPE_SCHEMA SECTION;
%token SECURITY SELF SEQUENCE SERIALIZABLE SERVER_NAME SESSION SETS SIMPLE SIZE;
%token SOURCE SPACE SPECIFIC_NAME START_CATALOG START_NAME;
%token START_PROCEDURE_SPECIFIC_CATALOG START_PROCEDURE_SPECIFIC_NAME;
%token START_PROCEDURE_SPECIFIC_SCHEMA START_SCHEMA STATE STATEMENT STRING;
%token STRUCTURE STYLE SUBCLASS_ORIGIN T TABLE_NAME TABLE_SEMANTICS TEMPORARY;
%token THROUGH TIES TOP_LEVEL_COUNT TRANSACTION TRANSACTION_ACTIVE;
%token TRANSACTIONS_COMMITTED TRANSACTIONS_ROLLED_BACK TRANSFORM TRANSFORMS;
%token TRIGGER_CATALOG TRIGGER_NAME TRIGGER_SCHEMA TYPE UNBOUNDED UNCOMMITTED;
%token UNCONDITIONAL UNDER UNNAMED USAGE USER_DEFINED_TYPE_CATALOG;
%token USER_DEFINED_TYPE_CODE USER_DEFINED_TYPE_NAME USER_DEFINED_TYPE_SCHEMA;
%token UTF16 UTF32 UTF8 VIEW WORK WRAPPER WRITE ZONE;

%token VALUES DROP NULLIF COALESCE ALTER WITH COMMIT DELETE FROM WHERE TABLE;
%token UPDATE SET CAST AS FOR E DATE TIME CREATE ROLLBACK VALUE TIMESTAMP;
%token TRUE FALSE UNKNOWN NULL AND BETWEEN NOT SYMMETRIC ASYMMETRIC POSITION;
%token IN CHAR_LENGTH CHARACTER_LENGTH ABS MOD SIN COS TAN SINH COSH TANH ASIN;
%token ACOS ATAN LOG10 LN EXP POWER SQRT FLOOR CEIL CEILING CHARACTER CHAR;
%token VARYING VARCHAR NUMERIC DECIMAL SMALLINT INTEGER INT BIGINT FLOAT REAL;
%token DOUBLE PRECISION BOOLEAN WITHOUT LIKE ROW SELECT JOIN START BY NO CYCLE;
%token GROUP OR IS PRIMARY CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP ON;
%token INNER OUTER LEFT RIGHT ORDER OFFSET FETCH ONLY ROWS SIMILAR TO COUNT;
%token AVG MAX MIN SUM CURRENT_CATALOG CURRENT_SCHEMA INSERT INTO SUBSTRING;
%token USING UPPER LOWER TRIM LEADING TRAILING BOTH OCTET_LENGTH LOCALTIME;
%token LOCALTIMESTAMP;

// operators
%token OPERATOR_EQUALS OPERATOR_LEFT_PAREN OPERATOR_RIGHT_PAREN;
%token OPERATOR_ASTERISK OPERATOR_PLUS OPERATOR_COMMA OPERATOR_MINUS;
%token OPERATOR_PERIOD OPERATOR_SOLIDUS OPERATOR_COLON OPERATOR_LESS_THAN;
%token OPERATOR_GREATER_THAN OPERATOR_DOUBLE_PIPE OPERATOR_NOT_EQUALS;
%token OPERATOR_GREATER_EQUALS OPERATOR_LESS_EQUALS;

// literals
%token LITERAL_IDENTIFIER LITERAL_STRING LITERAL_INTEGER;

%start preparable_statement;

%%

target_table /* Identifier */ :
    table_name

column_reference /* Identifier */ :
    basic_identifier_chain   {  column_reference() }

table_value_constructor /* SimpleTable */ :
    VALUES row_value_expression_list   {  table_value_constructor() }

row_value_expression_list /* []RowValueConstructor */ :
    table_row_value_expression           {  row_value_expression_list_1() }
  | row_value_expression_list
    comma table_row_value_expression   {  row_value_expression_list_2() }

contextually_typed_table_value_constructor /* []ContextuallyTypedRowValueConstructor */ :
    VALUES contextually_typed_row_value_expression_list   {  contextually_typed_table_value_constructor() }

contextually_typed_row_value_expression_list /* []ContextuallyTypedRowValueConstructor */ :
    contextually_typed_row_value_expression                {  contextually_typed_row_value_expression_list_1() }
  | contextually_typed_row_value_expression_list comma
    contextually_typed_row_value_expression                {  contextually_typed_row_value_expression_list_2() }

drop_sequence_generator_statement /* Stmt */ :
    DROP SEQUENCE
    sequence_generator_name   {  drop_sequence_generator_statement() }

case_expression /* CaseExpression */ :
    case_abbreviation

case_abbreviation /* CaseExpression */ :
    NULLIF left_paren value_expression
    comma value_expression right_paren                      {  nullif() }
  | COALESCE left_paren value_expression_list right_paren   {  coalesce() }

value_expression_list /* []ValueExpression */ :
    value_expression                                   {  value_expression_list_1() }
  | value_expression_list comma value_expression   {  value_expression_list_2() }

alter_sequence_generator_statement /* AlterSequenceGeneratorStatement */ :
    ALTER SEQUENCE
    sequence_generator_name
    alter_sequence_generator_options   {  alter_sequence_generator_statement() }

alter_sequence_generator_options /* []SequenceGeneratorOption */ :
    alter_sequence_generator_option   {  sequence_generator_options_1() }
  | alter_sequence_generator_options
    alter_sequence_generator_option   {  sequence_generator_options_2() }

alter_sequence_generator_option /* SequenceGeneratorOption */ :
    alter_sequence_generator_restart_option   {  SequenceGeneratorOption() }
  | basic_sequence_generator_option

alter_sequence_generator_restart_option /* SequenceGeneratorRestartOption */ :
    RESTART                              {  sequence_generator_restart_option_1() }
  | RESTART WITH
    sequence_generator_restart_value   {  sequence_generator_restart_option_2() }

sequence_generator_restart_value /* Value */ :
    signed_numeric_literal

commit_statement /* Stmt */ :
    COMMIT        {  commit() }
  | COMMIT WORK   {  commit() }

sort_specification_list /* []SortSpecification */ :
    sort_specification                                     {  sort_list_1() }
  | sort_specification_list comma sort_specification   {  sort_list_2() }

sort_specification /* SortSpecification */ :
    sort_key                            {  sort_1() }
  | sort_key ordering_specification   {  sort_2() }

sort_key /* ValueExpression */ :
    value_expression

ordering_specification /* bool */ :
    ASC    {  yes() }
  | DESC   {  no() }

row_subquery /* QueryExpression */ :
    subquery

table_subquery /* TablePrimary */ :
    subquery

subquery /* TablePrimaryBody */ :
    left_paren query_expression right_paren   {  subquery() }

set_clause_list /* map[string]UpdateSource */ :
    set_clause
  | set_clause_list comma set_clause   {  set_clause_append() }

set_clause /* map[string]UpdateSource */ :
  set_target equals_operator update_source   {  set_clause() }

set_target /* Identifier */ :
    update_target

update_target /* Identifier */ :
    object_column

update_source /* UpdateSource */ :
    value_expression                         {  UpdateSource() }
  | contextually_typed_value_specification   {  UpdateSource() }

object_column /* Identifier */ :
    column_name

delete_statement_searched /* Stmt */ :
    DELETE FROM target_table   {  delete_statement() }
  | DELETE FROM target_table
    WHERE search_condition     {  delete_statement_where() }

table_definition /* TableDefinition */ :
    CREATE TABLE table_name table_contents_source   {  table_definition() }

table_contents_source /* []TableElement */ :
    table_element_list

table_element_list /* []TableElement */ :
    left_paren
    table_elements
    right_paren      {  table_element_list() }

table_element /* TableElement */ :
    column_definition
  | table_constraint_definition

table_elements /* []TableElement */ :
    table_element                            {  table_elements_1() }
  | table_elements comma table_element   {  table_elements_2() }

preparable_statement /* Stmt */ :
    preparable_sql_data_statement
  | preparable_sql_schema_statement
  | preparable_sql_transaction_statement
  | preparable_sql_session_statement

preparable_sql_data_statement /* Stmt */ :
    delete_statement_searched
  | insert_statement
  | dynamic_select_statement
  | update_statement_searched

preparable_sql_schema_statement /* Stmt */ :
    sql_schema_statement

preparable_sql_transaction_statement /* Stmt */ :
  sql_transaction_statement

preparable_sql_session_statement /* Stmt */ :
    sql_session_statement

dynamic_select_statement /* Stmt */ :
    cursor_specification

schema_definition /* Stmt */ :
    CREATE SCHEMA schema_name_clause   {  schema_definition() }

schema_name_clause /* Identifier */ :
    schema_name

cursor_specification /* Stmt */ :
    query_expression   {  Stmt() }

datetime_value_expression /* DatetimePrimary */ :
    datetime_term

datetime_term /* DatetimePrimary */ :
    datetime_factor

datetime_factor /* DatetimePrimary */ :
    datetime_primary

datetime_primary /* DatetimePrimary */ :
    value_expression_primary   {  DatetimePrimary() }
  | datetime_value_function    {  DatetimePrimary() }

update_statement_searched /* Stmt */ :
    UPDATE target_table
    SET set_clause_list      {  update_statement_searched_1() }
  | UPDATE target_table
    SET set_clause_list
    WHERE search_condition   {  update_statement_searched_2() }

identifier_chain /* IdentifierChain */ :
    identifier
  | identifier period identifier   {  identifier_chain() }

basic_identifier_chain /* IdentifierChain */ :
    identifier_chain

cast_specification /* CastSpecification */ :
    CAST left_paren cast_operand AS cast_target right_paren   {  cast() }

cast_operand /* CastOperand */ :
    value_expression                       {  CastOperand() }
  | implicitly_typed_value_specification   {  CastOperand() }

cast_target /* Type */ :
    data_type

rollback_statement /* Stmt */ :
    ROLLBACK        {  rollback() }
  | ROLLBACK WORK   {  rollback() }

next_value_expression /* NextValueExpression */ :
    NEXT VALUE FOR sequence_generator_name   {  next_value_expression() }

where_clause /* BooleanValueExpression */ :
    WHERE search_condition   {  where_clause() }

literal /* Value */ :
    signed_numeric_literal
  | general_literal

unsigned_literal /* Value */ :
    unsigned_numeric_literal
  | general_literal

general_literal /* Value */ :
    character_string_literal
  | datetime_literal
  | boolean_literal

character_string_literal /* Value */ :
    LITERAL_STRING

signed_numeric_literal /* Value */ :
    unsigned_numeric_literal
  | sign unsigned_numeric_literal   {  signed_numeric_literal_2() }

unsigned_numeric_literal /* Value */ :
    exact_numeric_literal
  | approximate_numeric_literal

exact_numeric_literal /* Value */ :
    unsigned_integer                               {  exact_numeric_literal_1() }
  | unsigned_integer period                      {  exact_numeric_literal_2() }
  | unsigned_integer period unsigned_integer   {  exact_numeric_literal_3() }
  | period unsigned_integer                      {  exact_numeric_literal_4() }

sign /* string */ :
    plus_sign
  | minus_sign

approximate_numeric_literal /* Value */ :
    mantissa E exponent   {  approximate_numeric_literal() }

mantissa /* Value */ :
  exact_numeric_literal

exponent /* Value */ :
  signed_integer

signed_integer /* Value */ :
    unsigned_integer          {  signed_integer_1() }
  | sign unsigned_integer   {  signed_integer_2() }

unsigned_integer /* string */ :
    LITERAL_INTEGER

datetime_literal /* Value */ :
    date_literal
  | time_literal
  | timestamp_literal

date_literal /* Value */ :
    DATE date_string   {  date_literal() }

time_literal /* Value */ :
    TIME time_string   {  time_literal() }

timestamp_literal /* Value */ :
    TIMESTAMP timestamp_string   {  timestamp_literal() }

date_string /* Value */ :
    LITERAL_STRING

time_string /* Value */ :
    LITERAL_STRING

timestamp_string /* Value */ :
    LITERAL_STRING

boolean_literal /* Value */ :
    TRUE      {  true() }
  | FALSE     {  false() }
  | UNKNOWN   {  unknown() }

contextually_typed_value_specification /* NullSpecification */ :
    implicitly_typed_value_specification

implicitly_typed_value_specification /* NullSpecification */ :
    null_specification

null_specification /* NullSpecification */ :
    NULL   {  null_specification() }

from_clause /* TableReference */ :
    FROM table_reference_list   {  from_clause() }

table_reference_list /* TableReference */ :
    table_reference

between_predicate /* BetweenPredicate */ :
    row_value_predicand between_predicate_part_2   {  between() }

between_predicate_part_2 /* BetweenPredicate */ :
    between_predicate_part_1
    row_value_predicand AND row_value_predicand   {  between_1() }
  | between_predicate_part_1 is_symmetric
    row_value_predicand AND row_value_predicand   {  between_2() }

between_predicate_part_1 /* bool */ :
    BETWEEN       {  yes() }
  | NOT BETWEEN   {  no() }

is_symmetric /* bool */ :
    SYMMETRIC    {  yes() }
  | ASYMMETRIC   {  no() }

identifier /* IdentifierChain */ :
    actual_identifier

actual_identifier /* IdentifierChain */ :
    regular_identifier

table_name /* Identifier */ :
    local_or_schema_qualified_name   {  table_name() }

schema_name /* Identifier */ :
    catalog_name period unqualified_schema_name   {  schema_name_1() }
  | unqualified_schema_name

unqualified_schema_name /* Identifier */ :
    identifier   {  unqualified_schema_name() }

catalog_name /* IdentifierChain */ :
    identifier

schema_qualified_name /* IdentifierChain */ :
    qualified_identifier
  | schema_name period qualified_identifier   {  schema_qualified_name_2() }

local_or_schema_qualified_name /* IdentifierChain */ :
    qualified_identifier
  | local_or_schema_qualifier period
    qualified_identifier                 {  local_or_schema_qualified_name2() }

local_or_schema_qualifier /* Identifier */ :
    schema_name

qualified_identifier /* IdentifierChain */ :
    identifier

column_name /* Identifier */ :
    identifier   {  column_name() }

host_parameter_name /* GeneralValueSpecification */ :
    colon identifier   {  host_parameter_name() }

correlation_name /* Identifier */ :
    identifier   {  correlation_name() }

sequence_generator_name /* Identifier */ :
    schema_qualified_name   {  sequence_generator_name() }

drop_schema_statement /* Stmt */ :
    DROP SCHEMA schema_name drop_behavior   {  drop_schema_statement() }

drop_behavior /* string */ :
    CASCADE
  | RESTRICT

numeric_value_function /* RoutineInvocation */ :
    position_expression
  | length_expression
  | absolute_value_expression
  | modulus_expression
  | trigonometric_function
  | common_logarithm
  | natural_logarithm
  | exponential_function
  | power_function
  | square_root
  | floor_function
  | ceiling_function

position_expression /* RoutineInvocation */ :
    character_position_expression

character_position_expression /* RoutineInvocation */ :
    POSITION left_paren character_value_expression_1 IN
    character_value_expression_2 right_paren              {  position() }

character_value_expression_1 /* CharacterValueExpression */ :
    character_value_expression

character_value_expression_2 /* CharacterValueExpression */ :
    character_value_expression

length_expression /* RoutineInvocation */ :
    char_length_expression
  | octet_length_expression

char_length_expression /* RoutineInvocation */ :
    CHAR_LENGTH
    left_paren character_value_expression right_paren   {  char_length() }
  | CHARACTER_LENGTH
    left_paren character_value_expression right_paren   {  char_length() }

octet_length_expression /* RoutineInvocation */ :
    OCTET_LENGTH
    left_paren string_value_expression right_paren   {  octet_length() }

absolute_value_expression /* RoutineInvocation */ :
    ABS left_paren numeric_value_expression right_paren   {  abs() }

modulus_expression /* RoutineInvocation */ :
    MOD left_paren numeric_value_expression_dividend comma
    numeric_value_expression_divisor right_paren               {  mod() }

numeric_value_expression_dividend /* NumericValueExpression */ :
    numeric_value_expression

numeric_value_expression_divisor /* NumericValueExpression */ :
    numeric_value_expression

trigonometric_function /* RoutineInvocation */ :
    trigonometric_function_name
    left_paren numeric_value_expression
    right_paren                             {  trig_func() }

trigonometric_function_name /* string */ :
    SIN
  | COS
  | TAN
  | SINH
  | COSH
  | TANH
  | ASIN
  | ACOS
  | ATAN

common_logarithm /* RoutineInvocation */ :
    LOG10 left_paren numeric_value_expression right_paren   {  log10() }

natural_logarithm /* RoutineInvocation */ :
    LN left_paren numeric_value_expression right_paren   {  ln() }

exponential_function /* RoutineInvocation */ :
    EXP left_paren numeric_value_expression right_paren   {  exp() }

power_function /* RoutineInvocation */ :
    POWER left_paren numeric_value_expression_base comma
    numeric_value_expression_exponent right_paren            {  power() }

numeric_value_expression_base /* NumericValueExpression */ :
    numeric_value_expression

numeric_value_expression_exponent /* NumericValueExpression */ :
    numeric_value_expression

square_root /* RoutineInvocation */ :
    SQRT left_paren numeric_value_expression right_paren   {  sqrt() }

floor_function /* RoutineInvocation */ :
    FLOOR left_paren numeric_value_expression right_paren   {  floor() }

ceiling_function /* RoutineInvocation */ :
    CEIL left_paren numeric_value_expression right_paren      {  ceiling() }
  | CEILING left_paren numeric_value_expression right_paren   {  ceiling() }

concatenation_operator : OPERATOR_DOUBLE_PIPE

regular_identifier /* IdentifierChain */ :
    identifier_body
  | non_reserved_word   {  string_identifier() }

identifier_body /* IdentifierChain */ :
    identifier_start

identifier_start /* IdentifierChain */ :
    LITERAL_IDENTIFIER

not_equals_operator : OPERATOR_NOT_EQUALS

greater_than_or_equals_operator : OPERATOR_GREATER_EQUALS

less_than_or_equals_operator : OPERATOR_LESS_EQUALS

non_reserved_word /* string */ :
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
    predefined_type

predefined_type /* Type */ :
    character_string_type
  | numeric_type
  | boolean_type
  | datetime_type

character_string_type /* Type */ :
    CHARACTER                                                         {  character() }
  | CHARACTER left_paren character_length right_paren           {  character_n() }
  | CHAR                                                              {  character() }
  | CHAR left_paren character_length right_paren                {  character_n() }
  | CHARACTER VARYING left_paren character_length right_paren   {  varchar() }
  | CHAR VARYING left_paren character_length right_paren        {  varchar() }
  | VARCHAR left_paren character_length right_paren             {  varchar() }

numeric_type /* Type */ :
    exact_numeric_type
  | approximate_numeric_type

exact_numeric_type /* Type */ :
    NUMERIC                                                          {  numeric1() }
  | NUMERIC left_paren precision right_paren                   {  numeric2() }
  | NUMERIC left_paren precision comma scale right_paren   {  numeric3() }
  | DECIMAL                                                          {  decimal1() }
  | DECIMAL left_paren precision right_paren                   {  decimal2() }
  | DECIMAL left_paren precision comma scale right_paren   {  decimal3() }
  | SMALLINT                                                         {  smallint() }
  | INTEGER                                                          {  integer() }
  | INT                                                              {  integer() }
  | BIGINT                                                           {  bigint() }

approximate_numeric_type /* Type */ :
    FLOAT                                          {  float() }
  | FLOAT left_paren precision right_paren   {  float_n() }
  | REAL                                           {  real() }
  | DOUBLE PRECISION                               {  double_precision() }

length /* string */ :
    unsigned_integer

character_length /* string */ :
    length

char_length_units /* string */ :
    CHARACTERS
  | OCTETS

precision /* string */ :
    unsigned_integer

scale /* string */ :
    unsigned_integer

boolean_type /* Type */ :
    BOOLEAN   {  boolean_type() }

datetime_type /* Type */ :
    DATE                                               {  date_type() }
  | TIME                                               {  time_type() }
  | TIME left_paren time_precision right_paren   {  time_prec_type() }
  | TIME with_or_without_time_zone                   {  time_tz_type() }
  | TIME left_paren time_precision right_paren
    with_or_without_time_zone                        {  time_prec_tz_type() }
  | TIMESTAMP                                          {  timestamp_type() }
  | TIMESTAMP
    left_paren timestamp_precision right_paren   {  timestamp_prec_type() }
  | TIMESTAMP with_or_without_time_zone              {  timestamp_tz_type() }
  | TIMESTAMP
    left_paren timestamp_precision right_paren
    with_or_without_time_zone                        {  timestamp_prec_tz_type() }

with_or_without_time_zone /* bool */ :
    WITH TIME ZONE      {  yes() }
  | WITHOUT TIME ZONE   {  no() }

time_precision /* string */ :
    time_fractional_seconds_precision

timestamp_precision /* string */ :
    time_fractional_seconds_precision

time_fractional_seconds_precision /* string */ :
    unsigned_integer

like_predicate /* CharacterLikePredicate */ :
    character_like_predicate

character_like_predicate /* CharacterLikePredicate */ :
    row_value_predicand character_like_predicate_part_2   {  like_pred() }

character_like_predicate_part_2 /* CharacterLikePredicate */ :
    LIKE character_pattern       {  like() }
  | NOT LIKE character_pattern   {  not_like() }

character_pattern /* CharacterValueExpression */ :
    character_value_expression

comparison_predicate /* ComparisonPredicate */ :
    row_value_predicand comparison_predicate_part_2   {  comparison() }

comparison_predicate_part_2 /* ComparisonPredicatePart2 */ :
    comp_op row_value_predicand   {  comparison_part() }

comp_op /* string */ :
    equals_operator
  | not_equals_operator
  | less_than_operator
  | greater_than_operator
  | less_than_or_equals_operator
  | greater_than_or_equals_operator

row_value_constructor /* RowValueConstructor */ :
    common_value_expression          {  RowValueConstructor() }
  | boolean_value_expression         {  RowValueConstructor() }
  | explicit_row_value_constructor   {  RowValueConstructor() }

explicit_row_value_constructor /* ExplicitRowValueConstructor */ :
    ROW left_paren row_value_constructor_element_list
    right_paren                                           {  explicit_row_value_constructor_1() }
  | row_subquery                                          {  ExplicitRowValueConstructor() }

row_value_constructor_element_list /* []ValueExpression */ :
    row_value_constructor_element                {  row_value_constructor_element_list_1() }
  | row_value_constructor_element_list comma
    row_value_constructor_element                {  row_value_constructor_element_list_2() }

row_value_constructor_element /* ValueExpression */ :
    value_expression

contextually_typed_row_value_constructor /* ContextuallyTypedRowValueConstructor */ :
    common_value_expression                        {  ContextuallyTypedRowValueConstructor() }
  | boolean_value_expression                       {  ContextuallyTypedRowValueConstructor() }
  | contextually_typed_value_specification         {  ContextuallyTypedRowValueConstructor() }
  | left_paren contextually_typed_value_specification
    right_paren                                    {  contextually_typed_row_value_constructor_1() }
  | left_paren
    contextually_typed_row_value_constructor_element comma
    contextually_typed_row_value_constructor_element_list
    right_paren                                    {  contextually_typed_row_value_constructor_2() }

contextually_typed_row_value_constructor_element_list /* []ContextuallyTypedRowValueConstructorElement */ :
    contextually_typed_row_value_constructor_element        {  contextually_typed_row_value_constructor_element_list_1() }
  | contextually_typed_row_value_constructor_element_list
    comma
    contextually_typed_row_value_constructor_element        {  contextually_typed_row_value_constructor_element_list_2() }

contextually_typed_row_value_constructor_element /* ContextuallyTypedRowValueConstructorElement */ :
    value_expression                         {  ContextuallyTypedRowValueConstructorElement() }
  | contextually_typed_value_specification   {  ContextuallyTypedRowValueConstructorElement() }

row_value_constructor_predicand /* RowValueConstructorPredicand */ :
    common_value_expression   {  RowValueConstructorPredicand() }
  | boolean_predicand         {  RowValueConstructorPredicand() }

query_specification /* SimpleTable */ :
    SELECT
    select_list
    table_expression   {  query_specification() }

select_list /* SelectList */ :
    asterisk                               {  asterisk() }
  | select_sublist
  | select_list comma select_sublist   {  select_list_2() }

select_sublist /* SelectList */ :
    derived_column       {  select_sublist_1() }
  | qualified_asterisk   {  SelectList() }

qualified_asterisk /* QualifiedAsteriskExpr */ :
    asterisked_identifier_chain period asterisk   {  qualified_asterisk() }

asterisked_identifier_chain /* IdentifierChain */ :
    asterisked_identifier

asterisked_identifier /* IdentifierChain */ :
    identifier

derived_column /* DerivedColumn */ :
    value_expression               {  derived_column() }
  | value_expression as_clause   {  derived_column_as() }

as_clause /* Identifier */ :
    AS column_name   {  identifier() }
  | column_name

string_value_expression /* CharacterValueExpression */ :
    character_value_expression

character_value_expression /* CharacterValueExpression */ :
    concatenation      {  CharacterValueExpression() }
  | character_factor   {  CharacterValueExpression() }

concatenation /* Concatenation */ :
    character_value_expression
    concatenation_operator
    character_factor             {  concatenation() }

character_factor /* CharacterPrimary */ :
    character_primary

character_primary /* CharacterPrimary */ :
    value_expression_primary   {  CharacterPrimary() }
  | string_value_function      {  CharacterPrimary() }

set_function_specification /* AggregateFunction */ :
    aggregate_function

table_reference /* TableReference */ :
    table_factor   {  TableReference() }
  | joined_table   {  TableReference() }

qualified_join /* QualifiedJoin */ :
    table_reference
    JOIN table_reference join_specification   {  qualified_join_1() }
  | table_reference join_type
    JOIN table_reference join_specification   {  qualified_join_2() }

table_factor /* TablePrimary */ :
    table_primary

table_primary /* TablePrimary */ :
    table_or_query_name                          {  table_primary_identifier() }
  | derived_table
  | derived_table correlation_or_recognition   {  table_primary_derived_2() }

correlation_or_recognition /* Correlation */ :
    correlation_name                    {  correlation_1() }
  | AS correlation_name                 {  correlation_1() }
  | correlation_name
    parenthesized_derived_column_list   {  correlation_2() }
  | AS correlation_name
    parenthesized_derived_column_list   {  correlation_2() }

derived_table /* TablePrimary */ :
    table_subquery

table_or_query_name /* Identifier */ :
    table_name

derived_column_list /* []Identifier */ :
    column_name_list

column_name_list /* []Identifier */ :
    column_name                              {  column_name_list_1() }
  | column_name_list comma column_name   {  column_name_list_2() }

parenthesized_derived_column_list /* []Identifier */ :
    left_paren derived_column_list
    right_paren                        {  parenthesized_derived_column_list() }

sequence_generator_definition /* Stmt */ :
    CREATE SEQUENCE
    sequence_generator_name                   {  sequence_generator_definition_1() }
  | CREATE SEQUENCE sequence_generator_name
    sequence_generator_options                {  sequence_generator_definition_2() }

sequence_generator_options /* []SequenceGeneratorOption */ :
    sequence_generator_option
  | sequence_generator_options sequence_generator_option

sequence_generator_option /* []SequenceGeneratorOption */ :
    common_sequence_generator_options

common_sequence_generator_options /* []SequenceGeneratorOption */ :
    common_sequence_generator_option    {  sequence_generator_options_1() }
  | common_sequence_generator_options
    common_sequence_generator_option    {  sequence_generator_options_2() }

common_sequence_generator_option /* SequenceGeneratorOption */ :
    sequence_generator_start_with_option   {  SequenceGeneratorOption() }
  | basic_sequence_generator_option

basic_sequence_generator_option /* SequenceGeneratorOption */ :
    sequence_generator_increment_by_option   {  SequenceGeneratorOption() }
  | sequence_generator_maxvalue_option       {  SequenceGeneratorOption() }
  | sequence_generator_minvalue_option       {  SequenceGeneratorOption() }
  | sequence_generator_cycle_option          {  basic_sequence_generator_option_4() }

sequence_generator_start_with_option /* SequenceGeneratorStartWithOption */ :
    START WITH
    sequence_generator_start_value   {  sequence_generator_start_with_option() }

sequence_generator_start_value /* Value */ :
    signed_numeric_literal

sequence_generator_increment_by_option /* SequenceGeneratorIncrementByOption */ :
    INCREMENT BY
    sequence_generator_increment   {  sequence_generator_increment_by_option() }

sequence_generator_increment /* Value */ :
    signed_numeric_literal

sequence_generator_maxvalue_option /* SequenceGeneratorMaxvalueOption */ :
    MAXVALUE
    sequence_generator_max_value   {  sequence_generator_maxvalue_option_1() }
  | NO MAXVALUE                      {  sequence_generator_maxvalue_option_2() }

sequence_generator_max_value /* Value */ :
    signed_numeric_literal

sequence_generator_minvalue_option /* SequenceGeneratorMinvalueOption */ :
    MINVALUE
    sequence_generator_min_value   {  sequence_generator_minvalue_option_1() }
  | NO MINVALUE                      {  sequence_generator_minvalue_option_2() }

sequence_generator_min_value /* Value */ :
    signed_numeric_literal

sequence_generator_cycle_option /* bool */ :
    CYCLE      {  yes() }
  | NO CYCLE   {  no() }

search_condition /* BooleanValueExpression */ :
    boolean_value_expression

value_expression /* ValueExpression */ :
    common_value_expression    {  ValueExpression() }
  | boolean_value_expression   {  ValueExpression() }

common_value_expression /* CommonValueExpression */ :
    numeric_value_expression    {  CommonValueExpression() }
  | string_value_expression     {  CommonValueExpression() }
  | datetime_value_expression   {  CommonValueExpression() }

table_expression /* TableExpression */ :
    from_clause                                    {  table_expression() }
  | from_clause where_clause                     {  table_expression_where() }
  | from_clause group_by_clause                  {  table_expression_group() }
  | from_clause where_clause group_by_clause   {  table_expression_where_group() }

group_by_clause /* []Identifier */ :
    GROUP BY grouping_element_list   {  group_by_clause() }

grouping_element_list /* []Identifier */ :
    grouping_element                                   {  grouping_element_list_1() }
  | grouping_element_list comma grouping_element   {  grouping_element_list_2() }

grouping_element /* Identifier */ :
    ordinary_grouping_set

ordinary_grouping_set /* Identifier */ :
    grouping_column_reference

grouping_column_reference /* Identifier */ :
    column_reference

boolean_value_expression /* BooleanValueExpression */ :
    boolean_term                                 {  boolean_value_expression_1() }
  | boolean_value_expression OR boolean_term   {  boolean_value_expression_2() }

boolean_term /* BooleanTerm */ :
    boolean_factor                      {  boolean_term_1() }
  | boolean_term AND boolean_factor   {  boolean_term_2() }

boolean_factor /* BooleanTest */ :
    boolean_test
  | NOT boolean_test   {  boolean_factor_not() }

boolean_test /* BooleanTest */ :
    boolean_primary                        {  boolean_test_1() }
  | boolean_primary IS truth_value       {  boolean_test_2() }
  | boolean_primary IS NOT truth_value   {  boolean_test_3() }

truth_value /* Value */ :
    TRUE      {  true() }
  | FALSE     {  false() }
  | UNKNOWN   {  unknown() }

boolean_primary /* BooleanPrimary */ :
    predicate           {  BooleanPrimary() }
  | boolean_predicand   {  BooleanPrimary() }

boolean_predicand /* BooleanPredicand */ :
    parenthesized_boolean_value_expression      {  BooleanPredicand() }
  | nonparenthesized_value_expression_primary   {  BooleanPredicand() }

parenthesized_boolean_value_expression /* BooleanValueExpression */ :
    left_paren boolean_value_expression right_paren   {  parenthesized_boolean_value_expression() }

unique_constraint_definition /* TableElement */ :
  unique_specification left_paren
  unique_column_list right_paren    {  unique_constraint_definition() }

unique_specification :
  PRIMARY KEY   {  ignore() }

unique_column_list /* []Identifier */ :
  column_name_list

table_row_value_expression /* RowValueConstructor */ :
    row_value_constructor

contextually_typed_row_value_expression /* ContextuallyTypedRowValueConstructor */ :
  contextually_typed_row_value_constructor

row_value_predicand /* RowValueConstructorPredicand */ :
  row_value_constructor_predicand

sql_schema_statement /* Stmt */ :
    sql_schema_definition_statement
  | sql_schema_manipulation_statement

sql_schema_definition_statement /* Stmt */ :
    schema_definition
  | table_definition
  | sequence_generator_definition

sql_schema_manipulation_statement /* Stmt */ :
    drop_schema_statement
  | drop_table_statement
  | alter_sequence_generator_statement   {  Stmt() }
  | drop_sequence_generator_statement

sql_transaction_statement /* Stmt */ :
    start_transaction_statement
  | commit_statement
  | rollback_statement

sql_session_statement /* Stmt */ :
    set_schema_statement
  | set_catalog_statement

datetime_value_function /* DatetimeValueFunction */ :
    current_date_value_function
  | current_time_value_function
  | current_timestamp_value_function
  | current_local_time_value_function
  | current_local_timestamp_value_function

current_date_value_function /* DatetimeValueFunction */ :
    CURRENT_DATE   {  current_date() }

current_time_value_function /* DatetimeValueFunction */ :
    CURRENT_TIME                                               {  current_time_1() }
  | CURRENT_TIME left_paren time_precision right_paren   {  current_time_2() }

current_local_time_value_function /* DatetimeValueFunction */ :
    LOCALTIME                                               {  localtime_1() }
  | LOCALTIME left_paren time_precision right_paren   {  localtime_2() }

current_timestamp_value_function /* DatetimeValueFunction */ :
    CURRENT_TIMESTAMP                                  {  current_timestamp_1() }
  | CURRENT_TIMESTAMP
    left_paren timestamp_precision right_paren   {  current_timestamp_2() }

current_local_timestamp_value_function /* DatetimeValueFunction */ :
    LOCALTIMESTAMP                                     {  localtimestamp_1() }
  | LOCALTIMESTAMP
    left_paren timestamp_precision right_paren   {  localtimestamp_2() }

joined_table /* QualifiedJoin */ :
    qualified_join

join_specification /* BooleanValueExpression */ :
    join_condition

join_condition /* BooleanValueExpression */ :
    ON search_condition   {  join_condition() }

join_type /* string */ :
    INNER
  | outer_join_type
  | outer_join_type OUTER   {  string() }

outer_join_type /* string */ :
    LEFT
  | RIGHT

null_predicate /* NullPredicate */ :
    row_value_predicand null_predicate_part_2   {  null_predicate() }

null_predicate_part_2 /* bool */ :
    IS NULL       {  yes() }
  | IS NOT NULL   {  no() }

predicate /* Predicate */ :
    comparison_predicate   {  Predicate() }
  | between_predicate      {  Predicate() }
  | like_predicate         {  Predicate() }
  | similar_predicate      {  Predicate() }
  | null_predicate         {  Predicate() }

start_transaction_statement /* Stmt */ :
  START TRANSACTION   {  start_transaction_statement() }

query_expression /* QueryExpression */ :
    query_expression_body                     {  query_expression() }
  | query_expression_body order_by_clause   {  query_expression_order() }
  | query_expression_body
    result_offset_clause                      {  query_expression_offset() }
  | query_expression_body order_by_clause
    result_offset_clause                      {  query_expression_order_offset() }
  | query_expression_body
    fetch_first_clause                        {  query_expression_fetch() }
  | query_expression_body order_by_clause
    fetch_first_clause                        {  query_expression_order_fetch() }
  | query_expression_body order_by_clause
    result_offset_clause
    fetch_first_clause                        {  query_expression_order_offset_fetch() }
  | query_expression_body
    result_offset_clause
    fetch_first_clause                        {  query_expression_offset_fetch() }

query_expression_body /* SimpleTable */ :
    query_term

query_term /* SimpleTable */ :
    query_primary

query_primary /* SimpleTable */ :
    simple_table

simple_table /* SimpleTable */ :
    query_specification
  | table_value_constructor

order_by_clause /* []SortSpecification */ :
    ORDER BY sort_specification_list   {  order_by() }

result_offset_clause /* ValueSpecification */ :
    OFFSET offset_row_count row_or_rows   {  result_offset_clause() }

fetch_first_clause /* ValueSpecification */ :
    FETCH FIRST
    fetch_first_quantity
    row_or_rows
    ONLY                     {  fetch_first_clause() }

fetch_first_quantity /* ValueSpecification */ :
    fetch_first_row_count

offset_row_count /* ValueSpecification */ :
    simple_value_specification

fetch_first_row_count /* ValueSpecification */ :
    simple_value_specification

row_or_rows :
    ROW
  | ROWS

similar_predicate /* SimilarPredicate */ :
    row_value_predicand similar_predicate_part_2   {  similar_pred() }

similar_predicate_part_2 /* SimilarPredicate */ :
    SIMILAR TO similar_pattern       {  similar() }
  | NOT SIMILAR TO similar_pattern   {  not_similar() }

similar_pattern /* CharacterValueExpression */ :
    character_value_expression

left_paren : OPERATOR_LEFT_PAREN

right_paren : OPERATOR_RIGHT_PAREN

asterisk /* string */ : OPERATOR_ASTERISK

plus_sign /* string */ : OPERATOR_PLUS

comma : OPERATOR_COMMA

minus_sign /* string */ : OPERATOR_MINUS

period : OPERATOR_PERIOD

solidus /* string */ : OPERATOR_SOLIDUS

colon : OPERATOR_COLON

less_than_operator : OPERATOR_LESS_THAN

equals_operator : OPERATOR_EQUALS

greater_than_operator : OPERATOR_GREATER_THAN

table_constraint_definition /* TableElement */ :
  table_constraint

table_constraint /* TableElement */ :
  unique_constraint_definition

column_definition /* TableElement */ :
    column_name data_type_or_domain_name   {  column_definition_1() }
  | column_name data_type_or_domain_name
    column_constraint_definition             {  column_definition_2() }

data_type_or_domain_name /* Type */ :
    data_type

column_constraint_definition /* bool */ :
    column_constraint

column_constraint /* bool */ :
    NOT NULL   {  yes() }

set_schema_statement /* Stmt */ :
    SET schema_name_characteristic   {  set_schema_stmt() }

schema_name_characteristic /* ValueSpecification */ :
    SCHEMA value_specification   {  schema_name_characteristic() }

aggregate_function /* AggregateFunction */ :
    COUNT left_paren asterisk right_paren   {  count_all() }
  | general_set_function

general_set_function /* AggregateFunction */ :
    set_function_type left_paren
    value_expression right_paren   {  general_set_function() }

set_function_type /* string */ :
    computational_operation

computational_operation /* string */ :
    AVG
  | MAX
  | MIN
  | SUM
  | COUNT

set_catalog_statement /* Stmt */ :
    SET catalog_name_characteristic   {  set_catalog_stmt() }

catalog_name_characteristic /* ValueSpecification */ :
    CATALOG value_specification   {  catalog_name_characteristic() }

drop_table_statement /* Stmt */ :
    DROP TABLE table_name   {  drop_table_statement() }

value_specification /* ValueSpecification */ :
    literal                       {  ValueSpecification() }
  | general_value_specification   {  ValueSpecification() }

unsigned_value_specification /* ValueSpecification */ :
    unsigned_literal              {  ValueSpecification() }
  | general_value_specification   {  ValueSpecification() }

general_value_specification /* GeneralValueSpecification */ :
    host_parameter_specification
  | CURRENT_CATALOG                  {  current_catalog() }
  | CURRENT_SCHEMA                   {  current_schema() }

simple_value_specification /* ValueSpecification */ :
    literal               {  ValueSpecification() }
  | host_parameter_name   {  ValueSpecification() }

host_parameter_specification /* GeneralValueSpecification */ :
    host_parameter_name

insert_statement /* Stmt */ :
    INSERT INTO
    insertion_target
    insert_columns_and_source   {  insert_statement() }

insertion_target /* Identifier */ :
    table_name

insert_columns_and_source /* InsertStatement */ :
  from_constructor

from_constructor /* InsertStatement */ :
    left_paren insert_column_list right_paren
    contextually_typed_table_value_constructor   {  from_constructor() }

insert_column_list /* []Identifier */ :
    column_name_list

value_expression_primary /* ValueExpressionPrimary */ :
    parenthesized_value_expression              {  ValueExpressionPrimary() }
  | nonparenthesized_value_expression_primary   {  ValueExpressionPrimary() }

parenthesized_value_expression /* ParenthesizedValueExpression */ :
    left_paren value_expression right_paren   {  parenthesized_value_expression() }

nonparenthesized_value_expression_primary /* NonparenthesizedValueExpressionPrimary */ :
    unsigned_value_specification   {  NonparenthesizedValueExpressionPrimary() }
  | column_reference               {  NonparenthesizedValueExpressionPrimary() }
  | set_function_specification     {  NonparenthesizedValueExpressionPrimary() }
  | routine_invocation             {  NonparenthesizedValueExpressionPrimary() }
  | case_expression                {  NonparenthesizedValueExpressionPrimary() }
  | cast_specification             {  NonparenthesizedValueExpressionPrimary() }
  | next_value_expression          {  NonparenthesizedValueExpressionPrimary() }

string_value_function /* CharacterValueFunction */ :
    character_value_function

character_value_function /* CharacterValueFunction */ :
    character_substring_function   {  CharacterValueFunction() }
  | fold                           {  CharacterValueFunction() }
  | trim_function                  {  CharacterValueFunction() }

character_substring_function /* CharacterSubstringFunction */ :
    SUBSTRING left_paren character_value_expression
    FROM start_position right_paren                   {  character_substring_function_1() }
  | SUBSTRING left_paren character_value_expression
    FROM start_position
    FOR string_length right_paren                     {  character_substring_function_2() }
  | SUBSTRING left_paren character_value_expression
    FROM start_position
    USING char_length_units right_paren               {  character_substring_function_3() }
  | SUBSTRING left_paren character_value_expression
    FROM start_position
    FOR string_length
    USING char_length_units right_paren               {  character_substring_function_4() }

fold /* RoutineInvocation */ :
    UPPER left_paren character_value_expression right_paren   {  upper() }
  | LOWER left_paren character_value_expression right_paren   {  lower() }

trim_function /* TrimFunction */ :
  TRIM left_paren trim_operands right_paren   {  trim_function() }

trim_operands /* TrimFunction */ :
    trim_source                                              {  trim_operands_1() }
  | FROM trim_source                                         {  trim_operands_1() }
  | trim_specification FROM trim_source                    {  trim_operands_2() }
  | trim_character FROM trim_source                        {  trim_operands_3() }
  | trim_specification trim_character FROM trim_source   {  trim_operands_4() }

trim_source /* CharacterValueExpression */ :
    character_value_expression

trim_specification /* string */ :
    LEADING
  | TRAILING
  | BOTH

trim_character /* CharacterValueExpression */ :
    character_value_expression

start_position /* NumericValueExpression */ :
    numeric_value_expression

string_length /* NumericValueExpression */ :
    numeric_value_expression

numeric_value_expression /* NumericValueExpression */ :
    term                                           {  numeric_value_expression_1() }
  | numeric_value_expression plus_sign term    {  numeric_value_expression_2() }
  | numeric_value_expression minus_sign term   {  numeric_value_expression_2() }

term /* Term */ :
    factor                     {  term_1() }
  | term asterisk factor   {  term_2() }
  | term solidus factor    {  term_2() }

factor /* NumericPrimary */ :
    numeric_primary
  | sign numeric_primary   {  factor_2() }

numeric_primary /* NumericPrimary */ :
    value_expression_primary   {  NumericPrimary() }
  | numeric_value_function     {  NumericPrimary() }

routine_invocation /* RoutineInvocation */ :
    routine_name sql_argument_list   {  routine_invocation() }

routine_name /* Identifier */ :
    qualified_identifier   {  routine_name() }

sql_argument_list /* []ValueExpression */ :
    left_paren right_paren                  {  sql_argument_list_1() }
  | left_paren sql_argument right_paren   {  sql_argument_list_2() }
  | left_paren sql_argument_list comma
    sql_argument right_paren                {  sql_argument_list_3() }

sql_argument /* ValueExpression */ :
    value_expression

%%

struct YYSymType {
mut:
  val int
  yys int
}
