-- # The only character that is a member of the Unicode General Category class
-- # "Zl" is U+2028 (Line Separator)
VALUES<U+2028>123;
-- COL1: 123

-- # The only character that is a member of the Unicode General Category class
-- # "Zp" is U+2029 (Paragraph Separator).
VALUES<U+2029>123;
-- COL1: 123

-- # The characters that are members of the Unicode General Category class "Zs"
-- # are:

-- # U+0020 (Space)
VALUES<U+0020>123;
-- COL1: 123

-- # U+00A0 (No-Break Space)
VALUES<U+00A0>123;
-- COL1: 123

-- # U+1680 (Ogham Space Mark)
VALUES<U+1680>123;
-- COL1: 123

-- # U+180E (Mongolian Vowel Separator)
VALUES<U+180E>123;
-- COL1: 123

-- # U+2000 (En Quad)
VALUES<U+2000>123;
-- COL1: 123

-- # U+2001 (Em Quad)
VALUES<U+2001>123;
-- COL1: 123

-- # U+2002 (En Space)
VALUES<U+2002>123;
-- COL1: 123

-- # U+2003 (Em Space)
VALUES<U+2003>123;
-- COL1: 123

-- # U+2004 (Three-Per-Em Space)
VALUES<U+2004>123;
-- COL1: 123

-- # U+2005 (Four-Per-Em Space)
VALUES<U+2005>123;
-- COL1: 123

-- # U+2006 (Six-Per-Em Space)
VALUES<U+2006>123;
-- COL1: 123

-- # U+2007 (Figure Space)
VALUES<U+2007>123;
-- COL1: 123

-- # U+2008 (Punctuation Space)
VALUES<U+2008>123;
-- COL1: 123

-- # U+2009 (Thin Space)
VALUES<U+2009>123;
-- COL1: 123

-- # U+200A (Hair Space)
VALUES<U+200A>123;
-- COL1: 123

-- # U+202F (Narrow No-Break Space)
VALUES<U+202F>123;
-- COL1: 123

-- # U+205F (Space, Medium Mathematical)
VALUES<U+205F>123;
-- COL1: 123

-- # U+3000 (Ideographic Space)
VALUES<U+3000>123;
-- COL1: 123

-- # White space is any character in the Unicode General Category classes "Zs",
-- # "Zl", and "Zp", as well as any of the following characters:

-- # U+0009, Horizontal Tabulation
VALUES<U+0009>123;
-- COL1: 123

-- # U+000A, Line Feed
VALUES<U+000A>123;
-- COL1: 123

-- # U+000B, Vertical Tabulation
VALUES<U+000B>123;
-- COL1: 123

-- # U+000C, Form Feed
VALUES<U+000C>123;
-- COL1: 123

-- # U+000D, Carriage Return
VALUES<U+000D>123;
-- COL1: 123

-- # U+0085, Next Line
VALUES<U+0085>123;
-- COL1: 123

-- # Some other combinations and error conditions.

VALUES<U+0009><U+0009><U+0009>123;
-- COL1: 123

<U+0009>VALUES 123;
-- COL1: 123

VALUES<U+0061>123;
-- error 42601: syntax error: unexpected identifier
