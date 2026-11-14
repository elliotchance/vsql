%%

unique_constraint_definition:
  unique_specification left_paren unique_column_list right_paren {
    $$.v = yy_box(UniqueConstraintDefinition{
      columns:        $3.v as []Identifier
      is_primary_key: $1.v as bool
    })
  }
// A PRIMARY KEY can't have a <unique null treatment>, since its columns can't
// be NULL, so it's a syntax error.
//
// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 5
// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Conformance Rules, 4
| UNIQUE unique_null_treatment left_paren unique_column_list right_paren {
    flag(mut yylex, 'F292')
    $$.v = yy_box(UniqueConstraintDefinition{
      columns:            $4.v as []Identifier
      nulls_not_distinct: $2.v as bool
    })
  }

unique_specification:
  UNIQUE { $$.v = false }
| PRIMARY KEY { $$.v = true }

unique_column_list:
  column_name_list { $$.v = $1.v }

%%
