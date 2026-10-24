%%

// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>
//
// Specify a referential constraint.

referential_constraint_definition:
  FOREIGN KEY left_paren referencing_column_list right_paren
  references_specification {
    $$.v = new_referential_constraint_definition($4.v as []Identifier,
      $6.v as ReferentialConstraintDefinition)
  }

references_specification:
  REFERENCES referenced_table_and_columns {
    $$.v = $2.v as ReferentialConstraintDefinition
  }

referencing_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

referenced_table_and_columns:
  table_name {
    $$.v = ReferentialConstraintDefinition{
      referenced_table: $1.v as Identifier
    }
  }
| table_name left_paren referenced_column_list right_paren {
    $$.v = ReferentialConstraintDefinition{
      referenced_table:   $1.v as Identifier
      referenced_columns: $3.v as []Identifier
    }
  }

referenced_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

%%
