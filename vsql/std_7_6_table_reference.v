module vsql

// ISO/IEC 9075-2:2016(E), 7.6, <table reference>
//
// Reference a table.

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
