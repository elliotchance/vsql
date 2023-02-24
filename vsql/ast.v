// ast.v contains the AST structures that represent the parsed SQL.

module vsql

// All possible root statments.
//
// QueryExpression is used for both SELECT and VALUES.
type Stmt = AlterSequenceStmt
	| CommitStmt
	| CreateSchemaStmt
	| CreateSequenceStmt
	| CreateTableStmt
	| DeleteStmt
	| DropSchemaStmt
	| DropSequenceStmt
	| DropTableStmt
	| InsertStmt
	| QueryExpression
	| RollbackStmt
	| SetSchemaStmt
	| StartTransactionStmt
	| UpdateStmt

// All possible expression entities.
type Expr = BetweenExpr
	| BinaryExpr
	| CallExpr
	| CastExpr
	| CoalesceExpr
	| CountAllExpr
	| CurrentDateExpr
	| CurrentSchemaExpr
	| CurrentTimeExpr
	| CurrentTimestampExpr
	| Identifier
	| LikeExpr
	| LocalTimeExpr
	| LocalTimestampExpr
	| NextValueExpr
	| NoExpr
	| NullExpr
	| NullIfExpr
	| Parameter
	| QualifiedAsteriskExpr
	| QueryExpression
	| RowExpr
	| SimilarExpr
	| SubstringExpr
	| TrimExpr
	| TruthExpr
	| UnaryExpr
	| UntypedNullExpr
	| Value

fn (e Expr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e Expr) pstr(params map[string]Value) string {
	return match e {
		BetweenExpr {
			e.pstr(params)
		}
		BinaryExpr {
			e.pstr(params)
		}
		CallExpr {
			e.pstr(params)
		}
		CastExpr {
			e.pstr(params)
		}
		CoalesceExpr {
			e.pstr(params)
		}
		CountAllExpr {
			e.pstr(params)
		}
		CurrentSchemaExpr {
			e.str()
		}
		CurrentDateExpr {
			e.str()
		}
		CurrentTimeExpr {
			e.str()
		}
		CurrentTimestampExpr {
			e.str()
		}
		Identifier {
			e.str()
		}
		LikeExpr {
			e.pstr(params)
		}
		LocalTimeExpr {
			e.str()
		}
		LocalTimestampExpr {
			e.str()
		}
		NextValueExpr {
			e.str()
		}
		NoExpr {
			e.str()
		}
		NullExpr {
			e.pstr(params)
		}
		NullIfExpr {
			e.pstr(params)
		}
		Parameter {
			e.pstr(params)
		}
		QualifiedAsteriskExpr {
			e.str()
		}
		QueryExpression {
			e.pstr(params)
		}
		RowExpr {
			e.pstr(params)
		}
		SimilarExpr {
			e.pstr(params)
		}
		SubstringExpr {
			e.pstr(params)
		}
		TrimExpr {
			e.pstr(params)
		}
		TruthExpr {
			e.pstr(params)
		}
		UnaryExpr {
			e.pstr(params)
		}
		UntypedNullExpr {
			e.str()
		}
		Value {
			if e.typ.uses_string() || e.typ.uses_time() {
				'\'${e.str()}\''
			} else {
				e.str()
			}
		}
	}
}

type TableReference = QualifiedJoin | TablePrimary

struct QualifiedJoin {
	left_table    TableReference
	join_type     string // 'INNER', 'LEFT' or 'RIGHT'
	right_table   TableReference
	specification Expr // ON condition
}

struct QualifiedAsteriskExpr {
	table_name Identifier
}

fn (e QualifiedAsteriskExpr) str() string {
	return '${e.table_name}.*'
}

// SelectStmt for SELECT
// []RowExpr for VALUES ROW(), ROW() ...
type SimpleTable = SelectStmt | []RowExpr

fn (e SimpleTable) pstr(params map[string]Value) string {
	match e {
		SelectStmt {
			return '<subquery>'
		}
		[]RowExpr {
			mut elements := []string{}
			for element in e {
				elements << element.pstr(params)
			}

			return 'VALUES ${elements.join(', ')}'
		}
	}
}

type TablePrimaryBody = Identifier | QueryExpression

struct TablePrimary {
	body        TablePrimaryBody
	correlation Correlation
}

// CREATE TABLE ...
struct CreateTableStmt {
	table_name     Identifier
	table_elements []TableElement
}

