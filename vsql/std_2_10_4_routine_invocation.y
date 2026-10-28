%%

routine_invocation:
  routine_name sql_argument_list {
    flag_if(mut yylex, ($2.v as []ValueExpression).any(is_dynamic_parameter(it)), 'B033')
    $$.v = RoutineInvocation{
      function_name: ($1.v as Identifier).entity_name
      args:          $2.v as []ValueExpression
    }
  }

routine_name:
  qualified_identifier {
    $$.v = new_function_identifier(($1.v as IdentifierChain).identifier)!
  }

sql_argument_list:
  left_paren right_paren { $$.v = []ValueExpression{} }
| left_paren sql_arguments right_paren { $$.v = $2.v as []ValueExpression }

sql_arguments:
  sql_argument { $$.v = [$1.v as ValueExpression] }
| sql_arguments comma sql_argument {
    $$.v = append_list($1.v as []ValueExpression, $3.v as ValueExpression)
  }

sql_argument:
  value_expression { $$.v = $1.v as ValueExpression }

%%
