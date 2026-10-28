%%

transaction_characteristics:
  transaction_mode { $$.v = [$1.v as TransactionMode] }
| transaction_characteristics comma transaction_mode {
    $$.v = append_list($1.v as []TransactionMode, $3.v as TransactionMode)
  }

transaction_mode:
  isolation_level { $$.v = TransactionMode($1.v as IsolationLevel) }
| transaction_access_mode {
    $$.v = TransactionMode($1.v as TransactionAccessMode)
  }

transaction_access_mode:
  READ ONLY { $$.v = TransactionAccessMode.read_only }
| READ WRITE { $$.v = TransactionAccessMode.read_write }

isolation_level:
  ISOLATION LEVEL level_of_isolation { $$.v = $3.v as IsolationLevel }

level_of_isolation:
  READ UNCOMMITTED { $$.v = IsolationLevel.read_uncommitted }
| READ COMMITTED { $$.v = IsolationLevel.read_committed }
| REPEATABLE READ { $$.v = IsolationLevel.repeatable_read }
| SERIALIZABLE { $$.v = IsolationLevel.serializable }

%%
