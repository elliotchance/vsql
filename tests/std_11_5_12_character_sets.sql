-- # UTF8 is the only character set. Its default collation is UCS_BASIC, and
-- # both are in the INFORMATION_SCHEMA (6.11, Description, 1-4).
SELECT * FROM information_schema.character_sets;
-- CHARACTER_SET_CATALOG: :memory: CHARACTER_SET_SCHEMA: INFORMATION_SCHEMA CHARACTER_SET_NAME: UTF8 CHARACTER_REPERTOIRE: UCS FORM_OF_USE: UTF8 DEFAULT_COLLATE_CATALOG: :memory: DEFAULT_COLLATE_SCHEMA: INFORMATION_SCHEMA DEFAULT_COLLATE_NAME: UCS_BASIC

-- # It's the character set of a character string column.
CREATE TABLE t (x VARCHAR(10));
SELECT COUNT(*) FROM information_schema.columns c JOIN information_schema.character_sets cs ON (c.character_set_catalog, c.character_set_schema, c.character_set_name) = (cs.character_set_catalog, cs.character_set_schema, cs.character_set_name) WHERE c.table_name = 'T';
-- msg: CREATE TABLE 1
-- COL1: 1

-- # UCS_BASIC has the PAD SPACE characteristic, so trailing spaces don't
-- # matter when comparing.
VALUES 'a' = CAST('a  ' AS VARCHAR(10));
-- COL1: TRUE

-- # The short name view (5.77).
SELECT * FROM information_schema.character_sets_s;
-- CHAR_SET_CATALOG: :memory: CHAR_SET_SCHEMA: INFORMATION_SCHEMA CHARACTER_SET_NAME: UTF8 CHAR_REPERTOIRE: UCS FORM_OF_USE: UTF8 DEF_COLLATE_CAT: :memory: DEF_COLLATE_SCHEMA: INFORMATION_SCHEMA DEF_COLLATE_NAME: UCS_BASIC
