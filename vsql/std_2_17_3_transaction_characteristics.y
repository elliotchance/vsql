%%

transaction_characteristics:
  transaction_mode { $$.v = [$1.v as TransactionMode] }
| transaction_characteristics comma transaction_mode {
    $$.v = append_list($1.v as []TransactionMode, $3.v as TransactionMode)
  }

transaction_mode:
  isolation_level { $$.v = TransactionMode($1.v as IsolationLevel) }
| diagnostics_size { $$.v = TransactionMode($1.v as DiagnosticsSize) }
| transaction_access_mode {
    $$.v = TransactionMode($1.v as TransactionAccessMode)
  }

transaction_access_mode:
  READ ONLY { $$.v = TransactionAccessMode.read_only }
| READ WRITE { $$.v = TransactionAccessMode.read_write }

isolation_level:
  ISOLATION LEVEL level_of_isolation { $$.v = $3.v as IsolationLevel }

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Conformance Rules, 1

level_of_isolation:
  READ UNCOMMITTED {
    flag(mut yylex, 'F111')
    $$.v = IsolationLevel.read_uncommitted
  }
| READ COMMITTED {
    flag(mut yylex, 'F111')
    $$.v = IsolationLevel.read_committed
  }
| REPEATABLE READ {
    flag(mut yylex, 'F111')
    $$.v = IsolationLevel.repeatable_read
  }
| SERIALIZABLE { $$.v = IsolationLevel.serializable }

diagnostics_size:
  DIAGNOSTICS SIZE number_of_conditions {
    $$.v = DiagnosticsSize{$3.v as ValueSpecification}
  }

number_of_conditions:
  simple_value_specification { $$.v = $1.v as ValueSpecification }

%%
