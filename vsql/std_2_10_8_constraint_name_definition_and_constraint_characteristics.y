%%

// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint
// characteristics>
//
// Specify the name of a constraint and its characteristics.

constraint_name_definition:
  CONSTRAINT constraint_name { $$.v = $2.v as Identifier }

// Each <constraint characteristic> is added to the constraint before it (see
// with_constraint_characteristic), so that a NOT DEFERRABLE after a column
// constraint can't be mistaken for the start of a NOT NULL. <constraint
// enforcement> isn't supported, so every constraint is ENFORCED (Syntax Rule
// 3).
constraint_characteristic:
  DEFERRABLE {
    flag(mut yylex, 'F721')
    $$.v = 'DEFERRABLE'
  }
| NOT DEFERRABLE {
    flag(mut yylex, 'F721')
    $$.v = 'NOT DEFERRABLE'
  }
| INITIALLY DEFERRED {
    flag(mut yylex, 'F721')
    $$.v = 'INITIALLY DEFERRED'
  }
| INITIALLY IMMEDIATE {
    flag(mut yylex, 'F721')
    $$.v = 'INITIALLY IMMEDIATE'
  }

%%
