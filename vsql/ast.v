// ast.v contains the AST structures that represent the parsed SQL.

module vsql

// All possible root statments.
//
// QueryExpression is used for both SELECT and VALUES.
type Stmt = AlterTableStmt
	| CommitStmt
	| CreateSchemaStmt
	| CreateTableStmt
	| DeleteStmt
	| DropSchemaStmt
	| DropTableStmt
	| InsertStmt
	| QueryExpression
	| RollbackStmt
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
	| CurrentTimeExpr
	| CurrentTimestampExpr
	| Identifier
	| LikeExpr
	| LocalTimeExpr
	| LocalTimestampExpr
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
				'\'$e.str()\''
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
	table_name     string
	table_elements []TableElement
}

fn (s CreateTableStmt) columns() Columns {
	mut columns := []Column{}
	for c in s.table_elements {
		if c is ColumnDefinition {
			columns << Column{c.column_name.name, c.typ, c.not_null}
		}
	}

	return columns
}

// DELETE ...
struct DeleteStmt {
	table_name string
	where      Expr
}

// DROP TABLE ...
struct DropTableStmt {
	table_name string
}

// INSERT INTO ...
struct InsertStmt {
	table_name string
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
	table_name string
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

// Identifier is foo or "Foo"
struct Identifier {
	// name is the normalized name. That is, upper case for regular tokens or
	// the case is kept for delimited identifiers.
	name string
	// original is the original token string.
	original string
}

fn new_identifier(s string) Identifier {
	if s.len > 0 && s[0] == `"` {
		return Identifier{
			name: s[1..s.len - 1]
			original: s
		}
	}

	return Identifier{
		name: s.to_upper()
		original: s
	}
}

fn (e Identifier) str() string {
	return e.name
}

struct UnaryExpr {
	op   string // NOT, -, +
	expr Expr
}

fn (e UnaryExpr) str() string {
	return e.pstr(map[string]Value{})
}

fn (e UnaryExpr) pstr(params map[string]Value) string {
	return '$e.op ${e.expr.pstr(params)}'
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
	return '${e.left.pstr(params)} $e.op ${e.right.pstr(params)}'
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
	return '${e.function_name}($args)'
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
	if c.name.name == '' {
		return ''
	}

	mut s := ' AS $c.name'

	if c.columns.len > 0 {
		mut columns := []string{}
		for col in c.columns {
			columns << col.name
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
	return ':$e.name'
}

fn (e Parameter) pstr(params map[string]Value) string {
	p := params[e.name]

	if p.typ.uses_string() || p.typ.uses_time() {
		return '\'$p.str()\''
	}

	return p.str()
}

struct ColumnDefinition {
	column_name Identifier
	typ Type
	not_null bool
}

fn (e ColumnDefinition) str() string {
	mut s := '${e.column_name} ${e.typ}'
	if e.not_null {
		s += ' NOT NULL'
	}

	return s
}

struct UniqueConstraintDefinition {
	columns []Identifier
}

type TableElement = ColumnDefinition | UniqueConstraintDefinition

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
	return 'CURRENT_TIME($e.prec)'
}

struct CurrentTimestampExpr {
	prec int
}

fn (e CurrentTimestampExpr) str() string {
	return 'CURRENT_TIMESTAMP($e.prec)'
}

struct LocalTimeExpr {
	prec int
}

fn (e LocalTimeExpr) str() string {
	return 'LOCALTIME($e.prec)'
}

struct LocalTimestampExpr {
	prec int
}

fn (e LocalTimestampExpr) str() string {
	return 'LOCALTIMESTAMP($e.prec)'
}

struct CreateSchemaStmt {
	schema_name Identifier
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

	return s + ' USING $e.using)'
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
	return 'TRIM($e.specification ${e.character.pstr(params)} FROM ${e.source.pstr(params)})'
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
		return '${e.expr.pstr(params)} IS NOT $e.value.str()'
	}

	return '${e.expr.pstr(params)} IS $e.value.str()'
}

struct CastExpr {
	expr   Expr
	target Type
}

fn (e CastExpr) pstr(params map[string]Value) string {
	return 'CAST(${e.expr.pstr(params)} AS $e.target)'
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

struct AddColumnDefinition {
	column_definition ColumnDefinition
}

fn (e AddColumnDefinition) str() string {
	return 'ADD COLUMN ${e.column_definition.str()}'
}

struct AlterTableStmt {
	table_name Identifier
	action AddColumnDefinition
}

fn (e AlterTableStmt) str() string {
	return 'ALTER TABLE ${e.table_name.str()} ${e.action.str()}'
}
