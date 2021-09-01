// ast.v contains the AST structures that represent the parsed SQL.

module vsql

// All possible root statments.
type Stmt = CreateTableStmt | DeleteStmt | DropTableStmt | InsertStmt | SelectStmt | UpdateStmt

// All possible expression entities.
type Expr = BinaryExpr | CallExpr | Identifier | NamedExpr | NoExpr | NullExpr | Parameter |
	UnaryExpr | Value

// CREATE TABLE ...
struct CreateTableStmt {
	table_name string
	columns    []Column
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
	exprs  SelectList
	from   string
	where  Expr
	offset int
	fetch  int // -1 to ignore
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

// Identifier is foo or "Foo"
struct Identifier {
	name string
}

struct UnaryExpr {
	op   string // NOT, -, +
	expr Expr
}

struct BinaryExpr {
	left  Expr
	op    string
	right Expr
}

// NoExpr is just a placeholder when there is no expression provided.
struct NoExpr {
	dummy int // empty struct not allowed
}

struct CallExpr {
	function_name string
	args          []Expr
}

// NamedExpr wraps an "AS" expression.
struct NamedExpr {
	name string
	expr Expr
}

struct ComparisonPredicatePart2 {
	op   string
	expr Expr
}

struct TableExpression {
	from_clause  Identifier
	where_clause Expr
}

struct DerivedColumn {
	expr      Expr
	as_clause Identifier // will be empty if not provided
}

type AsteriskExpr = bool

type SelectList = AsteriskExpr | []DerivedColumn

// Parameter is :foo. The colon is not included in the name.
struct Parameter {
	name string
}
