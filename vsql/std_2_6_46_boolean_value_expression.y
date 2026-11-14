%%

// ISO/IEC 9075-2:2023, 6.46, <boolean value expression>
//
// Specify a boolean value.

boolean_value_expression:
  boolean_term { $$.v = yy_box(BooleanValueExpression{term: $1.v as BooleanTerm}) }
| boolean_value_expression OR boolean_term {
    expr := $1.v as BooleanValueExpression
    $$.v = yy_box(BooleanValueExpression{&expr, $3.v as BooleanTerm})
  }

boolean_term:
  boolean_factor { $$.v = yy_box(BooleanTerm{factor: $1.v as BooleanTest}) }
| boolean_term AND boolean_factor { 
    term := $1.v as BooleanTerm
    $$.v = yy_box(BooleanTerm{&term, $3.v as BooleanTest})
  }

boolean_factor:
  boolean_test { $$.v = $1.v }
| NOT boolean_test   {
    b := $2.v as BooleanTest
    $$.v = yy_box(BooleanTest{b.expr, b.not, b.value, !b.inverse})
  }

// "BP IS NOT TV" is "NOT (BP IS TV)". A truth value is flagged with F571.
//
// ISO/IEC 9075-2:2023, 6.46, <boolean value expression>, Syntax Rules, 4
// ISO/IEC 9075-2:2023, 6.46, <boolean value expression>, Conformance Rules, 2

boolean_test:
  boolean_primary { $$.v = yy_box(new_boolean_test($1.v as BooleanPrimary, false, none, false)) }
| boolean_primary IS_TRUE {
    flag(mut yylex, 'F571')
    $$.v = yy_box(new_boolean_test($1.v as BooleanPrimary, false, new_boolean_value(true),
      false))
  }
| boolean_primary IS_FALSE {
    flag(mut yylex, 'F571')
    $$.v = yy_box(new_boolean_test($1.v as BooleanPrimary, false, new_boolean_value(false),
      false))
  }
| boolean_primary IS_UNKNOWN {
    flag(mut yylex, 'F571')
    $$.v = yy_box(new_boolean_test($1.v as BooleanPrimary, false, new_unknown_value(),
      false))
  }
| boolean_primary IS_NOT_TRUE {
    flag(mut yylex, 'F571')
    $$.v = yy_box(new_boolean_test($1.v as BooleanPrimary, true, new_boolean_value(true),
      false))
  }
| boolean_primary IS_NOT_FALSE {
    flag(mut yylex, 'F571')
    $$.v = yy_box(new_boolean_test($1.v as BooleanPrimary, true, new_boolean_value(false),
      false))
  }
| boolean_primary IS_NOT_UNKNOWN {
    flag(mut yylex, 'F571')
    $$.v = yy_box(new_boolean_test($1.v as BooleanPrimary, true, new_unknown_value(),
      false))
  }

boolean_primary:
  predicate { $$.v = yy_box(BooleanPrimary($1.v as Predicate)) }
| boolean_predicand { $$.v = yy_box(BooleanPrimary($1.v as BooleanPredicand)) }

boolean_predicand:
  parenthesized_boolean_value_expression {
    $$.v = yy_box(BooleanPredicand($1.v as BooleanValueExpression))
  }
| nonparenthesized_value_expression_primary {
    $$.v = yy_box(BooleanPredicand($1.v as NonparenthesizedValueExpressionPrimary))
  }

parenthesized_boolean_value_expression:
  left_paren boolean_value_expression right_paren { $$.v = $2.v }

%%