fn (s CreateTableStmt) columns() Columns {
	mut columns := []Column{}
	for c in s.table_elements {
		if c is Column {
			columns << c
		}
	}

	return columns
}

// DELETE ...
struct DeleteStmt {
	table_name Identifier
	where      Expr
}

// DROP TABLE ...
struct DropTableStmt {
	table_name Identifier
}

// INSERT INTO ...
struct InsertStmt {
	table_name Identifier
	columns    []Identifier
	values     []Expr
}

// SELECT ...
struct SelectStmt {
	exprs            SelectList
	table_expression TableExpression
	offset           Expr
	fetch            Expr
}

// UPDATE ...
struct UpdateStmt {
	table_name Identifier
	set        map[string]Expr
	where      Expr
}

// NullExpr for "IS NULL" and "IS NOT NULL".
struct NullExpr {
	expr Expr
	not  bool
}

fn (e NullExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e NullExpr) pstr(params map[string]Value) string {
	if e.not {
		return '${e.expr.pstr(params)} IS NOT NULL'
	}

	return '${e.expr.pstr(params)} IS NULL'
}

// IdentifierChain wraps a single string that contains the chain of one or more
// identifiers, such as: "Foo".bar."BAZ"
struct IdentifierChain {
	identifier string
}

fn (identifier IdentifierChain) str() string {
	return identifier.identifier
}

// Identifier is used to describe a object within a schema (such as a table
// name) or a property of an object (like a column name of a table). You should
// not instantiate this directly, instead use the appropriate new_*_identifier()
// function.
//
// If you need the fully qualified (canonical) form of an identified you can use
// Connection.resolve_schema_identifier().
//
// snippet: v.Identifier
pub struct Identifier {
	// schema_name is optional. If not provided, it will use CURRENT_SCHEMA.
	schema_name string
	// entity_name would be the table name, sequence name, etc. Something inside
	// of a schema. It is case sensitive.
	entity_name string
	// sub_entity_name would represent a column name. It is case sensitive.
	sub_entity_name string
	// custom_id is a way to override the behavior of rendering and storage. This
	// is only used for internal identifiers.
	custom_id string
}

// new_table_identifier is the correct way to create a new Identifier that
// represents a table. It can take several forms:
//
//   foo                   => FOO
//   "foo"                 => foo
//   schema.Bar            => SCHEMA.BAR
//   "Schema".bar          => Schema.BAR
//   "Fully"."Qualified"   => Fully.Qualified
//
// It's important to note that when a schema is not provided it will be left
// blank. You will need to use Connection.resolve_schema_identifier() to fill in
// the missing schema.
//
// An error is returned if the identifer is not valid (cannot be parsed).
//
// Even though it's valid to have a '.' in an entity name (ie. "foo.bar"),
// new_table_identifier does not correct parse this yet.
fn new_table_identifier(s string) !Identifier {
	return new_identifier2(s)
}

fn new_function_identifier(s string) !Identifier {
	return new_identifier2(s)
}

fn new_schema_identifier(s string) !Identifier {
	return new_identifier1(s)
}

fn new_identifier1(s string) !Identifier {
	parts := split_identifier_parts(s)!

	match parts.len {
		1 {
			return Identifier{
				schema_name: parts[0]
			}
		}
		else {
			return error('invalid identifier: ${s}')
		}
	}
}

fn new_identifier2(s string) !Identifier {
	parts := split_identifier_parts(s)!

	match parts.len {
		1 {
			return Identifier{
				entity_name: parts[0]
			}
		}
		2 {
			return Identifier{
				schema_name: parts[0]
				entity_name: parts[1]
			}
		}
		else {
			return error('invalid identifier: ${s}')
		}
	}
}

// new_column_identifier is the correct way to create a new Identifier that
// represents a table column. It can take several forms:
//
//   col                            => COL
//   "col"                          => col
//   tbl.Bar                        => TBL.BAR
//   "Table".bar                    => Table.BAR
//   schema.tbl.Bar                 => SCHEMA.TBL.BAR
//   "Schema"."Table".bar           => Schema.Table.BAR
//   "Fully"."Qualified"."Column"   => Fully.Qualified.Column
//
// It's important to note that when a schema is not provided it will be left
// blank. You will need to use Connection.resolve_schema_identifier() to fill in
// the missing schema.
//
// An error is returned if the identifer is not valid (cannot be parsed).
//
// Even though it's valid to have a '.' in an entity name (ie. "foo.bar"),
// new_column_identifier does not correct parse this yet.
fn new_column_identifier(s string) !Identifier {
	return new_identifier3(s)
}

