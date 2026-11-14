%%

// ISO/IEC 9075-2:2023(E), 14.2, <cursor properties>
//
// Specify the declared properties of a cursor.

// Only the <cursor scrollability> and <cursor holdability> are supported.
cursor_properties:
  CURSOR { $$.v = yy_box(CursorProperties{}) }
| CURSOR cursor_holdability { $$.v = yy_box(CursorProperties{hold: $2.v as bool}) }
| cursor_scrollability CURSOR {
    $$.v = yy_box(CursorProperties{scroll: $1.v as bool, scrollability: true})
  }
| cursor_scrollability CURSOR cursor_holdability {
    $$.v = yy_box(CursorProperties{scroll: $1.v as bool, scrollability: true,
      hold: $3.v as bool})
  }

cursor_scrollability:
  SCROLL {
    flag(mut yylex, 'F431')
    $$.v = true
  }
| NO SCROLL {
    flag(mut yylex, 'F431')
    $$.v = false
  }

cursor_holdability:
  WITH HOLD { $$.v = true }
| WITHOUT HOLD {
    flag(mut yylex, 'T551')
    $$.v = false
  }

%%
