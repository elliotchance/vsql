%%

// ISO/IEC 9075-2:2016(E), 10.8, <constraint name definition> and <constraint
// characteristics>
//
// Specify the name of a constraint and its characteristics.

// <constraint characteristics> aren't supported, so every constraint is
// INITIALLY IMMEDIATE NOT DEFERRABLE ENFORCED (Syntax Rules 1 to 3).
constraint_name_definition:
  CONSTRAINT constraint_name { $$.v = $2.v as Identifier }

%%
