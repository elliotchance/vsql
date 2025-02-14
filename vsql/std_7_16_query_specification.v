module vsql

// ISO/IEC 9075-2:2016(E), 7.16, <query specification>
//
// Specify a table derived from the result of a <table expression>.

struct DerivedColumn {
	expr      ValueExpression
	as_clause Identifier // will be empty if not provided
}

type SelectList = AsteriskExpr | QualifiedAsteriskExpr | []DerivedColumn

type AsteriskExpr = bool

struct QualifiedAsteriskExpr {
	table_name Identifier
}

fn (e QualifiedAsteriskExpr) str() string {
	return '${e.table_name}.*'
}

struct QuerySpecification {
	exprs            SelectList
	table_expression TableExpression
	offset           ?ValueExpression
	fetch            ?ValueExpression
}

fn (mut q QuerySpecification) analyze(mut conn Connection) ![]DerivedColumn {
	match q.exprs {
		AsteriskExpr {
			mut catalog := conn.catalog()
			mut columns := []DerivedColumn{}
			for _, table in catalog.schema_tables('PUBLIC')! {
				for column in table.columns {
					columns << DerivedColumn{ValueExpression(CommonValueExpression(DatetimePrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(column.name))))), Identifier{
						sub_entity_name: column.name.sub_entity_name
					}}
				}
			}
			return columns
		}
		QualifiedAsteriskExpr {
			panic('here')
		}
		[]DerivedColumn {
			panic('here')
		}
	}
}
