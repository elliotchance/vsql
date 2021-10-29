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
	| NoExpr
	| NullExpr
	| Parameter
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
		NoExpr {
			e.str()
		}
		NullExpr {
			e.pstr(params)
		}
		Parameter {
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
	name string
}

fn (e Identifier) str() string {
	return identifier_name(e.name)
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
			columns << identifier_name(col.name)
		}

		s += ' (${columns.join(', ')})'
	}

	return s
}

// Parameter is :foo. The colon is not included in the name.
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
