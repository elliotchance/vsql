// ast.v contains the AST structures that represent the parsed SQL.

module vdb

// All possible root statments
type Stmt = CreateTableStmt | DeleteStmt | DropTableStmt | InsertStmt | SelectStmt | UpdateStmt

// CREATE TABLE ...
struct CreateTableStmt {
	table_name string
	columns    []Column
}

// DELETE ...
struct DeleteStmt {
	table_name string
	where      BinaryExpr
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
	value Value
	from  string
	where BinaryExpr
}

// UPDATE ...
struct UpdateStmt {
	table_name string
	set        map[string]Value
	where      BinaryExpr
}

struct BinaryExpr {
	col   string
	op    string
	value Value
}
