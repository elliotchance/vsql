%%

routine_invocation:
  routine_name sql_argument_list {
    flag_if(mut yylex, any_dynamic_parameter($2.v as []ValueExpression), 'B033')
    flag_if(mut yylex, ($1.v as Identifier).entity_name == 'NOW', vsql_now)
    parsed_routine_name(mut yylex, ($1.v as Identifier).entity_name)
    $$.v = yy_box(RoutineInvocation{
      catalog_name:  ($1.v as Identifier).catalog_name
      schema_name:   ($1.v as Identifier).schema_name
      function_name: ($1.v as Identifier).entity_name
      args:          $2.v as []ValueExpression
    })
  }
// Only an aggregate function, such as PRODUCT(DISTINCT x), can have a <set
// quantifier> (see RoutineInvocation.compile).
| routine_name left_paren set_quantifier sql_argument right_paren {
    parsed_routine_name(mut yylex, ($1.v as Identifier).entity_name)
    $$.v = yy_box(RoutineInvocation{
      catalog_name:  ($1.v as Identifier).catalog_name
      schema_name:   ($1.v as Identifier).schema_name
      function_name: ($1.v as Identifier).entity_name
      args:          [$4.v as ValueExpression]
      distinct:      $3.v as bool
    })
  }

// A <routine name> can be qualified by a schema (and catalog), such as
// VSQL.GCD. It's parsed as an identifier chain, like a <column reference>,
// which it can only be told apart from by the "(" that follows it.
routine_name:
  identifier_chain {
    $$.v = yy_box(new_function_identifier(($1.v as IdentifierChain).identifier)!)
  }

sql_argument_list:
  left_paren right_paren { $$.v = yy_box([]ValueExpression{}) }
| left_paren sql_arguments right_paren { $$.v = $2.v }

sql_arguments:
  sql_argument { $$.v = yy_box([$1.v as ValueExpression]) }
| sql_arguments comma sql_argument {
    $$.v = yy_append($1.v, $3.v as ValueExpression)
  }

sql_argument:
  value_expression { $$.v = $1.v }

%%
