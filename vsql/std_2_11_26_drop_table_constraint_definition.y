%%

// ISO/IEC 9075-2:2016(E), 11.26, <drop table constraint definition>
//
// Destroy a constraint on a table.

drop_table_constraint_definition:
  DROP CONSTRAINT constraint_name {
    $$.v = DropTableConstraintDefinition{$3.v as Identifier, 'RESTRICT'}
  }
| DROP CONSTRAINT constraint_name drop_behavior {
    $$.v = DropTableConstraintDefinition{$3.v as Identifier, $4.v as string}
  }

%%
