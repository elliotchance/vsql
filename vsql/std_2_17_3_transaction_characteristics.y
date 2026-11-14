%%

transaction_characteristics:
  transaction_mode { $$.v = yy_box([$1.v as TransactionMode]) }
| transaction_characteristics comma transaction_mode {
    $$.v = yy_box(append_list($1.v as []TransactionMode, $3.v as TransactionMode))
  }

transaction_mode:
  isolation_level { $$.v = yy_box(TransactionMode($1.v as IsolationLevel)) }
| diagnostics_size { $$.v = yy_box(TransactionMode($1.v as DiagnosticsSize)) }
| transaction_access_mode {
    $$.v = yy_box(TransactionMode($1.v as TransactionAccessMode))
  }

transaction_access_mode:
  READ ONLY { $$.v = yy_box(TransactionAccessMode.read_only) }
| READ WRITE { $$.v = yy_box(TransactionAccessMode.read_write) }

isolation_level:
  ISOLATION LEVEL level_of_isolation { $$.v = $3.v }

// ISO/IEC 9075-2:2023, 17.3, <transaction characteristics>, Conformance Rules, 1

level_of_isolation:
  READ UNCOMMITTED {
    flag(mut yylex, 'F111')
    $$.v = yy_box(IsolationLevel.read_uncommitted)
  }
| READ COMMITTED {
    flag(mut yylex, 'F111')
    $$.v = yy_box(IsolationLevel.read_committed)
  }
| REPEATABLE READ {
    flag(mut yylex, 'F111')
    $$.v = yy_box(IsolationLevel.repeatable_read)
  }
| SERIALIZABLE { $$.v = yy_box(IsolationLevel.serializable) }

// ISO/IEC 9075-2:2023, 17.3, <transaction characteristics>, Conformance Rules, 5
diagnostics_size:
  DIAGNOSTICS SIZE number_of_conditions {
    flag(mut yylex, 'F121')
    $$.v = yy_box(DiagnosticsSize{$3.v as ValueSpecification})
  }

number_of_conditions:
  simple_value_specification { $$.v = $1.v }

%%
