%%

drop_schema_statement:
  DROP SCHEMA schema_name drop_behavior {
    flag(mut yylex, 'F381')
    flag_if(mut yylex, $4.v as string == 'CASCADE', 'F032')
    $$.v = Stmt(DropSchemaStatement{$3.v as Identifier, $4.v as string})
  }

drop_behavior:
  CASCADE { $$.v = $1.v as string }
| RESTRICT { $$.v = $1.v as string }

%%
