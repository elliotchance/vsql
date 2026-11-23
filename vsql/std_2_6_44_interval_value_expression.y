%%

// ISO/IEC 9075-2:2023, 6.44, <interval value expression>
//
// Specify an interval value.
//
// The operators of an interval value expression are parsed as a
// numeric_value_expression (see compile_datetime_arithmetic). Only an
// interval_primary with an interval_qualifier is different, and it's a
// numeric_primary (like a numeric_value_function).

// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Conformance Rules, 1
interval_qualified_primary:
  value_expression_primary interval_qualifier {
    flag(mut yylex, 'F052')
    $$.v = yy_box(NumericPrimary(new_interval_qualified_primary($1.v as ValueExpressionPrimary, $2.v as IntervalQualifier)))
  }

%%
