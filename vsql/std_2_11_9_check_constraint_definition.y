%%

// ISO/IEC 9075-2:2023(E), 11.9, <check constraint definition>
//
// Specify a condition for the SQL-data.

check_constraint_definition:
  CHECK left_paren search_condition right_paren {
    $$.v = yy_box(CheckConstraintDefinition{
      search_condition: $3.v as BooleanValueExpression
    })
  }

%%
