%%

// ISO/IEC 9075-2:2023, 7.16, <query specification>
//
// Specify a table derived from the result of a <table expression>.

query_specification:
  SELECT select_list table_expression {
    table_expression := $3.v as TableExpression
    $$.v = yy_box(QuerySpecification{
      exprs:            $2.v as SelectList
      table_expression: &table_expression
    })
  }
| SELECT set_quantifier select_list table_expression {
    table_expression := $4.v as TableExpression
    $$.v = yy_box(QuerySpecification{
      exprs:            $3.v as SelectList
      table_expression: &table_expression
      distinct:         $2.v as bool
    })
  }
// This isn't in the standard, since a <table expression> must have a <from
// clause>. A bare asterisk needs a table, so it's only in the rules above.
| SELECT select_sublist_list {
    flag(mut yylex, vsql_select_without_from)
    $$.v = yy_box(new_query_specification_without_from($2.v as []SelectSublist, false))
  }
| SELECT set_quantifier select_sublist_list {
    flag(mut yylex, vsql_select_without_from)
    $$.v = yy_box(new_query_specification_without_from($3.v as []SelectSublist, $2.v as bool))
  }

// A bare asterisk can only appear alone, unlike a qualified asterisk which can
// be mixed with other items. Each is replaced by the columns of the table.
//
// ISO/IEC 9075-2:2023, 7.16, <query specification>, Syntax Rules, 7 and 10
select_list:
  asterisk { $$.v = yy_box(SelectList(AsteriskExpr(true))) }
| select_sublist_list { $$.v = yy_box(SelectList($1.v as []SelectSublist)) }

select_sublist_list:
  select_sublist { $$.v = yy_box([$1.v as SelectSublist]) }
| select_sublist_list comma select_sublist {
    mut new_select_list := ($1.v as []SelectSublist).clone()
    new_select_list << $3.v as SelectSublist
    $$.v = yy_box(new_select_list)
  }

select_sublist:
  derived_column { $$.v = yy_box(SelectSublist($1.v as DerivedColumn)) }
| qualified_asterisk { $$.v = yy_box(SelectSublist($1.v as QualifiedAsteriskExpr)) }

// was: asterisked_identifier_chain period asterisk
qualified_asterisk:
  asterisked_identifier_chain OPERATOR_PERIOD_ASTERISK {
    $$.v = yy_box(QualifiedAsteriskExpr{
      new_table_identifier(($1.v as IdentifierChain).identifier)!
    })
  }

// was: asterisked_identifier [ { period asterisked_identifier }... ]
asterisked_identifier_chain:
  identifier_chain { $$.v = $1.v }

derived_column:
  value_expression {
    $$.v = yy_box(DerivedColumn{$1.v as ValueExpression, Identifier{}})
  }
| value_expression as_clause {
    $$.v = yy_box(DerivedColumn{$1.v as ValueExpression, $2.v as Identifier})
  }

as_clause:
  AS column_name { $$.v = $2.v }
| column_name { $$.v = $1.v }

%%
