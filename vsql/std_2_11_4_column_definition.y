%%

// ISO/IEC 9075-2:2016(E), 11.4, <column definition>
//
// Define a column of a base table.

// The column is the first element, and each <unique specification>,
// <references specification> or <check constraint definition> adds a table
// constraint (see add_column_constraint).
column_definition:
  column_name data_type_or_domain_name {
    $$.v = [TableElement(Column{name: $1.v as Identifier, typ: $2.v as Type})]
  }
| column_name data_type_or_domain_name default_clause {
    $$.v = [
      TableElement(Column{
        name:          $1.v as Identifier
        typ:           $2.v as Type
        default_value: $3.v as DefaultOption
      }),
    ]
  }
| column_definition column_constraint_definition {
    $$.v = add_column_constraint($1.v as []TableElement, $2.v as ColumnConstraint)
  }

data_type_or_domain_name:
  data_type { $$.v = $1.v as Type }

column_constraint_definition:
  column_constraint { $$.v = $1.v as ColumnConstraint }
| constraint_name_definition NOT NULL {
    $$.v = ColumnConstraint(NotNullConstraint{name: $1.v as Identifier})
  }
| constraint_name_definition unique_specification {
    $$.v = ColumnConstraint(UniqueConstraintDefinition{
      name:           $1.v as Identifier
      is_primary_key: $2.v as bool
    })
  }
| constraint_name_definition references_specification {
    $$.v = ColumnConstraint(ReferentialConstraintDefinition{
      ...$2.v as ReferentialConstraintDefinition
      name: $1.v as Identifier
    })
  }
| constraint_name_definition check_constraint_definition {
    $$.v = ColumnConstraint(CheckConstraintDefinition{
      ...$2.v as CheckConstraintDefinition
      name: $1.v as Identifier
    })
  }

column_constraint:
  NOT NULL { $$.v = ColumnConstraint(NotNullConstraint{}) }
| unique_specification {
    $$.v = ColumnConstraint(UniqueConstraintDefinition{is_primary_key: $1.v as bool})
  }
| references_specification {
    $$.v = ColumnConstraint($1.v as ReferentialConstraintDefinition)
  }
| check_constraint_definition {
    $$.v = ColumnConstraint($1.v as CheckConstraintDefinition)
  }

%%
