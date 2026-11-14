%%

// ISO/IEC 9075-2:2023(E), 11.26, <drop table constraint definition>
//
// Destroy a constraint on a table.

// The <drop behavior> is optional (V105-02, see vsql_drop_constraint_behavior).
//
// ISO/IEC 9075-2:2023(E), 11.26, <drop table constraint definition>, Conformance Rules, 1
drop_table_constraint_definition:
  DROP CONSTRAINT constraint_name {
    flag(mut yylex, 'F381')
    flag(mut yylex, vsql_drop_constraint_behavior)
    $$.v = yy_box(DropTableConstraintDefinition{$3.v as Identifier, 'RESTRICT'})
  }
| DROP CONSTRAINT constraint_name drop_behavior {
    flag(mut yylex, 'F381')
    $$.v = yy_box(DropTableConstraintDefinition{$3.v as Identifier, $4.v as string})
  }

%%