fn new_identifier3(s string) !Identifier {
	parts := split_identifier_parts(s)!

	match parts.len {
		1 {
			return Identifier{
				sub_entity_name: parts[0]
			}
		}
		2 {
			return Identifier{
				entity_name: parts[0]
				sub_entity_name: parts[1]
			}
		}
		3 {
			return Identifier{
				schema_name: parts[0]
				entity_name: parts[1]
				sub_entity_name: parts[2]
			}
		}
		else {
			return error('invalid identifier3: ${s} ${parts}')
		}
	}
}

// decode_identifier is only for internal use. It is the opposite of
// Identifier.id().
fn decode_identifier(s string) Identifier {
	parts := split_identifier_parts(s) or { panic('cannot parse identifier: ${s}') }

	return Identifier{
		schema_name: parts[0]
		entity_name: parts[1]
	}
}

fn split_identifier_parts(s string) ![]string {
	if s == '' {
		return error('cannot use empty string for identifier')
	}

	mut parts := []string{}
	mut s2 := s
	for s2 != '' {
		if s2[0] == `"` {
			s2 = s2[1..]
			index := s2.index('"') or { return error('invalid identifier chain: ${s}') }
			parts << s2[..index]
			s2 = s2[index + 1..]
		} else {
			mut index := s2.index('.') or { -1 }
			if index < 0 {
				parts << s2.to_upper()
				break
			}
			if index > 0 {
				parts << s2[..index].to_upper()
			}
			s2 = s2[index + 1..]
		}
	}

	return parts
}

fn requote_identifier(s string) string {
	if s.to_upper() == s {
		return s
	}

	return '"${s}"'
}

// id is the internal canonical name. How it is represented in memory and
// on-disk. As opposed to str() which is the human readable form.
fn (e Identifier) id() string {
	if e.custom_id != '' {
		return e.custom_id
	}

	mut parts := []string{}

	if e.schema_name != '' {
		parts << e.schema_name
	}

	if e.entity_name != '' {
		parts << e.entity_name
	}

	if e.sub_entity_name != '' {
		parts << e.sub_entity_name
	}

	return parts.join('.')
}

pub fn (e Identifier) str() string {
	if e.custom_id != '' {
		return e.custom_id
	}

	if e.schema_name != '' {
		if e.sub_entity_name == '' {
			return '${requote_identifier(e.schema_name)}.${requote_identifier(e.entity_name)}'
		}

		return '${requote_identifier(e.schema_name)}.${requote_identifier(e.entity_name)}.${requote_identifier(e.sub_entity_name)}'
	}

	if e.entity_name != '' {
		if e.sub_entity_name == '' {
			return requote_identifier(e.entity_name)
		}

		return '${requote_identifier(e.entity_name)}.${requote_identifier(e.sub_entity_name)}'
	}

	return requote_identifier(e.sub_entity_name)
}

struct UnaryExpr {
	op   string // NOT, -, +
	expr Expr
}

fn (e UnaryExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e UnaryExpr) pstr(params map[string]Value) string {
	return '${e.op} ${e.expr.pstr(params)}'
}

struct BinaryExpr {
	left  Expr
	op    string
	right Expr
}

fn (e BinaryExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e BinaryExpr) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} ${e.op} ${e.right.pstr(params)}'
}

// NoExpr is just a placeholder when there is no expression provided.
struct NoExpr {
	dummy int // empty struct not allowed
}

fn (e NoExpr) str() string {
	return '<missing expr>'
}

struct CallExpr {
	function_name string
	args          []Expr
}

fn (e CallExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e CallExpr) pstr(params map[string]Value) string {
	args := e.args.map(it.pstr(params)).join(', ')
	return '${e.function_name}(${args})'
}

struct ComparisonPredicatePart2 {
	op   string
	expr Expr
}

struct TableExpression {
	from_clause  TableReference
	where_clause Expr
	group_clause []Expr
}

struct DerivedColumn {
	expr      Expr
	as_clause Identifier // will be empty if not provided
}

type AsteriskExpr = bool

