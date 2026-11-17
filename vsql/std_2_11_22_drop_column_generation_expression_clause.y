%%

// ISO/IEC 9075-2:2023, 11.22, <drop column generation expression clause>, Conformance Rules, 1
drop_column_generation_expression_clause:
  DROP EXPRESSION {
    flag(mut yylex, 'F385')
    $$.v = yy_box(DropColumnGenerationExpressionClause{})
  }

%%
