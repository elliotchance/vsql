%%

routine_invocation:
  routine_name sql_argument_list {
    $$.v = RoutineInvocation{($1.v as Identifier).entity_name, $2.v as []ValueExpression}
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
