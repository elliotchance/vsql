// ast.v contains the AST structures that represent the parsed SQL.

module vsql

// All possible root statments.
//
// QueryExpression is used for both SELECT and VALUES.
type Stmt = CommitStmt
	| CreateTableStmt
	| DeleteStmt
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
	| Identifier
	| LikeExpr
	| NoExpr
	| NullExpr
	| Parameter
	| QueryExpression
	| RowExpr
	| UnaryExpr
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
		Identifier {
			e.str()
		}
		LikeExpr {
			e.pstr(params)
		}
		NoExpr {
			e.str()
		}
		NullExpr {
			e.pstr(params)
		}
		Parameter {
			e.pstr(params)
		}
		QueryExpression {
			e.pstr(params)
		}
		RowExpr {
			e.pstr(params)
		}
		UnaryExpr {
			e.pstr(params)
		}
		Value {
			if e.typ.uses_string() {
				'\'$e.str()\''
			} else {
				e.str()
			}
		}
	}
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
		if c is Column {
			columns << c
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
	from_clause  TablePrimary
	where_clause Expr
}

struct DerivedColumn {
	expr      Expr
	as_clause Identifier // will be empty if not provided
}

type AsteriskExpr = bool

type SelectList = AsteriskExpr | []DerivedColumn

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

	if p.typ.uses_string() {
		return '\'$p.str()\''
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
