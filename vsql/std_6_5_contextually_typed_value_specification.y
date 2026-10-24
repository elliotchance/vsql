%%

contextually_typed_value_specification:
  implicitly_typed_value_specification {
    $$.v = ContextuallyTypedValueSpecification($1.v as NullSpecification)
  }
| default_specification {
    $$.v = ContextuallyTypedValueSpecification($1.v as DefaultSpecification)
  }

implicitly_typed_value_specification:
  null_specification { $$.v = $1.v as NullSpecification }

null_specification:
  NULL { $$.v = NullSpecification{} }

default_specification:
  DEFAULT { $$.v = DefaultSpecification{} }

%%
