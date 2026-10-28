%%

transaction_characteristics:
  transaction_mode { $$.v = [$1.v as TransactionMode] }
| transaction_characteristics comma transaction_mode {
    $$.v = append_list($1.v as []TransactionMode, $3.v as TransactionMode)
  }

transaction_mode:
  diagnostics_size { $$.v = $1.v as TransactionMode }

diagnostics_size:
  DIAGNOSTICS SIZE number_of_conditions {
    $$.v = TransactionMode{$3.v as ValueSpecification}
  }

number_of_conditions:
  simple_value_specification { $$.v = $1.v as ValueSpecification }

%%
