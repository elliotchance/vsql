-- # A comment is a separator, so it can be before UESCAPE.
VALUES U&'a!0041' /* c */ UESCAPE '!';
-- COL1: aA

VALUES U&'a!0041'/* c */UESCAPE '!';
-- COL1: aA

VALUES U&'a!0041' /* c */ /* d */ UESCAPE '!';
-- COL1: aA

VALUES U&'a!0041' /* outer /* inner */ outer */ UESCAPE '!';
-- COL1: aA

VALUES U&'a!0041' /* a
  new line */ UESCAPE '!';
-- COL1: aA

VALUES U&'a!0041' -- c
  UESCAPE '!';
-- COL1: aA

VALUES U&'a!0041' -- c
  -- d
  UESCAPE '!';
-- COL1: aA

-- # And it can be between UESCAPE and the character.
VALUES U&'a!0041' UESCAPE /* c */ '!';
-- COL1: aA

VALUES U&'a!0041' UESCAPE/* c */'!';
-- COL1: aA

VALUES U&'a!0041' uescape /* c */ '!';
-- COL1: aA

VALUES U&'a!0041' UESCAPE -- c
  '!';
-- COL1: aA

VALUES U&'a!0041' /* c */ UESCAPE -- d
  /* e */ '!';
-- COL1: aA

-- # The specifier applies to all of the parts of a compound literal.
VALUES U&'!0041' -- c
  '!0042' /* d */ UESCAPE /* e */ '!';
-- COL1: AB

VALUES U&'!0041' /* a
  new line */ '!0042' -- c
  UESCAPE '!';
-- COL1: AB

-- # All of the white space that separates tokens is allowed, not only ASCII.
VALUES U&'a!0041'　UESCAPE '!';
-- COL1: aA

VALUES U&'a!0041' UESCAPE　'!';
-- COL1: aA

VALUES U&'!0041'
　'!0042' UESCAPE '!';
-- COL1: AB

VALUES 'a'
　'b';
-- COL1: ab

-- # White space isn't a valid escape character.
VALUES U&'x' UESCAPE '　';
-- error 42601: syntax error: invalid Unicode escape character: '　'

-- # A comment isn't a specifier.
VALUES U&'a!0041' /* UESCAPE '!' */;
-- COL1: a!0041

VALUES U&'a!0041' -- UESCAPE '!'
;
-- COL1: a!0041

VALUES U&'a!0041' /* c */;
-- COL1: a!0041

-- # A comment doesn't change what isn't a specifier.
VALUES U&'x' /* c */ UESCAPEX;
-- error 42601: syntax error: unexpected identifier at line 1, column 22 near "VALUES U&'x' /* c */ UESCAPEX"; hint: is a "," missing before UESCAPEX?

VALUES U&'x' /* c */ 'y';
-- error 42601: syntax error: unexpected string at line 1, column 22 near "VALUES U&'x' /* c */ 'y'"; hint: is a "," missing before 'y'?

VALUES 'x' /* c */ UESCAPE '!';
-- error 42601: syntax error: unexpected UESCAPE at line 1, column 20 near "VALUES 'x' /* c */ UESCAPE '!'"

-- # The character must still follow.
VALUES U&'x' /* c */ UESCAPE /* d */;
-- error 42601: syntax error: UESCAPE must be followed by a single character in quotes

VALUES U&'x' UESCAPE /* c */ 'ab';
-- error 42601: syntax error: UESCAPE must be followed by a single character in quotes

VALUES U&'x' UESCAPE '/* c */!';
-- error 42601: syntax error: UESCAPE must be followed by a single character in quotes

-- # A comment must still be closed.
VALUES U&'x' /* c UESCAPE '!';
-- error 42601: syntax error: unterminated comment: /* c UESCAPE '!'

VALUES U&'x' UESCAPE /* c '!';
-- error 42601: syntax error: unterminated comment: /* c '!'
