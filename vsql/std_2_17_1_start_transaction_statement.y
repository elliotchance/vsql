%%

// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>, Conformance Rules, 1

start_transaction_statement:
  START TRANSACTION {
    flag(mut yylex, 'T241')
    $$.v = Stmt(StartTransactionStatement{})
  }
| START TRANSACTION transaction_characteristics {
    flag(mut yylex, 'T241')
    $$.v = Stmt(StartTransactionStatement{$3.v as []TransactionMode})
  }
| begin_transaction {
    flag(mut yylex, vsql_begin)
    flag(mut yylex, 'T241')
    $$.v = Stmt(StartTransactionStatement{})
  }
| begin_transaction transaction_characteristics {
    flag(mut yylex, vsql_begin)
    flag(mut yylex, 'T241')
    $$.v = Stmt(StartTransactionStatement{$2.v as []TransactionMode})
  }

// BEGIN isn't part of the standard (see the V013 feature in the SQL Flagger).
begin_transaction:
  BEGIN
| BEGIN TRANSACTION
| BEGIN WORK

%%
