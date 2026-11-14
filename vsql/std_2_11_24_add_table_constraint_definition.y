%%

// ISO/IEC 9075-2:2023, 11.24, <add table constraint definition>
//
// Add a constraint to a table.

add_table_constraint_definition:
  ADD table_constraint_definition {
    flag(mut yylex, 'F381')
    $$.v = yy_box(AddTableConstraintDefinition{$2.v as TableElement})
  }

%%
