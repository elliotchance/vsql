%%

// ISO/IEC 9075-2:2016(E), 14.2, <cursor properties>
//
// Specify the declared properties of a cursor.

// cursor_properties is true for a holdable cursor. Only the <cursor
// holdability> is supported.
cursor_properties:
  CURSOR { $$.v = false }
| CURSOR cursor_holdability { $$.v = $2.v as bool }

cursor_holdability:
  WITH HOLD { $$.v = true }
| WITHOUT HOLD {
    flag(mut yylex, 'T551')
    $$.v = false
  }

%%
