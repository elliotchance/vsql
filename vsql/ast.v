// ast.v contains the AST structures that represent the parsed SQL.

module vsql

// All possible root statments.
//
// QueryExpression is used for both SELECT and VALUES.
type Stmt = AlterSequenceGeneratorStatement
	| CommitStmt
	| DeleteStmt
	| DropSchemaStatement
	| DropSequenceGeneratorStatement
	| DropTableStatement
	| InsertStatement
	| QueryExpression
	| RollbackStatement
	| SchemaDefinition
	| SequenceGeneratorDefinition
	| SetCatalogStatement
	| SetSchemaStatement
	| StartTransactionStatement
	| TableDefinition
	| UpdateStatementSearched
