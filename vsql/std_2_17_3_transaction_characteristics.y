%%

transaction_characteristics:
  transaction_mode { $$.v = [$1.v as TransactionMode] }
| transaction_characteristics comma transaction_mode {
    $$.v = append_list($1.v as []TransactionMode, $3.v as TransactionMode)
  }

transaction_mode:
  diagnostics_size { $$.v = $1.v as TransactionMode }

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Conformance Rules, 2
diagnostics_size:
  DIAGNOSTICS SIZE number_of_conditions {
    flag(mut yylex, 'F121')
    $$.v = TransactionMode{$3.v as ValueSpecification}
  }

number_of_conditions:
  simple_value_specification { $$.v = $1.v as ValueSpecification }

%%
