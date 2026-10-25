%%

// ISO/IEC 9075-2:2016(E), 11.6, <table constraint definition>
//
// Specify an integrity constraint.

table_constraint_definition:
  table_constraint { $$.v = $1.v as TableElement }
| constraint_name_definition unique_constraint_definition {
    $$.v = TableElement(UniqueConstraintDefinition{
      ...$2.v as UniqueConstraintDefinition
      name: $1.v as Identifier
    })
  }
| constraint_name_definition referential_constraint_definition {
    $$.v = TableElement(ReferentialConstraintDefinition{
      ...$2.v as ReferentialConstraintDefinition
      name: $1.v as Identifier
    })
  }
| constraint_name_definition check_constraint_definition {
    $$.v = TableElement(CheckConstraintDefinition{
      ...$2.v as CheckConstraintDefinition
      name: $1.v as Identifier
    })
  }

table_constraint:
  unique_constraint_definition {
    $$.v = TableElement($1.v as UniqueConstraintDefinition)
  }
| referential_constraint_definition {
    $$.v = TableElement($1.v as ReferentialConstraintDefinition)
  }
| check_constraint_definition {
    $$.v = TableElement($1.v as CheckConstraintDefinition)
  }

%%
