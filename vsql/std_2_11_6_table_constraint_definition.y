%%

// ISO/IEC 9075-2:2016(E), 11.6, <table constraint definition>
//
// Specify an integrity constraint.

table_constraint_definition:
  table_constraint { $$.v = $1.v as TableElement }

table_constraint:
  unique_constraint_definition {
    $$.v = TableElement($1.v as UniqueConstraintDefinition)
  }

%%
