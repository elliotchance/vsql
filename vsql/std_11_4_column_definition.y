%%

column_definition:
  column_name data_type_or_domain_name {
    $$.v = TableElement(Column{$1.v as Identifier, $2.v as Type, false})
  }
| column_name data_type_or_domain_name column_constraint_definition {
    $$.v = TableElement(Column{$1.v as Identifier, $2.v as Type, $3.v as bool})
  }

data_type_or_domain_name:
  data_type { $$.v = $1.v as Type }

column_constraint_definition:
  column_constraint { $$.v = $1.v as bool }

column_constraint:
  NOT NULL { $$.v = true }

%%
