%%

disconnect_statement:
  DISCONNECT DEFAULT { $$.v = Stmt(DisconnectStatement{}) }
| DISCONNECT connection_name {
    $$.v = Stmt(DisconnectStatement{connection_name: $2.v as ValueSpecification})
  }
| DISCONNECT ALL { $$.v = Stmt(DisconnectStatement{all: true}) }
| DISCONNECT CURRENT { $$.v = Stmt(DisconnectStatement{current: true}) }

%%
