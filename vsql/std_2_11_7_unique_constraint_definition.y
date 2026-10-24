%%

unique_constraint_definition:
  unique_specification left_paren unique_column_list right_paren {
    $$.v = UniqueConstraintDefinition{
      columns:        $3.v as []Identifier
      is_primary_key: $1.v as bool
    }
  }

unique_specification:
  UNIQUE { $$.v = false }
| PRIMARY KEY { $$.v = true }

unique_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

%%
