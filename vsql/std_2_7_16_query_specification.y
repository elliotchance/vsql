%%

// ISO/IEC 9075-2:2016(E), 7.16, <query specification>
//
// Specify a table derived from the result of a <table expression>.

query_specification:
  SELECT select_list table_expression {
    table_expression := $3.v as TableExpression
    $$.v = QuerySpecification{
      exprs:            $2.v as SelectList
      table_expression: &table_expression
    }
  }
| SELECT set_quantifier select_list table_expression {
    table_expression := $4.v as TableExpression
    $$.v = QuerySpecification{
      exprs:            $3.v as SelectList
      table_expression: &table_expression
      distinct:         $2.v as bool
    }
  }

// A bare asterisk can only appear alone, unlike a qualified asterisk which can
// be mixed with other items. Each is replaced by the columns of the table.
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 4 and 8
select_list:
  asterisk { $$.v = SelectList(AsteriskExpr(true)) }
| select_sublist_list { $$.v = SelectList($1.v as []SelectSublist) }

select_sublist_list:
  select_sublist { $$.v = [$1.v as SelectSublist] }
| select_sublist_list comma select_sublist {
    mut new_select_list := ($1.v as []SelectSublist).clone()
    new_select_list << $3.v as SelectSublist
    $$.v = new_select_list
  }

select_sublist:
  derived_column { $$.v = SelectSublist($1.v as DerivedColumn) }
| qualified_asterisk { $$.v = SelectSublist($1.v as QualifiedAsteriskExpr) }

// was: asterisked_identifier_chain period asterisk
qualified_asterisk:
  asterisked_identifier_chain OPERATOR_PERIOD_ASTERISK {
    $$.v = QualifiedAsteriskExpr{
      new_table_identifier(($1.v as IdentifierChain).identifier)!
    }
  }

// was: asterisked_identifier [ { period asterisked_identifier }... ]
asterisked_identifier_chain:
  identifier_chain { $$.v = $1.v as IdentifierChain }

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