type SelectList = AsteriskExpr | QualifiedAsteriskExpr | []DerivedColumn

struct Correlation {
	name    Identifier
	columns []Identifier
}

fn (c Correlation) str() string {
	if c.name.sub_entity_name == '' {
		return ''
	}

	mut s := ' AS ${c.name}'

	if c.columns.len > 0 {
		mut columns := []string{}
		for col in c.columns {
			columns << col.sub_entity_name
		}

		s += ' (${columns.join(', ')})'
	}

	return s
}

// Parameter is :foo. The colon is not included in the name. Parameters are case
// sensitive.
struct Parameter {
	name string
}

fn (e Parameter) str() string {
	return ':${e.name}'
}

fn (e Parameter) pstr(params map[string]Value) string {
	p := params[e.name]

	if p.typ.uses_string() || p.typ.uses_time() {
		return '\'${p.str()}\''
	}

	return p.str()
}

struct UniqueConstraintDefinition {
	columns []Identifier
}

type TableElement = Column | UniqueConstraintDefinition

struct StartTransactionStmt {
}

struct CommitStmt {
}

struct RollbackStmt {
}

struct BetweenExpr {
	not       bool
	symmetric bool
	expr      Expr
	left      Expr
	right     Expr
}

fn (e BetweenExpr) pstr(params map[string]Value) string {
	return '${e.expr.pstr(params)} ' + if e.not {
		'NOT '
	} else {
		''
	} + 'BETWEEN ' + if e.symmetric {
		'SYMMETRIC '
	} else {
		''
	} + '${e.left.pstr(params)} AND ${e.right.pstr(params)}'
}

struct QueryExpression {
	body   SimpleTable
	fetch  Expr
	offset Expr
	order  []SortSpecification
}

fn (e QueryExpression) pstr(params map[string]Value) string {
	return '<subquery>'
}

struct RowExpr {
	exprs []Expr
}

fn (e RowExpr) pstr(params map[string]Value) string {
	mut values := []string{}
	for expr in e.exprs {
		values << expr.pstr(params)
	}

	return 'ROW(${values.join(', ')})'
}

// LikeExpr for "LIKE" and "NOT LIKE".
struct LikeExpr {
	left  Expr
	right Expr
	not   bool
}

fn (e LikeExpr) pstr(params map[string]Value) string {
	if e.not {
		return '${e.left.pstr(params)} NOT LIKE ${e.right.pstr(params)}'
	}

	return '${e.left.pstr(params)} LIKE ${e.right.pstr(params)}'
}

// SimilarExpr for "SIMILAR TO" and "NOT SIMILAR TO".
struct SimilarExpr {
	left  Expr
	right Expr
	not   bool
}

fn (e SimilarExpr) pstr(params map[string]Value) string {
	if e.not {
		return '${e.left.pstr(params)} NOT SIMILAR TO ${e.right.pstr(params)}'
	}

	return '${e.left.pstr(params)} SIMILAR TO ${e.right.pstr(params)}'
}

struct SortSpecification {
	expr   Expr
	is_asc bool
}

fn (e SortSpecification) pstr(params map[string]Value) string {
	if e.is_asc {
		return '${e.expr.pstr(params)} ASC'
	}

	return '${e.expr.pstr(params)} DESC'
}

struct CountAllExpr {}

fn (e CountAllExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e CountAllExpr) pstr(params map[string]Value) string {
	return 'COUNT(*)'
}

struct CurrentDateExpr {
}

fn (e CurrentDateExpr) str() string {
	return 'CURRENT_DATE'
}

struct CurrentTimeExpr {
	prec int
}

fn (e CurrentTimeExpr) str() string {
	return 'CURRENT_TIME(${e.prec})'
}

struct CurrentTimestampExpr {
	prec int
}

fn (e CurrentTimestampExpr) str() string {
	return 'CURRENT_TIMESTAMP(${e.prec})'
}

struct LocalTimeExpr {
	prec int
}

fn (e LocalTimeExpr) str() string {
	return 'LOCALTIME(${e.prec})'
}

struct LocalTimestampExpr {
	prec int
}

fn (e LocalTimestampExpr) str() string {
	return 'LOCALTIMESTAMP(${e.prec})'
}

struct CreateSchemaStmt {
	schema_name Identifier
}

struct DropSequenceStmt {
	sequence_name Identifier
}

