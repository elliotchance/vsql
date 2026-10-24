%%

// Only one <transaction mode> is supported, since <isolation level> and
// <diagnostics size> are not. Syntax Rule 1 means there can't be more than one
// <transaction access mode>.
transaction_characteristics:
  transaction_access_mode {
    $$.v = TransactionCharacteristics{read_only: $1.v as bool}
  }

transaction_access_mode:
  READ ONLY { $$.v = true }
| READ WRITE { $$.v = false }

%%
