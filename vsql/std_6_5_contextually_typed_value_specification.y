%%

contextually_typed_value_specification:
  implicitly_typed_value_specification { $$.v = $1.v as NullSpecification }

implicitly_typed_value_specification:
  null_specification { $$.v = $1.v as NullSpecification }

null_specification:
  NULL { $$.v = NullSpecification{} }

%%
