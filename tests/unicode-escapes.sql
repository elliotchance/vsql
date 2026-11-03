-- # A Unicode string has escapes for any character (F393). The default escape
-- # character is a backslash.
VALUES ROW(U&'\0041bc', u&'d\0061t\+000061', U&'a\\b', U&'no escapes');
-- COL1: Abc COL2: data COL3: a\b COL4: no escapes

VALUES ROW(U&'caf\00e9', CHAR_LENGTH(U&'caf\00e9'), OCTET_LENGTH(U&'caf\00e9'));
-- COL1: café COL2: 4 COL3: 5

VALUES ROW(CHAR_LENGTH(U&'\+01F600'), OCTET_LENGTH(U&'\+01F600'));
-- COL1: 1 COL2: 4

VALUES ROW(CHAR_LENGTH(U&'a\0000b'), OCTET_LENGTH(U&'a\0000b'));
-- COL1: 3 COL2: 3

VALUES U&'it''s';
-- COL1: it's

-- # UESCAPE chooses another escape character.
VALUES ROW(U&'!0041 \0041' UESCAPE '!', U&'x!!y' uescape'!', U&'x\' UESCAPE '!');
-- COL1: A \0041 COL2: x!y COL3: x\

-- # Strings separated by a new line are one string.
VALUES 'a'
  'b';
-- COL1: ab

VALUES U&'\0041'
  '\0042!0043' UESCAPE '!';
-- COL1: \0041\0042C

VALUES 'a' 'b';
-- error 42601: syntax error: unexpected string

VALUES U & 'x';
-- error 42601: syntax error: invalid character: &

-- # Invalid escapes.
VALUES U&'\004';
-- error 42601: syntax error: invalid Unicode escape: \004

VALUES U&'\00G1';
-- error 42601: syntax error: invalid Unicode escape: \00G1

VALUES U&'\+00004';
-- error 42601: syntax error: invalid Unicode escape: \+00004

VALUES U&'\+110000';
-- error 42601: syntax error: invalid Unicode code point: \+110000

VALUES U&'\D800';
-- error 42601: syntax error: invalid Unicode code point: \D800

VALUES U&'x' UESCAPE '+';
-- error 42601: syntax error: invalid Unicode escape character: '+'

VALUES U&'x' UESCAPE 'a';
-- error 42601: syntax error: invalid Unicode escape character: 'a'

VALUES U&'x' UESCAPE ' ';
-- error 42601: syntax error: invalid Unicode escape character: ' '

VALUES U&'x' UESCAPE '"';
-- error 42601: syntax error: invalid Unicode escape character: '"'

VALUES U&'x' UESCAPE '';
-- error 42601: syntax error: UESCAPE must be followed by a single character in quotes

VALUES U&'x' UESCAPE 'ab';
-- error 42601: syntax error: UESCAPE must be followed by a single character in quotes

VALUES U&'x' UESCAPE;
-- error 42601: syntax error: UESCAPE must be followed by a single character in quotes

VALUES U&'x' UESCAPEX;
-- error 42601: syntax error: unexpected identifier

-- # A noncharacter can't be in a character string.
VALUES U&'\FFFF';
-- error 22029: noncharacter in UCS string

VALUES U&'\FFFE';
-- error 22029: noncharacter in UCS string

VALUES U&'\FDD0';
-- error 22029: noncharacter in UCS string

VALUES U&'\FDEF';
-- error 22029: noncharacter in UCS string

VALUES CHAR_LENGTH(U&'\+10FFFF');
-- error 22029: noncharacter in UCS string

VALUES CHAR_LENGTH(U&'\+01FFFE');
-- error 22029: noncharacter in UCS string

VALUES '<U+FFFF>';
-- error 22029: noncharacter in UCS string

/* params '￿' */
VALUES CAST(? AS VARCHAR(10));
-- sql: VALUES CAST('￿' AS VARCHAR(10))
-- error 22029: noncharacter in UCS string

-- # The characters around them are allowed.
VALUES CHAR_LENGTH(U&'\FDCF\FDF0\FFFD\+01FFFD');
-- COL1: 4

/* params 'ok' */
VALUES CAST(? AS VARCHAR(10));
-- sql: VALUES CAST('ok' AS VARCHAR(10))
-- COL1: ok
