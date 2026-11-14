%%

// The <drop behavior> is optional (V104-01, see vsql_drop_table_behavior).
//
// ISO/IEC 9075-2:2023, 11.31, <drop table statement>, Conformance Rules, 1
drop_table_statement:
  DROP TABLE table_name {
    flag(mut yylex, vsql_drop_table_behavior)
    $$.v = yy_box(Stmt(DropTableStatement{
      table_name: $3.v as Identifier
      behavior:   'RESTRICT'
    }))
  }
| DROP TABLE table_name drop_behavior {
    flag_if(mut yylex, $4.v as string == 'CASCADE', 'F032')
    $$.v = yy_box(Stmt(DropTableStatement{
      table_name: $3.v as Identifier
      behavior:   $4.v as string
    }))
  }
| DROP TABLE if_exists table_name {
    flag(mut yylex, vsql_drop_table_behavior)
    flag(mut yylex, vsql_drop_table_if_exists)
    $$.v = yy_box(Stmt(DropTableStatement{
      table_name: $4.v as Identifier
      behavior:   'RESTRICT'
      if_exists:  true
    }))
  }
| DROP TABLE if_exists table_name drop_behavior {
    flag_if(mut yylex, $5.v as string == 'CASCADE', 'F032')
    flag(mut yylex, vsql_drop_table_if_exists)
    $$.v = yy_box(Stmt(DropTableStatement{
      table_name: $4.v as Identifier
      behavior:   $5.v as string
      if_exists:  true
    }))
  }

// IF EXISTS isn't part of the standard (see the V011 features of the SQL
// Flagger). Like if_not_exists, it can't be an optional (empty) rule because IF
// can also start the name, such as DROP TABLE if.
if_exists:
  IF EXISTS

%%
