%%

set_connection_statement:
  SET CONNECTION DEFAULT { $$.v = Stmt(SetConnectionStatement{}) }
| SET CONNECTION connection_name {
    $$.v = Stmt(SetConnectionStatement{$3.v as ValueSpecification})
  }

%%
