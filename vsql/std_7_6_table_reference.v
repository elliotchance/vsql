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

struct QualifiedJoin {
	left_table    TableReference
	join_type     string // 'INNER', 'LEFT' or 'RIGHT'
	right_table   TableReference
	specification BooleanValueExpression // ON condition
}
