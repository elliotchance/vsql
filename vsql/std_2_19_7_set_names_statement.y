%%

// ISO/IEC 9075-2:2023, 19.7, <set names statement>, Conformance Rules, 1 and 2

set_names_statement:
  SET NAMES value_specification {
    flag(mut yylex, 'F461')
    flag(mut yylex, 'F761')
    $$.v = yy_box(Stmt(SetNamesStatement{$3.v as ValueSpecification}))
  }

%%
