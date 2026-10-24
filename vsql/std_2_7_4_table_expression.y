%%

table_expression:
  table_expression_without_having { $$.v = $1.v as TableExpression }
| table_expression_without_having having_clause {
    table_expression := $1.v as TableExpression
    $$.v = TableExpression{
      ...table_expression
      having_clause: $2.v as BooleanValueExpression
    }
  }

table_expression_without_having:
  from_clause {
    $$.v = TableExpression{$1.v as TableReference, none, []Identifier{}, none}
  }
| from_clause where_clause {
    $$.v = TableExpression{
      $1.v as TableReference
      $2.v as BooleanValueExpression
      []Identifier{}
      none
    }
  }
| from_clause group_by_clause {
    $$.v = TableExpression{$1.v as TableReference, none, $2.v as []Identifier, none}
  }
| from_clause where_clause group_by_clause {
    $$.v = TableExpression{
      $1.v as TableReference
      $2.v as BooleanValueExpression
      $3.v as []Identifier
      none
    }
  }

%%
