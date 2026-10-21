module vsql

// ISO/IEC 9075-2:2016(E), 7.6, <table reference>
//
// Reference a table.

struct Correlation {
	name    Identifier
	columns []Identifier
}

struct TablePrimary {
	body        TablePrimaryBody
	correlation Correlation
}

type TableReference = QualifiedJoin | TablePrimary

enum JoinType {
	inner
	left
	right
}

fn (t JoinType) str() string {
	return match t {
		.inner { 'INNER' }
		.left { 'LEFT' }
		.right { 'RIGHT' }
	}
}

struct QualifiedJoin {
	left_table    TableReference
	join_type     JoinType
	right_table   TableReference
	specification BooleanValueExpression // ON condition
}
