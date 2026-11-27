module vsql

// ISO/IEC 9075-2:2023, 7.6, <table reference>
//
// Reference a table.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.17.11, Range variables

struct Correlation {
	name    Identifier
	columns []Identifier
	// degree is the number of columns of a view, when it's not zero. The query
	// of the view can have more columns than when the view was created (see
	// create_view_plan), which are left out.
	degree int
}

struct TablePrimary {
	body        TablePrimaryBody
	correlation Correlation
	// with_query is set when the table primary is a <query name> that's read
	// like a derived table (see table_or_query_name_primary). It identifies its
	// <with list element>, so that every read of it has the same result (see
	// WithResult).
	with_query voidptr
}

type TableReference = QualifiedJoin | TablePrimary

fn (e TableReference) pstr(params map[string]Value) string {
	match e {
		QualifiedJoin {
			natural := if e.specification is NaturalJoin { 'NATURAL ' } else { '' }
			return '${e.left_table.pstr(params)} ${natural}${e.join_type} JOIN ${e.right_table.pstr(params)} ${e.specification.pstr(params)}'.trim_right(' ')
		}
		TablePrimary {
			mut s := match e.body {
				Identifier { e.body.str() }
				QueryExpression { '(${e.body.pstr(params)})' }
				RecursiveQueryReference { e.body.query.name.str() }
			}

			if e.correlation.name.sub_entity_name != '' {
				s += ' AS ${e.correlation.name}'
			}

			if e.correlation.columns.len > 0 {
				mut columns := []string{}
				for column in e.correlation.columns {
					columns << column.str()
				}
				s += ' (${columns.join(', ')})'
			}

			return s
		}
	}
}

enum JoinType {
	inner
	left
	right
	full
}

fn (t JoinType) str() string {
	return match t {
		.inner { 'INNER' }
		.left { 'LEFT' }
		.right { 'RIGHT' }
		.full { 'FULL' }
	}
}

// left_table and right_table are references because a TableReference can be a
// QualifiedJoin, and V stores a sum type's value inline.
struct QualifiedJoin {
	left_table    &TableReference
	join_type     JoinType
	right_table   &TableReference
	specification JoinSpecification
}

// A JoinSpecification is an ON condition, the columns of a USING, or NATURAL.
type JoinSpecification = BooleanValueExpression | NaturalJoin | []Identifier

// NaturalJoin is a NATURAL join, which has no ON or USING.
struct NaturalJoin {}

fn (e JoinSpecification) pstr(params map[string]Value) string {
	return match e {
		BooleanValueExpression {
			'ON ${e.pstr(params)}'
		}
		NaturalJoin {
			''
		}
		[]Identifier {
			'USING (${e.map(it.str()).join(', ')})'
		}
	}
}

fn new_qualified_join(left_table TableReference, join_type JoinType, right_table TableReference, specification JoinSpecification) QualifiedJoin {
	return QualifiedJoin{&left_table, join_type, &right_table, specification}
}

// new_cross_join is a comma in FROM: the same as an inner join with a condition
// that's always true.
//
// ISO/IEC 9075-2:2023, 7.5, <from clause>, General Rules, 1.b
fn new_cross_join(left_table TableReference, right_table TableReference) QualifiedJoin {
	return new_qualified_join(left_table, .inner, right_table, true_condition())
}

// true_condition is a search condition that's always TRUE.
fn true_condition() BooleanValueExpression {
	return BooleanValueExpression{
		term: BooleanTerm{
			factor: new_boolean_test(BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_boolean_value(true))))),
				false, none, false)
		}
	}
}
