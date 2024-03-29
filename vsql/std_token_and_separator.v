module vsql

// ISO/IEC 9075-2:2016(E), 5.2, <token> and <separator>
//
// # Function
//
// Specify lexical units (tokens and separators) that participate in SQL
// language.
//
// # Format
//~
//~ <concatenation operator> ::= "||"
//
// <non-reserved word> is added on top of the original <regular identifier> to
// allow non-reserved words to be used as identifiers. As far as I can tell,
// only <reserved word>s are restricted. See "9075-2:2016 5.2 #26".
//
//~
//~ <regular identifier> /* IdentifierChain */ ::=
//~     <identifier body>
//~   | <non-reserved word>   -> string_identifier
//~
//~ <identifier body> /* IdentifierChain */ ::=
//~     <identifier start>
//~
//~ <identifier start> /* IdentifierChain */ ::=
//~     ^identifier
//~
//~ <not equals operator> ::= "<>"
//~
//~ <greater than or equals operator> ::= ">="
//~
//~ <less than or equals operator> ::= "<="
//~
//~ <non-reserved word> /* string */ ::=
//~     A
//~   | ABSOLUTE
//~   | ACTION
//~   | ADA
//~   | ADD
//~   | ADMIN
//~   | AFTER
//~   | ALWAYS
//~   | ASC
//~   | ASSERTION
//~   | ASSIGNMENT
//~   | ATTRIBUTE
//~   | ATTRIBUTES
//~   | BEFORE
//~   | BERNOULLI
//~   | BREADTH
//~   | C
//~   | CASCADE
//~   | CATALOG
//~   | CATALOG_NAME
//~   | CHAIN
//~   | CHAINING
//~   | CHARACTER_SET_CATALOG
//~   | CHARACTER_SET_NAME
//~   | CHARACTER_SET_SCHEMA
//~   | CHARACTERISTICS
//~   | CHARACTERS
//~   | CLASS_ORIGIN
//~   | COBOL
//~   | COLLATION
//~   | COLLATION_CATALOG
//~   | COLLATION_NAME
//~   | COLLATION_SCHEMA
//~   | COLUMNS
//~   | COLUMN_NAME
//~   | COMMAND_FUNCTION
//~   | COMMAND_FUNCTION_CODE
//~   | COMMITTED
//~   | CONDITIONAL
//~   | CONDITION_NUMBER
//~   | CONNECTION
//~   | CONNECTION_NAME
//~   | CONSTRAINT_CATALOG
//~   | CONSTRAINT_NAME
//~   | CONSTRAINT_SCHEMA
//~   | CONSTRAINTS
//~   | CONSTRUCTOR
//~   | CONTINUE
//~   | CURSOR_NAME
//~   | DATA
//~   | DATETIME_INTERVAL_CODE
//~   | DATETIME_INTERVAL_PRECISION
//~   | DEFAULTS
//~   | DEFERRABLE
//~   | DEFERRED
//~   | DEFINED
//~   | DEFINER
//~   | DEGREE
//~   | DEPTH
//~   | DERIVED
//~   | DESC
//~   | DESCRIBE_CATALOG
//~   | DESCRIBE_NAME
//~   | DESCRIBE_PROCEDURE_SPECIFIC_CATALOG
//~   | DESCRIBE_PROCEDURE_SPECIFIC_NAME
//~   | DESCRIBE_PROCEDURE_SPECIFIC_SCHEMA
//~   | DESCRIBE_SCHEMA
//~   | DESCRIPTOR
//~   | DIAGNOSTICS
//~   | DISPATCH
//~   | DOMAIN
//~   | DYNAMIC_FUNCTION
//~   | DYNAMIC_FUNCTION_CODE
//~   | ENCODING
//~   | ENFORCED
//~   | ERROR
//~   | EXCLUDE
//~   | EXCLUDING
//~   | EXPRESSION
//~   | FINAL
//~   | FINISH
//~   | FINISH_CATALOG
//~   | FINISH_NAME
//~   | FINISH_PROCEDURE_SPECIFIC_CATALOG
//~   | FINISH_PROCEDURE_SPECIFIC_NAME
//~   | FINISH_PROCEDURE_SPECIFIC_SCHEMA
//~   | FINISH_SCHEMA
//~   | FIRST
//~   | FLAG
//~   | FOLLOWING
//~   | FORMAT
//~   | FORTRAN
//~   | FOUND
//~   | FULFILL
//~   | FULFILL_CATALOG
//~   | FULFILL_NAME
//~   | FULFILL_PROCEDURE_SPECIFIC_CATALOG
//~   | FULFILL_PROCEDURE_SPECIFIC_NAME
//~   | FULFILL_PROCEDURE_SPECIFIC_SCHEMA
//~   | FULFILL_SCHEMA
//~   | G
//~   | GENERAL
//~   | GENERATED
//~   | GO
//~   | GOTO
//~   | GRANTED
//~   | HAS_PASS_THROUGH_COLUMNS
//~   | HAS_PASS_THRU_COLS
//~   | HIERARCHY
//~   | IGNORE
//~   | IMMEDIATE
//~   | IMMEDIATELY
//~   | IMPLEMENTATION
//~   | INCLUDING
//~   | INCREMENT
//~   | INITIALLY
//~   | INPUT
//~   | INSTANCE
//~   | INSTANTIABLE
//~   | INSTEAD
//~   | INVOKER
//~   | ISOLATION
//~   | IS_PRUNABLE
//~   | JSON
//~   | K
//~   | KEEP
//~   | KEY
//~   | KEYS
//~   | KEY_MEMBER
//~   | KEY_TYPE
//~   | LAST
//~   | LENGTH
//~   | LEVEL
//~   | LOCATOR
//~   | M
//~   | MAP
//~   | MATCHED
//~   | MAXVALUE
//~   | MESSAGE_LENGTH
//~   | MESSAGE_OCTET_LENGTH
//~   | MESSAGE_TEXT
//~   | MINVALUE
//~   | MORE
//~   | MUMPS
//~   | NAME
//~   | NAMES
//~   | NESTED
//~   | NESTING
//~   | NEXT
//~   | NFC
//~   | NFD
//~   | NFKC
//~   | NFKD
//~   | NORMALIZED
//~   | NULLABLE
//~   | NULLS
//~   | NUMBER
//~   | OBJECT
//~   | OCTETS
//~   | OPTION
//~   | OPTIONS
//~   | ORDERING
//~   | ORDINALITY
//~   | OTHERS
//~   | OUTPUT
//~   | OVERFLOW
//~   | OVERRIDING
//~   | P
//~   | PAD
//~   | PARAMETER_MODE
//~   | PARAMETER_NAME
//~   | PARAMETER_ORDINAL_POSITION
//~   | PARAMETER_SPECIFIC_CATALOG
//~   | PARAMETER_SPECIFIC_NAME
//~   | PARAMETER_SPECIFIC_SCHEMA
//~   | PARTIAL
//~   | PASCAL
//~   | PASS
//~   | PASSING
//~   | PAST
//~   | PATH
//~   | PLACING
//~   | PLAN
//~   | PLI
//~   | PRECEDING
//~   | PRESERVE
//~   | PRIOR
//~   | PRIVATE
//~   | PRIVATE_PARAMETERS
//~   | PRIVATE_PARAMS_S
//~   | PRIVILEGES
//~   | PRUNE
//~   | PUBLIC
//~   | QUOTES
//~   | READ
//~   | RELATIVE
//~   | REPEATABLE
//~   | RESPECT
//~   | RESTART
//~   | RESTRICT
//~   | RETURNED_CARDINALITY
//~   | RETURNED_LENGTH
//~   | RETURNED_OCTET_LENGTH
//~   | RETURNED_SQLSTATE
//~   | RETURNING
//~   | RETURNS_ONLY_PASS_THROUGH
//~   | RET_ONLY_PASS_THRU
//~   | ROLE
//~   | ROUTINE
//~   | ROUTINE_CATALOG
//~   | ROUTINE_NAME
//~   | ROUTINE_SCHEMA
//~   | ROW_COUNT
//~   | SCALAR
//~   | SCALE
//~   | SCHEMA
//~   | SCHEMA_NAME
//~   | SCOPE_CATALOG
//~   | SCOPE_NAME
//~   | SCOPE_SCHEMA
//~   | SECTION
//~   | SECURITY
//~   | SELF
//~   | SEQUENCE
//~   | SERIALIZABLE
//~   | SERVER_NAME
//~   | SESSION
//~   | SETS
//~   | SIMPLE
//~   | SIZE
//~   | SOURCE
//~   | SPACE
//~   | SPECIFIC_NAME
//~   | START_CATALOG
//~   | START_NAME
//~   | START_PROCEDURE_SPECIFIC_CATALOG
//~   | START_PROCEDURE_SPECIFIC_NAME
//~   | START_PROCEDURE_SPECIFIC_SCHEMA
//~   | START_SCHEMA
//~   | STATE
//~   | STATEMENT
//~   | STRING
//~   | STRUCTURE
//~   | STYLE
//~   | SUBCLASS_ORIGIN
//~   | T
//~   | TABLE_NAME
//~   | TABLE_SEMANTICS
//~   | TEMPORARY
//~   | THROUGH
//~   | TIES
//~   | TOP_LEVEL_COUNT
//~   | TRANSACTION
//~   | TRANSACTION_ACTIVE
//~   | TRANSACTIONS_COMMITTED
//~   | TRANSACTIONS_ROLLED_BACK
//~   | TRANSFORM
//~   | TRANSFORMS
//~   | TRIGGER_CATALOG
//~   | TRIGGER_NAME
//~   | TRIGGER_SCHEMA
//~   | TYPE
//~   | UNBOUNDED
//~   | UNCOMMITTED
//~   | UNCONDITIONAL
//~   | UNDER
//~   | UNNAMED
//~   | USAGE
//~   | USER_DEFINED_TYPE_CATALOG
//~   | USER_DEFINED_TYPE_CODE
//~   | USER_DEFINED_TYPE_NAME
//~   | USER_DEFINED_TYPE_SCHEMA
//~   | UTF16
//~   | UTF32
//~   | UTF8
//~   | VIEW
//~   | WORK
//~   | WRAPPER
//~   | WRITE
//~   | ZONE

fn parse_string_identifier(s string) !IdentifierChain {
	return IdentifierChain{s}
}

fn parse_string(s string) !string {
	return s
}
