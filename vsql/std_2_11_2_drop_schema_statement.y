%%

// ISO/IEC 9075-2:2023, 11.2, <drop schema statement>, Conformance Rules, 1 and 2
drop_schema_statement:
  DROP SCHEMA schema_name drop_behavior {
    flag(mut yylex, 'F381')
    flag_if(mut yylex, $4.v as string == 'CASCADE', 'F032')
    $$.v = yy_box(Stmt(DropSchemaStatement{
      schema_name: $3.v as Identifier
      behavior:    $4.v as string
    }))
  }
| DROP SCHEMA if_exists schema_name drop_behavior {
    flag(mut yylex, 'F381')
    flag_if(mut yylex, $5.v as string == 'CASCADE', 'F032')
    flag(mut yylex, vsql_drop_schema_if_exists)
    $$.v = yy_box(Stmt(DropSchemaStatement{
      schema_name: $4.v as Identifier
      behavior:    $5.v as string
      if_exists:   true
    }))
  }

drop_behavior:
  CASCADE { $$.v = $1.v as string }
| RESTRICT { $$.v = $1.v as string }

%%
