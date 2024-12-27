%%

table_expression:
  from_clause {
    $$.v = TableExpression{$1.v as TableReference, none, []Identifier{}}
  }
| from_clause where_clause {
    $$.v = TableExpression{
      $1.v as TableReference
      $2.v as BooleanValueExpression
      []Identifier{}
    }
  }
| from_clause group_by_clause {
    $$.v = TableExpression{$1.v as TableReference, none, $2.v as []Identifier}
  }
| from_clause where_clause group_by_clause {
    $$.v = TableExpression{
      $1.v as TableReference
      $2.v as BooleanValueExpression
      $3.v as []Identifier
    }
  }

%%
