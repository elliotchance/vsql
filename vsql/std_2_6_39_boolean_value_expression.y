%%

// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>
//
// Specify a boolean value.

boolean_value_expression:
  boolean_term { $$.v = BooleanValueExpression{term: $1.v as BooleanTerm} }
| boolean_value_expression OR boolean_term {
    expr := $1.v as BooleanValueExpression
    $$.v = BooleanValueExpression{&expr, $3.v as BooleanTerm}
  }

boolean_term:
  boolean_factor { $$.v = BooleanTerm{factor: $1.v as BooleanTest} }
| boolean_term AND boolean_factor { 
    term := $1.v as BooleanTerm
    $$.v = BooleanTerm{&term, $3.v as BooleanTest}
  }

boolean_factor:
  boolean_test { $$.v = $1.v as BooleanTest }
| NOT boolean_test   {
    b := $2.v as BooleanTest
    $$.v = BooleanTest{b.expr, b.not, b.value, !b.inverse}
  }

// "BP IS NOT TV" is "NOT (BP IS TV)". A truth value is flagged with F571.
//
// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>, Syntax Rules, 2
// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>, Conformance Rules, 2

boolean_test:
  boolean_primary { $$.v = new_boolean_test($1.v as BooleanPrimary, false, none, false) }
| boolean_primary IS_TRUE {
    flag(mut yylex, 'F571')
    $$.v = new_boolean_test($1.v as BooleanPrimary, false, new_boolean_value(true),
      false)
  }
| boolean_primary IS_FALSE {
    flag(mut yylex, 'F571')
    $$.v = new_boolean_test($1.v as BooleanPrimary, false, new_boolean_value(false),
      false)
  }
| boolean_primary IS_UNKNOWN {
    flag(mut yylex, 'F571')
    $$.v = new_boolean_test($1.v as BooleanPrimary, false, new_unknown_value(),
      false)
  }
| boolean_primary IS_NOT_TRUE {
    flag(mut yylex, 'F571')
    $$.v = new_boolean_test($1.v as BooleanPrimary, true, new_boolean_value(true),
      false)
  }
| boolean_primary IS_NOT_FALSE {
    flag(mut yylex, 'F571')
    $$.v = new_boolean_test($1.v as BooleanPrimary, true, new_boolean_value(false),
      false)
  }
| boolean_primary IS_NOT_UNKNOWN {
    flag(mut yylex, 'F571')
    $$.v = new_boolean_test($1.v as BooleanPrimary, true, new_unknown_value(),
      false)
  }

boolean_primary:
  predicate { $$.v = BooleanPrimary($1.v as Predicate) }
| boolean_predicand { $$.v = BooleanPrimary($1.v as BooleanPredicand) }

boolean_predicand:
  parenthesized_boolean_value_expression {
    $$.v = BooleanPredicand($1.v as BooleanValueExpression)
  }
| nonparenthesized_value_expression_primary {
    $$.v = BooleanPredicand($1.v as NonparenthesizedValueExpressionPrimary)
  }

parenthesized_boolean_value_expression:
  left_paren boolean_value_expression right_paren { $$.v = $2.v }

%%
