%%

// The <drop behavior> is optional (V119-01, see vsql_drop_view_behavior).
//
// ISO/IEC 9075-2:2016(E), 11.33, <drop view statement>, Conformance Rules, 1
drop_view_statement:
  DROP VIEW table_name {
    flag(mut yylex, vsql_drop_view_behavior)
    $$.v = yy_box(Stmt(DropViewStatement{
      view_name: $3.v as Identifier
      behavior:  'RESTRICT'
    }))
  }
| DROP VIEW table_name drop_behavior {
    flag_if(mut yylex, $4.v as string == 'CASCADE', 'F032')
    $$.v = yy_box(Stmt(DropViewStatement{
      view_name: $3.v as Identifier
      behavior:  $4.v as string
    }))
  }

%%
