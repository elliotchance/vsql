%%

disconnect_statement:
  DISCONNECT DEFAULT { $$.v = yy_box(Stmt(DisconnectStatement{})) }
| DISCONNECT connection_name {
    $$.v = yy_box(Stmt(DisconnectStatement{connection_name: $2.v as ValueSpecification}))
  }
| DISCONNECT ALL { $$.v = yy_box(Stmt(DisconnectStatement{all: true})) }
| DISCONNECT CURRENT { $$.v = yy_box(Stmt(DisconnectStatement{current: true})) }

%%
