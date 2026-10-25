%%

// ISO/IEC 9075-2:2016(E), 11.24, <add table constraint definition>
//
// Add a constraint to a table.

add_table_constraint_definition:
  ADD table_constraint_definition {
    $$.v = AddTableConstraintDefinition{$2.v as TableElement}
  }

%%
