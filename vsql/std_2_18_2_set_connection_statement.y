%%

set_connection_statement:
  SET CONNECTION DEFAULT { $$.v = yy_box(Stmt(SetConnectionStatement{})) }
| SET CONNECTION connection_name {
    $$.v = yy_box(Stmt(SetConnectionStatement{$3.v as ValueSpecification}))
  }

%%
