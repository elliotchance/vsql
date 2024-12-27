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
| left_paren sql_argument right_paren { $$.v = [$2.v as ValueExpression] }
| left_paren sql_argument_list comma sql_argument right_paren {
    $$.v = append_list($2.v as []ValueExpression, $4.v as ValueExpression)
  }

sql_argument:
  value_expression { $$.v = $1.v as ValueExpression }

%%
