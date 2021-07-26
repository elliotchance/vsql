// ast.v contains the AST structures that represent the parsed SQL.

module vsql

// All possible root statments.
type Stmt = CreateTableStmt | DeleteStmt | DropTableStmt | InsertStmt | SelectStmt | UpdateStmt

// All possible expression entities.
type Expr = BinaryExpr | Identifier | NoExpr | NullExpr | Value

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
	columns    []string
	values     []Value
}

// SELECT ...
struct SelectStmt {
	exprs []Expr
	from  string
	where Expr
}

// UPDATE ...
struct UpdateStmt {
	table_name string
	set        map[string]Value
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

struct BinaryExpr {
	col   string
	op    string
	value Value
}

// NoExpr is just a placeholder when there is no expression provided.
struct NoExpr {
	dummy int // empty struct not allowed
}
