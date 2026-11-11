%%

// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>
//
// Specify a referential constraint.

referential_constraint_definition:
  FOREIGN KEY left_paren referencing_column_list right_paren
  references_specification {
    $$.v = yy_box(new_referential_constraint_definition($4.v as []Identifier,
      $6.v as ReferentialConstraintDefinition))
  }

references_specification:
  REFERENCES referenced_table_and_columns {
    $$.v = $2.v
  }
| REFERENCES referenced_table_and_columns referential_triggered_action {
    $$.v = yy_box(ReferentialConstraintDefinition{
      ...$2.v as ReferentialConstraintDefinition
      update_rule: ($3.v as ReferentialConstraintDefinition).update_rule
      delete_rule: ($3.v as ReferentialConstraintDefinition).delete_rule
    })
  }

referencing_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

referenced_table_and_columns:
  table_name {
    $$.v = yy_box(ReferentialConstraintDefinition{
      referenced_table: $1.v as Identifier
    })
  }
| table_name left_paren referenced_column_list right_paren {
    $$.v = yy_box(ReferentialConstraintDefinition{
      referenced_table:   $1.v as Identifier
      referenced_columns: $3.v as []Identifier
    })
  }

referenced_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>, Conformance Rules, 3 and 4
referential_triggered_action:
  update_rule {
    flag(mut yylex, 'F701')
    $$.v = yy_box(ReferentialConstraintDefinition{
      update_rule: $1.v as string
    })
  }
| update_rule delete_rule {
    flag(mut yylex, 'F701')
    flag(mut yylex, 'F191')
    $$.v = yy_box(ReferentialConstraintDefinition{
      update_rule: $1.v as string
      delete_rule: $2.v as string
    })
  }
| delete_rule {
    flag(mut yylex, 'F191')
    $$.v = yy_box(ReferentialConstraintDefinition{
      delete_rule: $1.v as string
    })
  }
| delete_rule update_rule {
    flag(mut yylex, 'F701')
    flag(mut yylex, 'F191')
    $$.v = yy_box(ReferentialConstraintDefinition{
      update_rule: $2.v as string
      delete_rule: $1.v as string
    })
  }

update_rule:
  ON UPDATE referential_action { $$.v = $3.v as string }

delete_rule:
  ON DELETE referential_action { $$.v = $3.v as string }

// RESTRICT isn't supported (T191).
referential_action:
  CASCADE { $$.v = 'CASCADE' }
| SET NULL { $$.v = 'SET NULL' }
| SET DEFAULT { $$.v = 'SET DEFAULT' }
| NO ACTION { $$.v = 'NO ACTION' }

%%