struct DropSchemaStmt {
	schema_name Identifier
	behavior    string // CASCADE or RESTRICT
}

struct SubstringExpr {
	value Expr
	from  Expr   // NoExpr when missing
	@for  Expr   // NoExpr when missing
	using string // CHARACTERS or OCTETS or ''
}

fn (e SubstringExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e SubstringExpr) pstr(params map[string]Value) string {
	mut s := 'SUBSTRING(${e.value.pstr(params)}'

	if e.from !is NoExpr {
		s += ' FROM ${e.from.pstr(params)}'
	}

	if e.@for !is NoExpr {
		s += ' FOR ${e.@for.pstr(params)}'
	}

	return s + ' USING ${e.using})'
}

struct TrimExpr {
	specification string // LEADING, TRAILING or BOTH
	character     Expr   // NoExpr when missing
	source        Expr
}

fn (e TrimExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e TrimExpr) pstr(params map[string]Value) string {
	return 'TRIM(${e.specification} ${e.character.pstr(params)} FROM ${e.source.pstr(params)})'
}

// UntypedNullExpr (not to be confused with NullExpr) represents an untyped
// NULL. This exists as an expression (rather than a special value) because it's
// devoid of a type until it's used in an actual expression. Also, having it use
// it;s own SQLType creates a lot of branches in the codebase that require "this
// should not be possible" comments and panics.
struct UntypedNullExpr {}

fn (e UntypedNullExpr) str() string {
	return 'NULL'
}

// TruthExpr for "IS [ NOT ] { TRUE | FALSE | UNKNOWN }".
struct TruthExpr {
	expr  Expr
	not   bool
	value Value
}

fn (e TruthExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e TruthExpr) pstr(params map[string]Value) string {
	if e.not {
		return '${e.expr.pstr(params)} IS NOT ${e.value.str()}'
	}

	return '${e.expr.pstr(params)} IS ${e.value.str()}'
}

struct CastExpr {
	expr   Expr
	target Type
}

fn (e CastExpr) pstr(params map[string]Value) string {
	return 'CAST(${e.expr.pstr(params)} AS ${e.target})'
}

struct CoalesceExpr {
	exprs []Expr
}

fn (e CoalesceExpr) pstr(params map[string]Value) string {
	return 'COALESCE(${e.exprs.map(it.pstr(params)).join(', ')})'
}

struct NullIfExpr {
	a Expr
	b Expr
}

fn (e NullIfExpr) pstr(params map[string]Value) string {
	return 'NULLIF(${e.a.pstr(params)}, ${e.b.pstr(params)})'
}

// CREATE SEQUENCE ...
struct CreateSequenceStmt {
	name    Identifier
	options []SequenceGeneratorOption
}

// ALTER SEQUENCE ...
struct AlterSequenceStmt {
	name    Identifier
	options []SequenceGeneratorOption
}

type SequenceGeneratorOption = SequenceGeneratorCycleOption
	| SequenceGeneratorIncrementByOption
	| SequenceGeneratorMaxvalueOption
	| SequenceGeneratorMinvalueOption
	| SequenceGeneratorRestartOption
	| SequenceGeneratorStartWithOption

struct SequenceGeneratorStartWithOption {
	start_value Expr
}

struct SequenceGeneratorRestartOption {
	restart_value Expr // NoExpr is automatic
}

struct SequenceGeneratorIncrementByOption {
	increment_by Expr
}

struct SequenceGeneratorMinvalueOption {
	min_value Expr // NoExpr = NO MINVALUE
}

struct SequenceGeneratorMaxvalueOption {
	max_value Expr // NoExpr = NO MAXVALUE
}

struct SequenceGeneratorCycleOption {
	cycle bool
}

// NextValueExpr for "NEXT VALUE FOR <sequence generator name>"
struct NextValueExpr {
	name Identifier
}

fn (e NextValueExpr) str() string {
	return 'NEXT VALUE FOR ${e.name}'
}

// CURRENT_SCHEMA
struct CurrentSchemaExpr {
}

fn (e CurrentSchemaExpr) str() string {
	return 'CURRENT_SCHEMA'
}

// SET SCHEMA
struct SetSchemaStmt {
	schema_name Expr
}

fn (e SetSchemaStmt) pstr(params map[string]Value) string {
	return 'SET SCHEMA ${e.schema_name.pstr(params)}'
}
