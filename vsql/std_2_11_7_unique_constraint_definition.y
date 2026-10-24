%%

unique_constraint_definition:
  unique_specification left_paren unique_column_list right_paren {
    $$.v = UniqueConstraintDefinition{$3.v as []Identifier}
  }

unique_specification:
  PRIMARY KEY

unique_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

%%
