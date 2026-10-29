%%

connect_statement:
  CONNECT TO connection_target { $$.v = $3.v as Stmt }

connection_target:
  sql_server_name {
    $$.v = Stmt(ConnectStatement{ConnectionTarget{server_name: $1.v as ValueSpecification}})
  }
| sql_server_name AS connection_name {
    $$.v = Stmt(ConnectStatement{ConnectionTarget{
      server_name:     $1.v as ValueSpecification
      connection_name: $3.v as ValueSpecification
    }})
  }
| sql_server_name USER connection_user_name {
    $$.v = Stmt(ConnectStatement{ConnectionTarget{
      server_name:          $1.v as ValueSpecification
      connection_user_name: $3.v as ValueSpecification
    }})
  }
| sql_server_name AS connection_name USER connection_user_name {
    $$.v = Stmt(ConnectStatement{ConnectionTarget{
      server_name:          $1.v as ValueSpecification
      connection_name:      $3.v as ValueSpecification
      connection_user_name: $5.v as ValueSpecification
    }})
  }
| DEFAULT { $$.v = Stmt(ConnectStatement{}) }

%%
