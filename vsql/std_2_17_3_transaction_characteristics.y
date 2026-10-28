%%

transaction_characteristics:
  transaction_mode { $$.v = [$1.v as IsolationLevel] }
| transaction_characteristics comma transaction_mode {
    $$.v = append_list($1.v as []IsolationLevel, $3.v as IsolationLevel)
  }

transaction_mode:
  isolation_level { $$.v = $1.v as IsolationLevel }

isolation_level:
  ISOLATION LEVEL level_of_isolation { $$.v = $3.v as IsolationLevel }

level_of_isolation:
  READ UNCOMMITTED { $$.v = IsolationLevel.read_uncommitted }
| READ COMMITTED { $$.v = IsolationLevel.read_committed }
| REPEATABLE READ { $$.v = IsolationLevel.repeatable_read }
| SERIALIZABLE { $$.v = IsolationLevel.serializable }

%%
