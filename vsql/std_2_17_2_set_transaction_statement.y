%%

set_transaction_statement:
  SET TRANSACTION { $$.v = Stmt(SetTransactionStatement{}) }
| SET TRANSACTION transaction_characteristics {
    $$.v = Stmt(SetTransactionStatement{modes: $3.v as []TransactionMode})
  }
// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, Conformance Rules, 1
| SET LOCAL TRANSACTION {
    flag(mut yylex, 'T251')
    $$.v = Stmt(SetTransactionStatement{local: true})
  }
| SET LOCAL TRANSACTION transaction_characteristics {
    flag(mut yylex, 'T251')
    $$.v = Stmt(SetTransactionStatement{
      modes: $4.v as []TransactionMode
      local: true
    })
  }

%%
