%%

// ISO/IEC 9075-2:2016(E), 17.4, <set constraints mode statement>
//
// If an SQL-transaction is currently active, then set the constraint mode for
// that SQL-transaction in the current SQL-session. If no SQL-transaction is
// currently active, then set the constraint mode for the next SQL-transaction
// in the current SQL-session for the SQL-agent.

set_constraints_mode_statement:
  SET CONSTRAINTS constraint_name_list DEFERRED {
    $$.v = Stmt(SetConstraintsModeStatement{$3.v as []Identifier, true})
  }
| SET CONSTRAINTS constraint_name_list IMMEDIATE {
    $$.v = Stmt(SetConstraintsModeStatement{$3.v as []Identifier, false})
  }

// ALL is an empty list.
constraint_name_list:
  ALL { $$.v = []Identifier{} }
| constraint_names { $$.v = $1.v as []Identifier }

constraint_names:
  constraint_name { $$.v = [$1.v as Identifier] }
| constraint_names comma constraint_name {
    $$.v = append_list($1.v as []Identifier, $3.v as Identifier)
  }

%%
