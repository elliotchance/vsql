%%

// The <drop behavior> is optional (V002-01, see vsql_drop_table_behavior).
//
// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>, Conformance Rules, 1
drop_table_statement:
  DROP TABLE table_name {
    flag(mut yylex, vsql_drop_table_behavior)
    $$.v = Stmt(DropTableStatement{$3.v as Identifier, 'RESTRICT'})
  }
| DROP TABLE table_name drop_behavior {
    flag_if(mut yylex, $4.v as string == 'CASCADE', 'F032')
    $$.v = Stmt(DropTableStatement{$3.v as Identifier, $4.v as string})
  }

%%
