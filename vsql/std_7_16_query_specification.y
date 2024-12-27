%%

query_specification:
  SELECT select_list table_expression {
    $$.v = QuerySpecification{
      exprs:            $2.v as SelectList
      table_expression: $3.v as TableExpression
    }
  }

select_list:
  asterisk { $$.v = SelectList(AsteriskExpr(true)) }
| select_sublist { $$.v = $1.v as SelectList }
| select_list comma select_sublist {
    mut new_select_list := (($1.v as SelectList) as []DerivedColumn).clone()
    new_select_list << (($3.v as SelectList) as []DerivedColumn)[0]
    $$.v = SelectList(new_select_list)
  }

select_sublist:
  derived_column { $$.v = SelectList([$1.v as DerivedColumn]) }
| qualified_asterisk { $$.v = SelectList($1.v as QualifiedAsteriskExpr) }

// was: asterisked_identifier_chain period asterisk
qualified_asterisk:
  asterisked_identifier_chain OPERATOR_PERIOD_ASTERISK {
    $$.v = QualifiedAsteriskExpr{
      new_column_identifier(($1.v as IdentifierChain).identifier)!
    }
  }

asterisked_identifier_chain:
  asterisked_identifier { $$.v = $1.v as IdentifierChain }

asterisked_identifier:
  identifier { $$.v = $1.v as IdentifierChain }

derived_column:
  value_expression {
    $$.v = DerivedColumn{$1.v as ValueExpression, Identifier{}}
  }
| value_expression as_clause {
    $$.v = DerivedColumn{$1.v as ValueExpression, $2.v as Identifier}
  }

as_clause:
  AS column_name { $$.v = $2.v as Identifier }
| column_name { $$.v = $1.v as Identifier }

%%
