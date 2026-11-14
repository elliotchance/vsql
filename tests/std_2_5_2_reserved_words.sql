-- # No reserved word can be a regular identifier (Syntax Rules, 26), so each
-- # one is a syntax error as a table name. A reserved word can still be a name
-- # when it's quoted.
CREATE TABLE ABS (x INT);
-- error 42601: syntax error: unexpected ABS at line 1, column 14 near "CREATE TABLE ABS ("; hint: ABS is a reserved word, so it must be quoted to be used as a name, such as "ABS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ABSENT (x INT);
-- error 42601: syntax error: unexpected ABSENT at line 1, column 14 near "CREATE TABLE ABSENT ("; hint: ABSENT is a reserved word, so it must be quoted to be used as a name, such as "ABSENT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ACOS (x INT);
-- error 42601: syntax error: unexpected ACOS at line 1, column 14 near "CREATE TABLE ACOS ("; hint: ACOS is a reserved word, so it must be quoted to be used as a name, such as "ACOS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ALL (x INT);
-- error 42601: syntax error: unexpected ALL at line 1, column 14 near "CREATE TABLE ALL ("

CREATE TABLE ALLOCATE (x INT);
-- error 42601: syntax error: unexpected ALLOCATE at line 1, column 14 near "CREATE TABLE ALLOCATE ("; hint: ALLOCATE is a reserved word, so it must be quoted to be used as a name, such as "ALLOCATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ALTER (x INT);
-- error 42601: syntax error: unexpected ALTER at line 1, column 14 near "CREATE TABLE ALTER ("; hint: ALTER is a reserved word, so it must be quoted to be used as a name, such as "ALTER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE AND (x INT);
-- error 42601: syntax error: unexpected AND at line 1, column 14 near "CREATE TABLE AND ("; hint: AND is a reserved word, so it must be quoted to be used as a name, such as "AND" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ANY (x INT);
-- error 42601: syntax error: unexpected ANY at line 1, column 14 near "CREATE TABLE ANY ("; hint: ANY is a reserved word, so it must be quoted to be used as a name, such as "ANY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ANY_VALUE (x INT);
-- error 42601: syntax error: unexpected ANY_VALUE at line 1, column 14 near "CREATE TABLE ANY_VALUE ("; hint: ANY_VALUE is a reserved word, so it must be quoted to be used as a name, such as "ANY_VALUE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ARE (x INT);
-- error 42601: syntax error: unexpected ARE at line 1, column 14 near "CREATE TABLE ARE ("; hint: ARE is a reserved word, so it must be quoted to be used as a name, such as "ARE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ARRAY (x INT);
-- error 42601: syntax error: unexpected ARRAY at line 1, column 14 near "CREATE TABLE ARRAY ("; hint: ARRAY is a reserved word, so it must be quoted to be used as a name, such as "ARRAY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ARRAY_AGG (x INT);
-- error 42601: syntax error: unexpected ARRAY_AGG at line 1, column 14 near "CREATE TABLE ARRAY_AGG ("; hint: ARRAY_AGG is a reserved word, so it must be quoted to be used as a name, such as "ARRAY_AGG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ARRAY_MAX_CARDINALITY (x INT);
-- error 42601: syntax error: unexpected ARRAY_MAX_CARDINALITY at line 1, column 14 near "CREATE TABLE ARRAY_MAX_CARDINALITY ("; hint: ARRAY_MAX_CARDINALITY is a reserved word, so it must be quoted to be used as a name, such as "ARRAY_MAX_CARDINALITY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE AS (x INT);
-- error 42601: syntax error: unexpected AS at line 1, column 14 near "CREATE TABLE AS ("; hint: AS is a reserved word, so it must be quoted to be used as a name, such as "AS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ASENSITIVE (x INT);
-- error 42601: syntax error: unexpected ASENSITIVE at line 1, column 14 near "CREATE TABLE ASENSITIVE ("; hint: ASENSITIVE is a reserved word, so it must be quoted to be used as a name, such as "ASENSITIVE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ASIN (x INT);
-- error 42601: syntax error: unexpected ASIN at line 1, column 14 near "CREATE TABLE ASIN ("; hint: ASIN is a reserved word, so it must be quoted to be used as a name, such as "ASIN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ASYMMETRIC (x INT);
-- error 42601: syntax error: unexpected ASYMMETRIC at line 1, column 14 near "CREATE TABLE ASYMMETRIC ("; hint: ASYMMETRIC is a reserved word, so it must be quoted to be used as a name, such as "ASYMMETRIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE AT (x INT);
-- error 42601: syntax error: unexpected AT at line 1, column 14 near "CREATE TABLE AT ("; hint: AT is a reserved word, so it must be quoted to be used as a name, such as "AT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ATAN (x INT);
-- error 42601: syntax error: unexpected ATAN at line 1, column 14 near "CREATE TABLE ATAN ("; hint: ATAN is a reserved word, so it must be quoted to be used as a name, such as "ATAN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ATOMIC (x INT);
-- error 42601: syntax error: unexpected ATOMIC at line 1, column 14 near "CREATE TABLE ATOMIC ("; hint: ATOMIC is a reserved word, so it must be quoted to be used as a name, such as "ATOMIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE AUTHORIZATION (x INT);
-- error 42601: syntax error: unexpected AUTHORIZATION at line 1, column 14 near "CREATE TABLE AUTHORIZATION ("; hint: AUTHORIZATION is a reserved word, so it must be quoted to be used as a name, such as "AUTHORIZATION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE AVG (x INT);
-- error 42601: syntax error: unexpected AVG at line 1, column 14 near "CREATE TABLE AVG ("; hint: AVG is a reserved word, so it must be quoted to be used as a name, such as "AVG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BEGIN (x INT);
-- error 42601: syntax error: unexpected BEGIN at line 1, column 14 near "CREATE TABLE BEGIN ("; hint: BEGIN is a reserved word, so it must be quoted to be used as a name, such as "BEGIN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BEGIN_FRAME (x INT);
-- error 42601: syntax error: unexpected BEGIN_FRAME at line 1, column 14 near "CREATE TABLE BEGIN_FRAME ("; hint: BEGIN_FRAME is a reserved word, so it must be quoted to be used as a name, such as "BEGIN_FRAME" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BEGIN_PARTITION (x INT);
-- error 42601: syntax error: unexpected BEGIN_PARTITION at line 1, column 14 near "CREATE TABLE BEGIN_PARTITION ("; hint: BEGIN_PARTITION is a reserved word, so it must be quoted to be used as a name, such as "BEGIN_PARTITION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BETWEEN (x INT);
-- error 42601: syntax error: unexpected BETWEEN at line 1, column 14 near "CREATE TABLE BETWEEN ("; hint: BETWEEN is a reserved word, so it must be quoted to be used as a name, such as "BETWEEN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BIGINT (x INT);
-- error 42601: syntax error: unexpected BIGINT at line 1, column 14 near "CREATE TABLE BIGINT ("; hint: BIGINT is a reserved word, so it must be quoted to be used as a name, such as "BIGINT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BINARY (x INT);
-- error 42601: syntax error: unexpected BINARY at line 1, column 14 near "CREATE TABLE BINARY ("; hint: BINARY is a reserved word, so it must be quoted to be used as a name, such as "BINARY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BLOB (x INT);
-- error 42601: syntax error: unexpected BLOB at line 1, column 14 near "CREATE TABLE BLOB ("; hint: BLOB is a reserved word, so it must be quoted to be used as a name, such as "BLOB" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BOOLEAN (x INT);
-- error 42601: syntax error: unexpected BOOLEAN at line 1, column 14 near "CREATE TABLE BOOLEAN ("; hint: BOOLEAN is a reserved word, so it must be quoted to be used as a name, such as "BOOLEAN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BOTH (x INT);
-- error 42601: syntax error: unexpected BOTH at line 1, column 14 near "CREATE TABLE BOTH ("; hint: BOTH is a reserved word, so it must be quoted to be used as a name, such as "BOTH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BTRIM (x INT);
-- error 42601: syntax error: unexpected BTRIM at line 1, column 14 near "CREATE TABLE BTRIM ("; hint: BTRIM is a reserved word, so it must be quoted to be used as a name, such as "BTRIM" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE BY (x INT);
-- error 42601: syntax error: unexpected BY at line 1, column 14 near "CREATE TABLE BY ("; hint: BY is a reserved word, so it must be quoted to be used as a name, such as "BY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CALL (x INT);
-- error 42601: syntax error: unexpected CALL at line 1, column 14 near "CREATE TABLE CALL ("; hint: CALL is a reserved word, so it must be quoted to be used as a name, such as "CALL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CALLED (x INT);
-- error 42601: syntax error: unexpected CALLED at line 1, column 14 near "CREATE TABLE CALLED ("; hint: CALLED is a reserved word, so it must be quoted to be used as a name, such as "CALLED" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CARDINALITY (x INT);
-- error 42601: syntax error: unexpected CARDINALITY at line 1, column 14 near "CREATE TABLE CARDINALITY ("; hint: CARDINALITY is a reserved word, so it must be quoted to be used as a name, such as "CARDINALITY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CASCADED (x INT);
-- error 42601: syntax error: unexpected CASCADED at line 1, column 14 near "CREATE TABLE CASCADED ("; hint: CASCADED is a reserved word, so it must be quoted to be used as a name, such as "CASCADED" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CASE (x INT);
-- error 42601: syntax error: unexpected CASE at line 1, column 14 near "CREATE TABLE CASE ("; hint: CASE is a reserved word, so it must be quoted to be used as a name, such as "CASE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CAST (x INT);
-- error 42601: syntax error: unexpected CAST at line 1, column 14 near "CREATE TABLE CAST ("; hint: CAST is a reserved word, so it must be quoted to be used as a name, such as "CAST" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CEIL (x INT);
-- error 42601: syntax error: unexpected CEIL at line 1, column 14 near "CREATE TABLE CEIL ("; hint: CEIL is a reserved word, so it must be quoted to be used as a name, such as "CEIL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CEILING (x INT);
-- error 42601: syntax error: unexpected CEILING at line 1, column 14 near "CREATE TABLE CEILING ("; hint: CEILING is a reserved word, so it must be quoted to be used as a name, such as "CEILING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CHAR (x INT);
-- error 42601: syntax error: unexpected CHAR at line 1, column 14 near "CREATE TABLE CHAR ("; hint: CHAR is a reserved word, so it must be quoted to be used as a name, such as "CHAR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CHAR_LENGTH (x INT);
-- error 42601: syntax error: unexpected CHAR_LENGTH at line 1, column 14 near "CREATE TABLE CHAR_LENGTH ("; hint: CHAR_LENGTH is a reserved word, so it must be quoted to be used as a name, such as "CHAR_LENGTH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CHARACTER (x INT);
-- error 42601: syntax error: unexpected CHARACTER at line 1, column 14 near "CREATE TABLE CHARACTER ("; hint: CHARACTER is a reserved word, so it must be quoted to be used as a name, such as "CHARACTER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CHARACTER_LENGTH (x INT);
-- error 42601: syntax error: unexpected CHARACTER_LENGTH at line 1, column 14 near "CREATE TABLE CHARACTER_LENGTH ("; hint: CHARACTER_LENGTH is a reserved word, so it must be quoted to be used as a name, such as "CHARACTER_LENGTH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CHECK (x INT);
-- error 42601: syntax error: unexpected CHECK at line 1, column 14 near "CREATE TABLE CHECK ("; hint: CHECK is a reserved word, so it must be quoted to be used as a name, such as "CHECK" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CLASSIFIER (x INT);
-- error 42601: syntax error: unexpected CLASSIFIER at line 1, column 14 near "CREATE TABLE CLASSIFIER ("; hint: CLASSIFIER is a reserved word, so it must be quoted to be used as a name, such as "CLASSIFIER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CLOB (x INT);
-- error 42601: syntax error: unexpected CLOB at line 1, column 14 near "CREATE TABLE CLOB ("; hint: CLOB is a reserved word, so it must be quoted to be used as a name, such as "CLOB" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CLOSE (x INT);
-- error 42601: syntax error: unexpected CLOSE at line 1, column 14 near "CREATE TABLE CLOSE ("; hint: CLOSE is a reserved word, so it must be quoted to be used as a name, such as "CLOSE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COALESCE (x INT);
-- error 42601: syntax error: unexpected COALESCE at line 1, column 14 near "CREATE TABLE COALESCE ("; hint: COALESCE is a reserved word, so it must be quoted to be used as a name, such as "COALESCE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COLLATE (x INT);
-- error 42601: syntax error: unexpected COLLATE at line 1, column 14 near "CREATE TABLE COLLATE ("; hint: COLLATE is a reserved word, so it must be quoted to be used as a name, such as "COLLATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COLLECT (x INT);
-- error 42601: syntax error: unexpected COLLECT at line 1, column 14 near "CREATE TABLE COLLECT ("; hint: COLLECT is a reserved word, so it must be quoted to be used as a name, such as "COLLECT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COLUMN (x INT);
-- error 42601: syntax error: unexpected COLUMN at line 1, column 14 near "CREATE TABLE COLUMN ("; hint: COLUMN is a reserved word, so it must be quoted to be used as a name, such as "COLUMN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COMMIT (x INT);
-- error 42601: syntax error: unexpected COMMIT at line 1, column 14 near "CREATE TABLE COMMIT ("; hint: COMMIT is a reserved word, so it must be quoted to be used as a name, such as "COMMIT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CONDITION (x INT);
-- error 42601: syntax error: unexpected CONDITION at line 1, column 14 near "CREATE TABLE CONDITION ("; hint: CONDITION is a reserved word, so it must be quoted to be used as a name, such as "CONDITION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CONNECT (x INT);
-- error 42601: syntax error: unexpected CONNECT at line 1, column 14 near "CREATE TABLE CONNECT ("; hint: CONNECT is a reserved word, so it must be quoted to be used as a name, such as "CONNECT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CONSTRAINT (x INT);
-- error 42601: syntax error: unexpected CONSTRAINT at line 1, column 14 near "CREATE TABLE CONSTRAINT ("; hint: CONSTRAINT is a reserved word, so it must be quoted to be used as a name, such as "CONSTRAINT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CONTAINS (x INT);
-- error 42601: syntax error: unexpected CONTAINS at line 1, column 14 near "CREATE TABLE CONTAINS ("; hint: CONTAINS is a reserved word, so it must be quoted to be used as a name, such as "CONTAINS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CONVERT (x INT);
-- error 42601: syntax error: unexpected CONVERT at line 1, column 14 near "CREATE TABLE CONVERT ("; hint: CONVERT is a reserved word, so it must be quoted to be used as a name, such as "CONVERT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COPY (x INT);
-- error 42601: syntax error: unexpected COPY at line 1, column 14 near "CREATE TABLE COPY ("; hint: COPY is a reserved word, so it must be quoted to be used as a name, such as "COPY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CORR (x INT);
-- error 42601: syntax error: unexpected CORR at line 1, column 14 near "CREATE TABLE CORR ("; hint: CORR is a reserved word, so it must be quoted to be used as a name, such as "CORR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CORRESPONDING (x INT);
-- error 42601: syntax error: unexpected CORRESPONDING at line 1, column 14 near "CREATE TABLE CORRESPONDING ("; hint: CORRESPONDING is a reserved word, so it must be quoted to be used as a name, such as "CORRESPONDING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COS (x INT);
-- error 42601: syntax error: unexpected COS at line 1, column 14 near "CREATE TABLE COS ("; hint: COS is a reserved word, so it must be quoted to be used as a name, such as "COS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COSH (x INT);
-- error 42601: syntax error: unexpected COSH at line 1, column 14 near "CREATE TABLE COSH ("; hint: COSH is a reserved word, so it must be quoted to be used as a name, such as "COSH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COUNT (x INT);
-- error 42601: syntax error: unexpected COUNT at line 1, column 14 near "CREATE TABLE COUNT ("; hint: COUNT is a reserved word, so it must be quoted to be used as a name, such as "COUNT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COVAR_POP (x INT);
-- error 42601: syntax error: unexpected COVAR_POP at line 1, column 14 near "CREATE TABLE COVAR_POP ("; hint: COVAR_POP is a reserved word, so it must be quoted to be used as a name, such as "COVAR_POP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE COVAR_SAMP (x INT);
-- error 42601: syntax error: unexpected COVAR_SAMP at line 1, column 14 near "CREATE TABLE COVAR_SAMP ("; hint: COVAR_SAMP is a reserved word, so it must be quoted to be used as a name, such as "COVAR_SAMP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CREATE (x INT);
-- error 42601: syntax error: unexpected CREATE at line 1, column 14 near "CREATE TABLE CREATE ("; hint: CREATE is a reserved word, so it must be quoted to be used as a name, such as "CREATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CROSS (x INT);
-- error 42601: syntax error: unexpected CROSS at line 1, column 14 near "CREATE TABLE CROSS ("; hint: CROSS is a reserved word, so it must be quoted to be used as a name, such as "CROSS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CUBE (x INT);
-- error 42601: syntax error: unexpected CUBE at line 1, column 14 near "CREATE TABLE CUBE ("; hint: CUBE is a reserved word, so it must be quoted to be used as a name, such as "CUBE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CUME_DIST (x INT);
-- error 42601: syntax error: unexpected CUME_DIST at line 1, column 14 near "CREATE TABLE CUME_DIST ("; hint: CUME_DIST is a reserved word, so it must be quoted to be used as a name, such as "CUME_DIST" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT (x INT);
-- error 42601: syntax error: unexpected CURRENT at line 1, column 14 near "CREATE TABLE CURRENT ("; hint: CURRENT is a reserved word, so it must be quoted to be used as a name, such as "CURRENT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_CATALOG (x INT);
-- error 42601: syntax error: unexpected CURRENT_CATALOG at line 1, column 14 near "CREATE TABLE CURRENT_CATALOG ("; hint: CURRENT_CATALOG is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_CATALOG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_DATE (x INT);
-- error 42601: syntax error: unexpected CURRENT_DATE at line 1, column 14 near "CREATE TABLE CURRENT_DATE ("; hint: CURRENT_DATE is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_DATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_DEFAULT_TRANSFORM_GROUP (x INT);
-- error 42601: syntax error: unexpected CURRENT_DEFAULT_TRANSFORM_GROUP at line 1, column 14 near "TABLE CURRENT_DEFAULT_TRANSFORM_GROUP ("; hint: CURRENT_DEFAULT_TRANSFORM_GROUP is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_DEFAULT_TRANSFORM_GROUP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_PATH (x INT);
-- error 42601: syntax error: unexpected CURRENT_PATH at line 1, column 14 near "CREATE TABLE CURRENT_PATH ("; hint: CURRENT_PATH is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_PATH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_ROLE (x INT);
-- error 42601: syntax error: unexpected CURRENT_ROLE at line 1, column 14 near "CREATE TABLE CURRENT_ROLE ("; hint: CURRENT_ROLE is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_ROLE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_ROW (x INT);
-- error 42601: syntax error: unexpected CURRENT_ROW at line 1, column 14 near "CREATE TABLE CURRENT_ROW ("; hint: CURRENT_ROW is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_ROW" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_SCHEMA (x INT);
-- error 42601: syntax error: unexpected CURRENT_SCHEMA at line 1, column 14 near "CREATE TABLE CURRENT_SCHEMA ("; hint: CURRENT_SCHEMA is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_SCHEMA" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_TIME (x INT);
-- error 42601: syntax error: unexpected CURRENT_TIME at line 1, column 14 near "CREATE TABLE CURRENT_TIME ("; hint: CURRENT_TIME is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_TIME" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_TIMESTAMP (x INT);
-- error 42601: syntax error: unexpected CURRENT_TIMESTAMP at line 1, column 14 near "CREATE TABLE CURRENT_TIMESTAMP ("; hint: CURRENT_TIMESTAMP is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_TIMESTAMP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_PATH (x INT);
-- error 42601: syntax error: unexpected CURRENT_PATH at line 1, column 14 near "CREATE TABLE CURRENT_PATH ("; hint: CURRENT_PATH is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_PATH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_ROLE (x INT);
-- error 42601: syntax error: unexpected CURRENT_ROLE at line 1, column 14 near "CREATE TABLE CURRENT_ROLE ("; hint: CURRENT_ROLE is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_ROLE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_TRANSFORM_GROUP_FOR_TYPE (x INT);
-- error 42601: syntax error: unexpected CURRENT_TRANSFORM_GROUP_FOR_TYPE at line 1, column 14 near "TABLE CURRENT_TRANSFORM_GROUP_FOR_TYPE ("; hint: CURRENT_TRANSFORM_GROUP_FOR_TYPE is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_TRANSFORM_GROUP_FOR_TYPE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURRENT_USER (x INT);
-- error 42601: syntax error: unexpected CURRENT_USER at line 1, column 14 near "CREATE TABLE CURRENT_USER ("; hint: CURRENT_USER is a reserved word, so it must be quoted to be used as a name, such as "CURRENT_USER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CURSOR (x INT);
-- error 42601: syntax error: unexpected CURSOR at line 1, column 14 near "CREATE TABLE CURSOR ("; hint: CURSOR is a reserved word, so it must be quoted to be used as a name, such as "CURSOR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE CYCLE (x INT);
-- error 42601: syntax error: unexpected CYCLE at line 1, column 14 near "CREATE TABLE CYCLE ("; hint: CYCLE is a reserved word, so it must be quoted to be used as a name, such as "CYCLE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DATE (x INT);
-- error 42601: syntax error: unexpected DATE at line 1, column 14 near "CREATE TABLE DATE ("; hint: DATE is a reserved word, so it must be quoted to be used as a name, such as "DATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DAY (x INT);
-- error 42601: syntax error: unexpected DAY at line 1, column 14 near "CREATE TABLE DAY ("; hint: DAY is a reserved word, so it must be quoted to be used as a name, such as "DAY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DEALLOCATE (x INT);
-- error 42601: syntax error: unexpected DEALLOCATE at line 1, column 14 near "CREATE TABLE DEALLOCATE ("; hint: DEALLOCATE is a reserved word, so it must be quoted to be used as a name, such as "DEALLOCATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DEC (x INT);
-- error 42601: syntax error: unexpected DEC at line 1, column 14 near "CREATE TABLE DEC ("; hint: DEC is a reserved word, so it must be quoted to be used as a name, such as "DEC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DECIMAL (x INT);
-- error 42601: syntax error: unexpected DECIMAL at line 1, column 14 near "CREATE TABLE DECIMAL ("; hint: DECIMAL is a reserved word, so it must be quoted to be used as a name, such as "DECIMAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DECFLOAT (x INT);
-- error 42601: syntax error: unexpected DECFLOAT at line 1, column 14 near "CREATE TABLE DECFLOAT ("; hint: DECFLOAT is a reserved word, so it must be quoted to be used as a name, such as "DECFLOAT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DECLARE (x INT);
-- error 42601: syntax error: unexpected DECLARE at line 1, column 14 near "CREATE TABLE DECLARE ("; hint: DECLARE is a reserved word, so it must be quoted to be used as a name, such as "DECLARE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DEFAULT (x INT);
-- error 42601: syntax error: unexpected DEFAULT at line 1, column 14 near "CREATE TABLE DEFAULT ("

CREATE TABLE DEFINE (x INT);
-- error 42601: syntax error: unexpected DEFINE at line 1, column 14 near "CREATE TABLE DEFINE ("; hint: DEFINE is a reserved word, so it must be quoted to be used as a name, such as "DEFINE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DELETE (x INT);
-- error 42601: syntax error: unexpected DELETE at line 1, column 14 near "CREATE TABLE DELETE ("; hint: DELETE is a reserved word, so it must be quoted to be used as a name, such as "DELETE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DENSE_RANK (x INT);
-- error 42601: syntax error: unexpected DENSE_RANK at line 1, column 14 near "CREATE TABLE DENSE_RANK ("; hint: DENSE_RANK is a reserved word, so it must be quoted to be used as a name, such as "DENSE_RANK" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DEREF (x INT);
-- error 42601: syntax error: unexpected DEREF at line 1, column 14 near "CREATE TABLE DEREF ("; hint: DEREF is a reserved word, so it must be quoted to be used as a name, such as "DEREF" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DESCRIBE (x INT);
-- error 42601: syntax error: unexpected DESCRIBE at line 1, column 14 near "CREATE TABLE DESCRIBE ("; hint: DESCRIBE is a reserved word, so it must be quoted to be used as a name, such as "DESCRIBE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DETERMINISTIC (x INT);
-- error 42601: syntax error: unexpected DETERMINISTIC at line 1, column 14 near "CREATE TABLE DETERMINISTIC ("; hint: DETERMINISTIC is a reserved word, so it must be quoted to be used as a name, such as "DETERMINISTIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DISCONNECT (x INT);
-- error 42601: syntax error: unexpected DISCONNECT at line 1, column 14 near "CREATE TABLE DISCONNECT ("; hint: DISCONNECT is a reserved word, so it must be quoted to be used as a name, such as "DISCONNECT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DISTINCT (x INT);
-- error 42601: syntax error: unexpected DISTINCT at line 1, column 14 near "CREATE TABLE DISTINCT ("

CREATE TABLE DOUBLE (x INT);
-- error 42601: syntax error: unexpected DOUBLE at line 1, column 14 near "CREATE TABLE DOUBLE ("; hint: DOUBLE is a reserved word, so it must be quoted to be used as a name, such as "DOUBLE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DROP (x INT);
-- error 42601: syntax error: unexpected DROP at line 1, column 14 near "CREATE TABLE DROP ("; hint: DROP is a reserved word, so it must be quoted to be used as a name, such as "DROP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE DYNAMIC (x INT);
-- error 42601: syntax error: unexpected DYNAMIC at line 1, column 14 near "CREATE TABLE DYNAMIC ("; hint: DYNAMIC is a reserved word, so it must be quoted to be used as a name, such as "DYNAMIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EACH (x INT);
-- error 42601: syntax error: unexpected EACH at line 1, column 14 near "CREATE TABLE EACH ("; hint: EACH is a reserved word, so it must be quoted to be used as a name, such as "EACH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ELEMENT (x INT);
-- error 42601: syntax error: unexpected ELEMENT at line 1, column 14 near "CREATE TABLE ELEMENT ("; hint: ELEMENT is a reserved word, so it must be quoted to be used as a name, such as "ELEMENT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ELSE (x INT);
-- error 42601: syntax error: unexpected ELSE at line 1, column 14 near "CREATE TABLE ELSE ("; hint: ELSE is a reserved word, so it must be quoted to be used as a name, such as "ELSE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EMPTY (x INT);
-- error 42601: syntax error: unexpected EMPTY at line 1, column 14 near "CREATE TABLE EMPTY ("; hint: EMPTY is a reserved word, so it must be quoted to be used as a name, such as "EMPTY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE END (x INT);
-- error 42601: syntax error: unexpected END at line 1, column 14 near "CREATE TABLE END ("; hint: END is a reserved word, so it must be quoted to be used as a name, such as "END" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE END_FRAME (x INT);
-- error 42601: syntax error: unexpected END_FRAME at line 1, column 14 near "CREATE TABLE END_FRAME ("; hint: END_FRAME is a reserved word, so it must be quoted to be used as a name, such as "END_FRAME" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE END_PARTITION (x INT);
-- error 42601: syntax error: unexpected END_PARTITION at line 1, column 14 near "CREATE TABLE END_PARTITION ("; hint: END_PARTITION is a reserved word, so it must be quoted to be used as a name, such as "END_PARTITION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

-- # END-EXEC isn't one token. The error is at END, which is reserved on its
-- # own.
CREATE TABLE END-EXEC (x INT);
-- error 42601: syntax error: unexpected END at line 1, column 14 near "CREATE TABLE END-"

CREATE TABLE EQUALS (x INT);
-- error 42601: syntax error: unexpected EQUALS at line 1, column 14 near "CREATE TABLE EQUALS ("; hint: EQUALS is a reserved word, so it must be quoted to be used as a name, such as "EQUALS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ESCAPE (x INT);
-- error 42601: syntax error: unexpected ESCAPE at line 1, column 14 near "CREATE TABLE ESCAPE ("; hint: ESCAPE is a reserved word, so it must be quoted to be used as a name, such as "ESCAPE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EVERY (x INT);
-- error 42601: syntax error: unexpected EVERY at line 1, column 14 near "CREATE TABLE EVERY ("; hint: EVERY is a reserved word, so it must be quoted to be used as a name, such as "EVERY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EXCEPT (x INT);
-- error 42601: syntax error: unexpected EXCEPT at line 1, column 14 near "CREATE TABLE EXCEPT ("; hint: EXCEPT is a reserved word, so it must be quoted to be used as a name, such as "EXCEPT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EXEC (x INT);
-- error 42601: syntax error: unexpected EXEC at line 1, column 14 near "CREATE TABLE EXEC ("; hint: EXEC is a reserved word, so it must be quoted to be used as a name, such as "EXEC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EXECUTE (x INT);
-- error 42601: syntax error: unexpected EXECUTE at line 1, column 14 near "CREATE TABLE EXECUTE ("; hint: EXECUTE is a reserved word, so it must be quoted to be used as a name, such as "EXECUTE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EXISTS (x INT);
-- error 42601: syntax error: unexpected EXISTS at line 1, column 14 near "CREATE TABLE EXISTS ("; hint: EXISTS is a reserved word, so it must be quoted to be used as a name, such as "EXISTS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EXP (x INT);
-- error 42601: syntax error: unexpected EXP at line 1, column 14 near "CREATE TABLE EXP ("; hint: EXP is a reserved word, so it must be quoted to be used as a name, such as "EXP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EXTERNAL (x INT);
-- error 42601: syntax error: unexpected EXTERNAL at line 1, column 14 near "CREATE TABLE EXTERNAL ("; hint: EXTERNAL is a reserved word, so it must be quoted to be used as a name, such as "EXTERNAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE EXTRACT (x INT);
-- error 42601: syntax error: unexpected EXTRACT at line 1, column 14 near "CREATE TABLE EXTRACT ("; hint: EXTRACT is a reserved word, so it must be quoted to be used as a name, such as "EXTRACT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FALSE (x INT);
-- error 42601: syntax error: unexpected FALSE at line 1, column 14 near "CREATE TABLE FALSE ("

CREATE TABLE FETCH (x INT);
-- error 42601: syntax error: unexpected FETCH at line 1, column 14 near "CREATE TABLE FETCH ("; hint: FETCH is a reserved word, so it must be quoted to be used as a name, such as "FETCH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FILTER (x INT);
-- error 42601: syntax error: unexpected FILTER at line 1, column 14 near "CREATE TABLE FILTER ("; hint: FILTER is a reserved word, so it must be quoted to be used as a name, such as "FILTER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FIRST_VALUE (x INT);
-- error 42601: syntax error: unexpected FIRST_VALUE at line 1, column 14 near "CREATE TABLE FIRST_VALUE ("; hint: FIRST_VALUE is a reserved word, so it must be quoted to be used as a name, such as "FIRST_VALUE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FLOAT (x INT);
-- error 42601: syntax error: unexpected FLOAT at line 1, column 14 near "CREATE TABLE FLOAT ("; hint: FLOAT is a reserved word, so it must be quoted to be used as a name, such as "FLOAT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FLOOR (x INT);
-- error 42601: syntax error: unexpected FLOOR at line 1, column 14 near "CREATE TABLE FLOOR ("; hint: FLOOR is a reserved word, so it must be quoted to be used as a name, such as "FLOOR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FOR (x INT);
-- error 42601: syntax error: unexpected FOR at line 1, column 14 near "CREATE TABLE FOR ("; hint: FOR is a reserved word, so it must be quoted to be used as a name, such as "FOR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FOREIGN (x INT);
-- error 42601: syntax error: unexpected FOREIGN at line 1, column 14 near "CREATE TABLE FOREIGN ("; hint: FOREIGN is a reserved word, so it must be quoted to be used as a name, such as "FOREIGN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FRAME_ROW (x INT);
-- error 42601: syntax error: unexpected FRAME_ROW at line 1, column 14 near "CREATE TABLE FRAME_ROW ("; hint: FRAME_ROW is a reserved word, so it must be quoted to be used as a name, such as "FRAME_ROW" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FREE (x INT);
-- error 42601: syntax error: unexpected FREE at line 1, column 14 near "CREATE TABLE FREE ("; hint: FREE is a reserved word, so it must be quoted to be used as a name, such as "FREE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FROM (x INT);
-- error 42601: syntax error: unexpected FROM at line 1, column 14 near "CREATE TABLE FROM ("; hint: FROM is a reserved word, so it must be quoted to be used as a name, such as "FROM" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FULL (x INT);
-- error 42601: syntax error: unexpected FULL at line 1, column 14 near "CREATE TABLE FULL ("; hint: FULL is a reserved word, so it must be quoted to be used as a name, such as "FULL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FUNCTION (x INT);
-- error 42601: syntax error: unexpected FUNCTION at line 1, column 14 near "CREATE TABLE FUNCTION ("; hint: FUNCTION is a reserved word, so it must be quoted to be used as a name, such as "FUNCTION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE FUSION (x INT);
-- error 42601: syntax error: unexpected FUSION at line 1, column 14 near "CREATE TABLE FUSION ("; hint: FUSION is a reserved word, so it must be quoted to be used as a name, such as "FUSION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE GET (x INT);
-- error 42601: syntax error: unexpected GET at line 1, column 14 near "CREATE TABLE GET ("; hint: GET is a reserved word, so it must be quoted to be used as a name, such as "GET" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE GLOBAL (x INT);
-- error 42601: syntax error: unexpected GLOBAL at line 1, column 14 near "CREATE TABLE GLOBAL ("; hint: GLOBAL is a reserved word, so it must be quoted to be used as a name, such as "GLOBAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE GRANT (x INT);
-- error 42601: syntax error: unexpected GRANT at line 1, column 14 near "CREATE TABLE GRANT ("; hint: GRANT is a reserved word, so it must be quoted to be used as a name, such as "GRANT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE GREATEST (x INT);
-- error 42601: syntax error: unexpected GREATEST at line 1, column 14 near "CREATE TABLE GREATEST ("; hint: GREATEST is a reserved word, so it must be quoted to be used as a name, such as "GREATEST" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE GROUP (x INT);
-- error 42601: syntax error: unexpected GROUP at line 1, column 14 near "CREATE TABLE GROUP ("; hint: GROUP is a reserved word, so it must be quoted to be used as a name, such as "GROUP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE GROUPING (x INT);
-- error 42601: syntax error: unexpected GROUPING at line 1, column 14 near "CREATE TABLE GROUPING ("; hint: GROUPING is a reserved word, so it must be quoted to be used as a name, such as "GROUPING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE GROUPS (x INT);
-- error 42601: syntax error: unexpected GROUPS at line 1, column 14 near "CREATE TABLE GROUPS ("; hint: GROUPS is a reserved word, so it must be quoted to be used as a name, such as "GROUPS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE HAVING (x INT);
-- error 42601: syntax error: unexpected HAVING at line 1, column 14 near "CREATE TABLE HAVING ("; hint: HAVING is a reserved word, so it must be quoted to be used as a name, such as "HAVING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE HOLD (x INT);
-- error 42601: syntax error: unexpected HOLD at line 1, column 14 near "CREATE TABLE HOLD ("; hint: HOLD is a reserved word, so it must be quoted to be used as a name, such as "HOLD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE HOUR (x INT);
-- error 42601: syntax error: unexpected HOUR at line 1, column 14 near "CREATE TABLE HOUR ("; hint: HOUR is a reserved word, so it must be quoted to be used as a name, such as "HOUR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE IDENTITY (x INT);
-- error 42601: syntax error: unexpected IDENTITY at line 1, column 14 near "CREATE TABLE IDENTITY ("; hint: IDENTITY is a reserved word, so it must be quoted to be used as a name, such as "IDENTITY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE IN (x INT);
-- error 42601: syntax error: unexpected IN at line 1, column 14 near "CREATE TABLE IN ("; hint: IN is a reserved word, so it must be quoted to be used as a name, such as "IN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INDICATOR (x INT);
-- error 42601: syntax error: unexpected INDICATOR at line 1, column 14 near "CREATE TABLE INDICATOR ("; hint: INDICATOR is a reserved word, so it must be quoted to be used as a name, such as "INDICATOR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INITIAL (x INT);
-- error 42601: syntax error: unexpected INITIAL at line 1, column 14 near "CREATE TABLE INITIAL ("; hint: INITIAL is a reserved word, so it must be quoted to be used as a name, such as "INITIAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INNER (x INT);
-- error 42601: syntax error: unexpected INNER at line 1, column 14 near "CREATE TABLE INNER ("; hint: INNER is a reserved word, so it must be quoted to be used as a name, such as "INNER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INOUT (x INT);
-- error 42601: syntax error: unexpected INOUT at line 1, column 14 near "CREATE TABLE INOUT ("; hint: INOUT is a reserved word, so it must be quoted to be used as a name, such as "INOUT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INSENSITIVE (x INT);
-- error 42601: syntax error: unexpected INSENSITIVE at line 1, column 14 near "CREATE TABLE INSENSITIVE ("; hint: INSENSITIVE is a reserved word, so it must be quoted to be used as a name, such as "INSENSITIVE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INSERT (x INT);
-- error 42601: syntax error: unexpected INSERT at line 1, column 14 near "CREATE TABLE INSERT ("; hint: INSERT is a reserved word, so it must be quoted to be used as a name, such as "INSERT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INT (x INT);
-- error 42601: syntax error: unexpected INT at line 1, column 14 near "CREATE TABLE INT ("; hint: INT is a reserved word, so it must be quoted to be used as a name, such as "INT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INTEGER (x INT);
-- error 42601: syntax error: unexpected INTEGER at line 1, column 14 near "CREATE TABLE INTEGER ("; hint: INTEGER is a reserved word, so it must be quoted to be used as a name, such as "INTEGER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INTERSECT (x INT);
-- error 42601: syntax error: unexpected INTERSECT at line 1, column 14 near "CREATE TABLE INTERSECT ("; hint: INTERSECT is a reserved word, so it must be quoted to be used as a name, such as "INTERSECT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INTERSECTION (x INT);
-- error 42601: syntax error: unexpected INTERSECTION at line 1, column 14 near "CREATE TABLE INTERSECTION ("; hint: INTERSECTION is a reserved word, so it must be quoted to be used as a name, such as "INTERSECTION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INTERVAL (x INT);
-- error 42601: syntax error: unexpected INTERVAL at line 1, column 14 near "CREATE TABLE INTERVAL ("; hint: INTERVAL is a reserved word, so it must be quoted to be used as a name, such as "INTERVAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE INTO (x INT);
-- error 42601: syntax error: unexpected INTO at line 1, column 14 near "CREATE TABLE INTO ("; hint: INTO is a reserved word, so it must be quoted to be used as a name, such as "INTO" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE IS (x INT);
-- error 42601: syntax error: unexpected IS at line 1, column 14 near "CREATE TABLE IS ("; hint: IS is a reserved word, so it must be quoted to be used as a name, such as "IS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JOIN (x INT);
-- error 42601: syntax error: unexpected JOIN at line 1, column 14 near "CREATE TABLE JOIN ("; hint: JOIN is a reserved word, so it must be quoted to be used as a name, such as "JOIN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON (x INT);
-- error 42601: syntax error: unexpected JSON at line 1, column 14 near "CREATE TABLE JSON ("; hint: JSON is a reserved word, so it must be quoted to be used as a name, such as "JSON" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_ARRAY (x INT);
-- error 42601: syntax error: unexpected JSON_ARRAY at line 1, column 14 near "CREATE TABLE JSON_ARRAY ("; hint: JSON_ARRAY is a reserved word, so it must be quoted to be used as a name, such as "JSON_ARRAY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_ARRAYAGG (x INT);
-- error 42601: syntax error: unexpected JSON_ARRAYAGG at line 1, column 14 near "CREATE TABLE JSON_ARRAYAGG ("; hint: JSON_ARRAYAGG is a reserved word, so it must be quoted to be used as a name, such as "JSON_ARRAYAGG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_EXISTS (x INT);
-- error 42601: syntax error: unexpected JSON_EXISTS at line 1, column 14 near "CREATE TABLE JSON_EXISTS ("; hint: JSON_EXISTS is a reserved word, so it must be quoted to be used as a name, such as "JSON_EXISTS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_OBJECT (x INT);
-- error 42601: syntax error: unexpected JSON_OBJECT at line 1, column 14 near "CREATE TABLE JSON_OBJECT ("; hint: JSON_OBJECT is a reserved word, so it must be quoted to be used as a name, such as "JSON_OBJECT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_OBJECTAGG (x INT);
-- error 42601: syntax error: unexpected JSON_OBJECTAGG at line 1, column 14 near "CREATE TABLE JSON_OBJECTAGG ("; hint: JSON_OBJECTAGG is a reserved word, so it must be quoted to be used as a name, such as "JSON_OBJECTAGG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_QUERY (x INT);
-- error 42601: syntax error: unexpected JSON_QUERY at line 1, column 14 near "CREATE TABLE JSON_QUERY ("; hint: JSON_QUERY is a reserved word, so it must be quoted to be used as a name, such as "JSON_QUERY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_SCALAR (x INT);
-- error 42601: syntax error: unexpected JSON_SCALAR at line 1, column 14 near "CREATE TABLE JSON_SCALAR ("; hint: JSON_SCALAR is a reserved word, so it must be quoted to be used as a name, such as "JSON_SCALAR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_SERIALIZE (x INT);
-- error 42601: syntax error: unexpected JSON_SERIALIZE at line 1, column 14 near "CREATE TABLE JSON_SERIALIZE ("; hint: JSON_SERIALIZE is a reserved word, so it must be quoted to be used as a name, such as "JSON_SERIALIZE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_TABLE (x INT);
-- error 42601: syntax error: unexpected JSON_TABLE at line 1, column 14 near "CREATE TABLE JSON_TABLE ("; hint: JSON_TABLE is a reserved word, so it must be quoted to be used as a name, such as "JSON_TABLE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_TABLE_PRIMITIVE (x INT);
-- error 42601: syntax error: unexpected JSON_TABLE_PRIMITIVE at line 1, column 14 near "CREATE TABLE JSON_TABLE_PRIMITIVE ("; hint: JSON_TABLE_PRIMITIVE is a reserved word, so it must be quoted to be used as a name, such as "JSON_TABLE_PRIMITIVE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE JSON_VALUE (x INT);
-- error 42601: syntax error: unexpected JSON_VALUE at line 1, column 14 near "CREATE TABLE JSON_VALUE ("; hint: JSON_VALUE is a reserved word, so it must be quoted to be used as a name, such as "JSON_VALUE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LAG (x INT);
-- error 42601: syntax error: unexpected LAG at line 1, column 14 near "CREATE TABLE LAG ("; hint: LAG is a reserved word, so it must be quoted to be used as a name, such as "LAG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LANGUAGE (x INT);
-- error 42601: syntax error: unexpected LANGUAGE at line 1, column 14 near "CREATE TABLE LANGUAGE ("; hint: LANGUAGE is a reserved word, so it must be quoted to be used as a name, such as "LANGUAGE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LARGE (x INT);
-- error 42601: syntax error: unexpected LARGE at line 1, column 14 near "CREATE TABLE LARGE ("; hint: LARGE is a reserved word, so it must be quoted to be used as a name, such as "LARGE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LAST_VALUE (x INT);
-- error 42601: syntax error: unexpected LAST_VALUE at line 1, column 14 near "CREATE TABLE LAST_VALUE ("; hint: LAST_VALUE is a reserved word, so it must be quoted to be used as a name, such as "LAST_VALUE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LATERAL (x INT);
-- error 42601: syntax error: unexpected LATERAL at line 1, column 14 near "CREATE TABLE LATERAL ("; hint: LATERAL is a reserved word, so it must be quoted to be used as a name, such as "LATERAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LEAD (x INT);
-- error 42601: syntax error: unexpected LEAD at line 1, column 14 near "CREATE TABLE LEAD ("; hint: LEAD is a reserved word, so it must be quoted to be used as a name, such as "LEAD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LEADING (x INT);
-- error 42601: syntax error: unexpected LEADING at line 1, column 14 near "CREATE TABLE LEADING ("; hint: LEADING is a reserved word, so it must be quoted to be used as a name, such as "LEADING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LEAST (x INT);
-- error 42601: syntax error: unexpected LEAST at line 1, column 14 near "CREATE TABLE LEAST ("; hint: LEAST is a reserved word, so it must be quoted to be used as a name, such as "LEAST" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LEFT (x INT);
-- error 42601: syntax error: unexpected LEFT at line 1, column 14 near "CREATE TABLE LEFT ("; hint: LEFT is a reserved word, so it must be quoted to be used as a name, such as "LEFT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LIKE (x INT);
-- error 42601: syntax error: unexpected LIKE at line 1, column 14 near "CREATE TABLE LIKE ("; hint: LIKE is a reserved word, so it must be quoted to be used as a name, such as "LIKE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LIKE_REGEX (x INT);
-- error 42601: syntax error: unexpected LIKE_REGEX at line 1, column 14 near "CREATE TABLE LIKE_REGEX ("; hint: LIKE_REGEX is a reserved word, so it must be quoted to be used as a name, such as "LIKE_REGEX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LISTAGG (x INT);
-- error 42601: syntax error: unexpected LISTAGG at line 1, column 14 near "CREATE TABLE LISTAGG ("; hint: LISTAGG is a reserved word, so it must be quoted to be used as a name, such as "LISTAGG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LN (x INT);
-- error 42601: syntax error: unexpected LN at line 1, column 14 near "CREATE TABLE LN ("; hint: LN is a reserved word, so it must be quoted to be used as a name, such as "LN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LOCAL (x INT);
-- error 42601: syntax error: unexpected LOCAL at line 1, column 14 near "CREATE TABLE LOCAL ("; hint: LOCAL is a reserved word, so it must be quoted to be used as a name, such as "LOCAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LOCALTIME (x INT);
-- error 42601: syntax error: unexpected LOCALTIME at line 1, column 14 near "CREATE TABLE LOCALTIME ("; hint: LOCALTIME is a reserved word, so it must be quoted to be used as a name, such as "LOCALTIME" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LOCALTIMESTAMP (x INT);
-- error 42601: syntax error: unexpected LOCALTIMESTAMP at line 1, column 14 near "CREATE TABLE LOCALTIMESTAMP ("; hint: LOCALTIMESTAMP is a reserved word, so it must be quoted to be used as a name, such as "LOCALTIMESTAMP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LOG (x INT);
-- error 42601: syntax error: unexpected LOG at line 1, column 14 near "CREATE TABLE LOG ("; hint: LOG is a reserved word, so it must be quoted to be used as a name, such as "LOG" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LOG10 (x INT);
-- error 42601: syntax error: unexpected LOG10 at line 1, column 14 near "CREATE TABLE LOG10 ("; hint: LOG10 is a reserved word, so it must be quoted to be used as a name, such as "LOG10" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LOWER (x INT);
-- error 42601: syntax error: unexpected LOWER at line 1, column 14 near "CREATE TABLE LOWER ("; hint: LOWER is a reserved word, so it must be quoted to be used as a name, such as "LOWER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LPAD (x INT);
-- error 42601: syntax error: unexpected LPAD at line 1, column 14 near "CREATE TABLE LPAD ("; hint: LPAD is a reserved word, so it must be quoted to be used as a name, such as "LPAD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE LTRIM (x INT);
-- error 42601: syntax error: unexpected LTRIM at line 1, column 14 near "CREATE TABLE LTRIM ("; hint: LTRIM is a reserved word, so it must be quoted to be used as a name, such as "LTRIM" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MATCH (x INT);
-- error 42601: syntax error: unexpected MATCH at line 1, column 14 near "CREATE TABLE MATCH ("; hint: MATCH is a reserved word, so it must be quoted to be used as a name, such as "MATCH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MATCH_NUMBER (x INT);
-- error 42601: syntax error: unexpected MATCH_NUMBER at line 1, column 14 near "CREATE TABLE MATCH_NUMBER ("; hint: MATCH_NUMBER is a reserved word, so it must be quoted to be used as a name, such as "MATCH_NUMBER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MATCH_RECOGNIZE (x INT);
-- error 42601: syntax error: unexpected MATCH_RECOGNIZE at line 1, column 14 near "CREATE TABLE MATCH_RECOGNIZE ("; hint: MATCH_RECOGNIZE is a reserved word, so it must be quoted to be used as a name, such as "MATCH_RECOGNIZE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MATCHES (x INT);
-- error 42601: syntax error: unexpected MATCHES at line 1, column 14 near "CREATE TABLE MATCHES ("; hint: MATCHES is a reserved word, so it must be quoted to be used as a name, such as "MATCHES" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MAX (x INT);
-- error 42601: syntax error: unexpected MAX at line 1, column 14 near "CREATE TABLE MAX ("; hint: MAX is a reserved word, so it must be quoted to be used as a name, such as "MAX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MEMBER (x INT);
-- error 42601: syntax error: unexpected MEMBER at line 1, column 14 near "CREATE TABLE MEMBER ("; hint: MEMBER is a reserved word, so it must be quoted to be used as a name, such as "MEMBER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MERGE (x INT);
-- error 42601: syntax error: unexpected MERGE at line 1, column 14 near "CREATE TABLE MERGE ("; hint: MERGE is a reserved word, so it must be quoted to be used as a name, such as "MERGE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE METHOD (x INT);
-- error 42601: syntax error: unexpected METHOD at line 1, column 14 near "CREATE TABLE METHOD ("; hint: METHOD is a reserved word, so it must be quoted to be used as a name, such as "METHOD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MIN (x INT);
-- error 42601: syntax error: unexpected MIN at line 1, column 14 near "CREATE TABLE MIN ("; hint: MIN is a reserved word, so it must be quoted to be used as a name, such as "MIN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MINUTE (x INT);
-- error 42601: syntax error: unexpected MINUTE at line 1, column 14 near "CREATE TABLE MINUTE ("; hint: MINUTE is a reserved word, so it must be quoted to be used as a name, such as "MINUTE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MOD (x INT);
-- error 42601: syntax error: unexpected MOD at line 1, column 14 near "CREATE TABLE MOD ("; hint: MOD is a reserved word, so it must be quoted to be used as a name, such as "MOD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MODIFIES (x INT);
-- error 42601: syntax error: unexpected MODIFIES at line 1, column 14 near "CREATE TABLE MODIFIES ("; hint: MODIFIES is a reserved word, so it must be quoted to be used as a name, such as "MODIFIES" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MODULE (x INT);
-- error 42601: syntax error: unexpected MODULE at line 1, column 14 near "CREATE TABLE MODULE ("; hint: MODULE is a reserved word, so it must be quoted to be used as a name, such as "MODULE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MONTH (x INT);
-- error 42601: syntax error: unexpected MONTH at line 1, column 14 near "CREATE TABLE MONTH ("; hint: MONTH is a reserved word, so it must be quoted to be used as a name, such as "MONTH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE MULTISET (x INT);
-- error 42601: syntax error: unexpected MULTISET at line 1, column 14 near "CREATE TABLE MULTISET ("; hint: MULTISET is a reserved word, so it must be quoted to be used as a name, such as "MULTISET" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NATIONAL (x INT);
-- error 42601: syntax error: unexpected NATIONAL at line 1, column 14 near "CREATE TABLE NATIONAL ("; hint: NATIONAL is a reserved word, so it must be quoted to be used as a name, such as "NATIONAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NATURAL (x INT);
-- error 42601: syntax error: unexpected NATURAL at line 1, column 14 near "CREATE TABLE NATURAL ("; hint: NATURAL is a reserved word, so it must be quoted to be used as a name, such as "NATURAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NCHAR (x INT);
-- error 42601: syntax error: unexpected NCHAR at line 1, column 14 near "CREATE TABLE NCHAR ("; hint: NCHAR is a reserved word, so it must be quoted to be used as a name, such as "NCHAR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NCLOB (x INT);
-- error 42601: syntax error: unexpected NCLOB at line 1, column 14 near "CREATE TABLE NCLOB ("; hint: NCLOB is a reserved word, so it must be quoted to be used as a name, such as "NCLOB" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NEW (x INT);
-- error 42601: syntax error: unexpected NEW at line 1, column 14 near "CREATE TABLE NEW ("; hint: NEW is a reserved word, so it must be quoted to be used as a name, such as "NEW" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NO (x INT);
-- error 42601: syntax error: unexpected NO at line 1, column 14 near "CREATE TABLE NO ("; hint: NO is a reserved word, so it must be quoted to be used as a name, such as "NO" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NONE (x INT);
-- error 42601: syntax error: unexpected NONE at line 1, column 14 near "CREATE TABLE NONE ("; hint: NONE is a reserved word, so it must be quoted to be used as a name, such as "NONE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NORMALIZE (x INT);
-- error 42601: syntax error: unexpected NORMALIZE at line 1, column 14 near "CREATE TABLE NORMALIZE ("; hint: NORMALIZE is a reserved word, so it must be quoted to be used as a name, such as "NORMALIZE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NOT (x INT);
-- error 42601: syntax error: unexpected NOT at line 1, column 14 near "CREATE TABLE NOT ("; hint: NOT is a reserved word, so it must be quoted to be used as a name, such as "NOT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NTH_VALUE (x INT);
-- error 42601: syntax error: unexpected NTH_VALUE at line 1, column 14 near "CREATE TABLE NTH_VALUE ("; hint: NTH_VALUE is a reserved word, so it must be quoted to be used as a name, such as "NTH_VALUE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NTILE (x INT);
-- error 42601: syntax error: unexpected NTILE at line 1, column 14 near "CREATE TABLE NTILE ("; hint: NTILE is a reserved word, so it must be quoted to be used as a name, such as "NTILE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NULL (x INT);
-- error 42601: syntax error: unexpected NULL at line 1, column 14 near "CREATE TABLE NULL ("

CREATE TABLE NULLIF (x INT);
-- error 42601: syntax error: unexpected NULLIF at line 1, column 14 near "CREATE TABLE NULLIF ("; hint: NULLIF is a reserved word, so it must be quoted to be used as a name, such as "NULLIF" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE NUMERIC (x INT);
-- error 42601: syntax error: unexpected NUMERIC at line 1, column 14 near "CREATE TABLE NUMERIC ("; hint: NUMERIC is a reserved word, so it must be quoted to be used as a name, such as "NUMERIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OCTET_LENGTH (x INT);
-- error 42601: syntax error: unexpected OCTET_LENGTH at line 1, column 14 near "CREATE TABLE OCTET_LENGTH ("; hint: OCTET_LENGTH is a reserved word, so it must be quoted to be used as a name, such as "OCTET_LENGTH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OCCURRENCES_REGEX (x INT);
-- error 42601: syntax error: unexpected OCCURRENCES_REGEX at line 1, column 14 near "CREATE TABLE OCCURRENCES_REGEX ("; hint: OCCURRENCES_REGEX is a reserved word, so it must be quoted to be used as a name, such as "OCCURRENCES_REGEX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OF (x INT);
-- error 42601: syntax error: unexpected OF at line 1, column 14 near "CREATE TABLE OF ("; hint: OF is a reserved word, so it must be quoted to be used as a name, such as "OF" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OFFSET (x INT);
-- error 42601: syntax error: unexpected OFFSET at line 1, column 14 near "CREATE TABLE OFFSET ("; hint: OFFSET is a reserved word, so it must be quoted to be used as a name, such as "OFFSET" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OLD (x INT);
-- error 42601: syntax error: unexpected OLD at line 1, column 14 near "CREATE TABLE OLD ("; hint: OLD is a reserved word, so it must be quoted to be used as a name, such as "OLD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OMIT (x INT);
-- error 42601: syntax error: unexpected OMIT at line 1, column 14 near "CREATE TABLE OMIT ("; hint: OMIT is a reserved word, so it must be quoted to be used as a name, such as "OMIT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ON (x INT);
-- error 42601: syntax error: unexpected ON at line 1, column 14 near "CREATE TABLE ON ("; hint: ON is a reserved word, so it must be quoted to be used as a name, such as "ON" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ONE (x INT);
-- error 42601: syntax error: unexpected ONE at line 1, column 14 near "CREATE TABLE ONE ("; hint: ONE is a reserved word, so it must be quoted to be used as a name, such as "ONE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ONLY (x INT);
-- error 42601: syntax error: unexpected ONLY at line 1, column 14 near "CREATE TABLE ONLY ("; hint: ONLY is a reserved word, so it must be quoted to be used as a name, such as "ONLY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OPEN (x INT);
-- error 42601: syntax error: unexpected OPEN at line 1, column 14 near "CREATE TABLE OPEN ("; hint: OPEN is a reserved word, so it must be quoted to be used as a name, such as "OPEN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OR (x INT);
-- error 42601: syntax error: unexpected OR at line 1, column 14 near "CREATE TABLE OR ("; hint: OR is a reserved word, so it must be quoted to be used as a name, such as "OR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ORDER (x INT);
-- error 42601: syntax error: unexpected ORDER at line 1, column 14 near "CREATE TABLE ORDER ("; hint: ORDER is a reserved word, so it must be quoted to be used as a name, such as "ORDER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OUT (x INT);
-- error 42601: syntax error: unexpected OUT at line 1, column 14 near "CREATE TABLE OUT ("; hint: OUT is a reserved word, so it must be quoted to be used as a name, such as "OUT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OUTER (x INT);
-- error 42601: syntax error: unexpected OUTER at line 1, column 14 near "CREATE TABLE OUTER ("; hint: OUTER is a reserved word, so it must be quoted to be used as a name, such as "OUTER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OVER (x INT);
-- error 42601: syntax error: unexpected OVER at line 1, column 14 near "CREATE TABLE OVER ("; hint: OVER is a reserved word, so it must be quoted to be used as a name, such as "OVER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OVERLAPS (x INT);
-- error 42601: syntax error: unexpected OVERLAPS at line 1, column 14 near "CREATE TABLE OVERLAPS ("; hint: OVERLAPS is a reserved word, so it must be quoted to be used as a name, such as "OVERLAPS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE OVERLAY (x INT);
-- error 42601: syntax error: unexpected OVERLAY at line 1, column 14 near "CREATE TABLE OVERLAY ("; hint: OVERLAY is a reserved word, so it must be quoted to be used as a name, such as "OVERLAY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PARAMETER (x INT);
-- error 42601: syntax error: unexpected PARAMETER at line 1, column 14 near "CREATE TABLE PARAMETER ("; hint: PARAMETER is a reserved word, so it must be quoted to be used as a name, such as "PARAMETER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PARTITION (x INT);
-- error 42601: syntax error: unexpected PARTITION at line 1, column 14 near "CREATE TABLE PARTITION ("; hint: PARTITION is a reserved word, so it must be quoted to be used as a name, such as "PARTITION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PATTERN (x INT);
-- error 42601: syntax error: unexpected PATTERN at line 1, column 14 near "CREATE TABLE PATTERN ("; hint: PATTERN is a reserved word, so it must be quoted to be used as a name, such as "PATTERN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PER (x INT);
-- error 42601: syntax error: unexpected PER at line 1, column 14 near "CREATE TABLE PER ("; hint: PER is a reserved word, so it must be quoted to be used as a name, such as "PER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PERCENT (x INT);
-- error 42601: syntax error: unexpected PERCENT at line 1, column 14 near "CREATE TABLE PERCENT ("; hint: PERCENT is a reserved word, so it must be quoted to be used as a name, such as "PERCENT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PERCENT_RANK (x INT);
-- error 42601: syntax error: unexpected PERCENT_RANK at line 1, column 14 near "CREATE TABLE PERCENT_RANK ("; hint: PERCENT_RANK is a reserved word, so it must be quoted to be used as a name, such as "PERCENT_RANK" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PERCENTILE_CONT (x INT);
-- error 42601: syntax error: unexpected PERCENTILE_CONT at line 1, column 14 near "CREATE TABLE PERCENTILE_CONT ("; hint: PERCENTILE_CONT is a reserved word, so it must be quoted to be used as a name, such as "PERCENTILE_CONT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PERCENTILE_DISC (x INT);
-- error 42601: syntax error: unexpected PERCENTILE_DISC at line 1, column 14 near "CREATE TABLE PERCENTILE_DISC ("; hint: PERCENTILE_DISC is a reserved word, so it must be quoted to be used as a name, such as "PERCENTILE_DISC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PERIOD (x INT);
-- error 42601: syntax error: unexpected PERIOD at line 1, column 14 near "CREATE TABLE PERIOD ("; hint: PERIOD is a reserved word, so it must be quoted to be used as a name, such as "PERIOD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PORTION (x INT);
-- error 42601: syntax error: unexpected PORTION at line 1, column 14 near "CREATE TABLE PORTION ("; hint: PORTION is a reserved word, so it must be quoted to be used as a name, such as "PORTION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE POSITION (x INT);
-- error 42601: syntax error: unexpected POSITION at line 1, column 14 near "CREATE TABLE POSITION ("; hint: POSITION is a reserved word, so it must be quoted to be used as a name, such as "POSITION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE POSITION_REGEX (x INT);
-- error 42601: syntax error: unexpected POSITION_REGEX at line 1, column 14 near "CREATE TABLE POSITION_REGEX ("; hint: POSITION_REGEX is a reserved word, so it must be quoted to be used as a name, such as "POSITION_REGEX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE POWER (x INT);
-- error 42601: syntax error: unexpected POWER at line 1, column 14 near "CREATE TABLE POWER ("; hint: POWER is a reserved word, so it must be quoted to be used as a name, such as "POWER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PRECEDES (x INT);
-- error 42601: syntax error: unexpected PRECEDES at line 1, column 14 near "CREATE TABLE PRECEDES ("; hint: PRECEDES is a reserved word, so it must be quoted to be used as a name, such as "PRECEDES" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PRECISION (x INT);
-- error 42601: syntax error: unexpected PRECISION at line 1, column 14 near "CREATE TABLE PRECISION ("; hint: PRECISION is a reserved word, so it must be quoted to be used as a name, such as "PRECISION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PREPARE (x INT);
-- error 42601: syntax error: unexpected PREPARE at line 1, column 14 near "CREATE TABLE PREPARE ("; hint: PREPARE is a reserved word, so it must be quoted to be used as a name, such as "PREPARE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PRIMARY (x INT);
-- error 42601: syntax error: unexpected PRIMARY at line 1, column 14 near "CREATE TABLE PRIMARY ("; hint: PRIMARY is a reserved word, so it must be quoted to be used as a name, such as "PRIMARY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PROCEDURE (x INT);
-- error 42601: syntax error: unexpected PROCEDURE at line 1, column 14 near "CREATE TABLE PROCEDURE ("; hint: PROCEDURE is a reserved word, so it must be quoted to be used as a name, such as "PROCEDURE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE PTF (x INT);
-- error 42601: syntax error: unexpected PTF at line 1, column 14 near "CREATE TABLE PTF ("; hint: PTF is a reserved word, so it must be quoted to be used as a name, such as "PTF" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RANGE (x INT);
-- error 42601: syntax error: unexpected RANGE at line 1, column 14 near "CREATE TABLE RANGE ("; hint: RANGE is a reserved word, so it must be quoted to be used as a name, such as "RANGE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RANK (x INT);
-- error 42601: syntax error: unexpected RANK at line 1, column 14 near "CREATE TABLE RANK ("; hint: RANK is a reserved word, so it must be quoted to be used as a name, such as "RANK" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE READS (x INT);
-- error 42601: syntax error: unexpected READS at line 1, column 14 near "CREATE TABLE READS ("; hint: READS is a reserved word, so it must be quoted to be used as a name, such as "READS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REAL (x INT);
-- error 42601: syntax error: unexpected REAL at line 1, column 14 near "CREATE TABLE REAL ("; hint: REAL is a reserved word, so it must be quoted to be used as a name, such as "REAL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RECURSIVE (x INT);
-- error 42601: syntax error: unexpected RECURSIVE at line 1, column 14 near "CREATE TABLE RECURSIVE ("; hint: RECURSIVE is a reserved word, so it must be quoted to be used as a name, such as "RECURSIVE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REF (x INT);
-- error 42601: syntax error: unexpected REF at line 1, column 14 near "CREATE TABLE REF ("; hint: REF is a reserved word, so it must be quoted to be used as a name, such as "REF" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REFERENCES (x INT);
-- error 42601: syntax error: unexpected REFERENCES at line 1, column 14 near "CREATE TABLE REFERENCES ("; hint: REFERENCES is a reserved word, so it must be quoted to be used as a name, such as "REFERENCES" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REFERENCING (x INT);
-- error 42601: syntax error: unexpected REFERENCING at line 1, column 14 near "CREATE TABLE REFERENCING ("; hint: REFERENCING is a reserved word, so it must be quoted to be used as a name, such as "REFERENCING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_AVGX (x INT);
-- error 42601: syntax error: unexpected REGR_AVGX at line 1, column 14 near "CREATE TABLE REGR_AVGX ("; hint: REGR_AVGX is a reserved word, so it must be quoted to be used as a name, such as "REGR_AVGX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_AVGY (x INT);
-- error 42601: syntax error: unexpected REGR_AVGY at line 1, column 14 near "CREATE TABLE REGR_AVGY ("; hint: REGR_AVGY is a reserved word, so it must be quoted to be used as a name, such as "REGR_AVGY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_COUNT (x INT);
-- error 42601: syntax error: unexpected REGR_COUNT at line 1, column 14 near "CREATE TABLE REGR_COUNT ("; hint: REGR_COUNT is a reserved word, so it must be quoted to be used as a name, such as "REGR_COUNT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_INTERCEPT (x INT);
-- error 42601: syntax error: unexpected REGR_INTERCEPT at line 1, column 14 near "CREATE TABLE REGR_INTERCEPT ("; hint: REGR_INTERCEPT is a reserved word, so it must be quoted to be used as a name, such as "REGR_INTERCEPT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_R2 (x INT);
-- error 42601: syntax error: unexpected REGR_R2 at line 1, column 14 near "CREATE TABLE REGR_R2 ("; hint: REGR_R2 is a reserved word, so it must be quoted to be used as a name, such as "REGR_R2" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_SLOPE (x INT);
-- error 42601: syntax error: unexpected REGR_SLOPE at line 1, column 14 near "CREATE TABLE REGR_SLOPE ("; hint: REGR_SLOPE is a reserved word, so it must be quoted to be used as a name, such as "REGR_SLOPE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_SXX (x INT);
-- error 42601: syntax error: unexpected REGR_SXX at line 1, column 14 near "CREATE TABLE REGR_SXX ("; hint: REGR_SXX is a reserved word, so it must be quoted to be used as a name, such as "REGR_SXX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_SXY (x INT);
-- error 42601: syntax error: unexpected REGR_SXY at line 1, column 14 near "CREATE TABLE REGR_SXY ("; hint: REGR_SXY is a reserved word, so it must be quoted to be used as a name, such as "REGR_SXY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REGR_SYY (x INT);
-- error 42601: syntax error: unexpected REGR_SYY at line 1, column 14 near "CREATE TABLE REGR_SYY ("; hint: REGR_SYY is a reserved word, so it must be quoted to be used as a name, such as "REGR_SYY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RELEASE (x INT);
-- error 42601: syntax error: unexpected RELEASE at line 1, column 14 near "CREATE TABLE RELEASE ("; hint: RELEASE is a reserved word, so it must be quoted to be used as a name, such as "RELEASE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RESULT (x INT);
-- error 42601: syntax error: unexpected RESULT at line 1, column 14 near "CREATE TABLE RESULT ("; hint: RESULT is a reserved word, so it must be quoted to be used as a name, such as "RESULT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RETURN (x INT);
-- error 42601: syntax error: unexpected RETURN at line 1, column 14 near "CREATE TABLE RETURN ("; hint: RETURN is a reserved word, so it must be quoted to be used as a name, such as "RETURN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RETURNS (x INT);
-- error 42601: syntax error: unexpected RETURNS at line 1, column 14 near "CREATE TABLE RETURNS ("; hint: RETURNS is a reserved word, so it must be quoted to be used as a name, such as "RETURNS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE REVOKE (x INT);
-- error 42601: syntax error: unexpected REVOKE at line 1, column 14 near "CREATE TABLE REVOKE ("; hint: REVOKE is a reserved word, so it must be quoted to be used as a name, such as "REVOKE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RIGHT (x INT);
-- error 42601: syntax error: unexpected RIGHT at line 1, column 14 near "CREATE TABLE RIGHT ("; hint: RIGHT is a reserved word, so it must be quoted to be used as a name, such as "RIGHT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ROLLBACK (x INT);
-- error 42601: syntax error: unexpected ROLLBACK at line 1, column 14 near "CREATE TABLE ROLLBACK ("; hint: ROLLBACK is a reserved word, so it must be quoted to be used as a name, such as "ROLLBACK" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ROLLUP (x INT);
-- error 42601: syntax error: unexpected ROLLUP at line 1, column 14 near "CREATE TABLE ROLLUP ("; hint: ROLLUP is a reserved word, so it must be quoted to be used as a name, such as "ROLLUP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ROW (x INT);
-- error 42601: syntax error: unexpected ROW at line 1, column 14 near "CREATE TABLE ROW ("; hint: ROW is a reserved word, so it must be quoted to be used as a name, such as "ROW" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ROW_NUMBER (x INT);
-- error 42601: syntax error: unexpected ROW_NUMBER at line 1, column 14 near "CREATE TABLE ROW_NUMBER ("; hint: ROW_NUMBER is a reserved word, so it must be quoted to be used as a name, such as "ROW_NUMBER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE ROWS (x INT);
-- error 42601: syntax error: unexpected ROWS at line 1, column 14 near "CREATE TABLE ROWS ("; hint: ROWS is a reserved word, so it must be quoted to be used as a name, such as "ROWS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RPAD (x INT);
-- error 42601: syntax error: unexpected RPAD at line 1, column 14 near "CREATE TABLE RPAD ("; hint: RPAD is a reserved word, so it must be quoted to be used as a name, such as "RPAD" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RTRIM (x INT);
-- error 42601: syntax error: unexpected RTRIM at line 1, column 14 near "CREATE TABLE RTRIM ("; hint: RTRIM is a reserved word, so it must be quoted to be used as a name, such as "RTRIM" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE RUNNING (x INT);
-- error 42601: syntax error: unexpected RUNNING at line 1, column 14 near "CREATE TABLE RUNNING ("; hint: RUNNING is a reserved word, so it must be quoted to be used as a name, such as "RUNNING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SAVEPOINT (x INT);
-- error 42601: syntax error: unexpected SAVEPOINT at line 1, column 14 near "CREATE TABLE SAVEPOINT ("; hint: SAVEPOINT is a reserved word, so it must be quoted to be used as a name, such as "SAVEPOINT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SCOPE (x INT);
-- error 42601: syntax error: unexpected SCOPE at line 1, column 14 near "CREATE TABLE SCOPE ("; hint: SCOPE is a reserved word, so it must be quoted to be used as a name, such as "SCOPE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SCROLL (x INT);
-- error 42601: syntax error: unexpected SCROLL at line 1, column 14 near "CREATE TABLE SCROLL ("; hint: SCROLL is a reserved word, so it must be quoted to be used as a name, such as "SCROLL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SEARCH (x INT);
-- error 42601: syntax error: unexpected SEARCH at line 1, column 14 near "CREATE TABLE SEARCH ("; hint: SEARCH is a reserved word, so it must be quoted to be used as a name, such as "SEARCH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SECOND (x INT);
-- error 42601: syntax error: unexpected SECOND at line 1, column 14 near "CREATE TABLE SECOND ("; hint: SECOND is a reserved word, so it must be quoted to be used as a name, such as "SECOND" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SEEK (x INT);
-- error 42601: syntax error: unexpected SEEK at line 1, column 14 near "CREATE TABLE SEEK ("; hint: SEEK is a reserved word, so it must be quoted to be used as a name, such as "SEEK" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SELECT (x INT);
-- error 42601: syntax error: unexpected SELECT at line 1, column 14 near "CREATE TABLE SELECT ("; hint: SELECT is a reserved word, so it must be quoted to be used as a name, such as "SELECT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SENSITIVE (x INT);
-- error 42601: syntax error: unexpected SENSITIVE at line 1, column 14 near "CREATE TABLE SENSITIVE ("; hint: SENSITIVE is a reserved word, so it must be quoted to be used as a name, such as "SENSITIVE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SESSION_USER (x INT);
-- error 42601: syntax error: unexpected SESSION_USER at line 1, column 14 near "CREATE TABLE SESSION_USER ("; hint: SESSION_USER is a reserved word, so it must be quoted to be used as a name, such as "SESSION_USER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SET (x INT);
-- error 42601: syntax error: unexpected SET at line 1, column 14 near "CREATE TABLE SET ("; hint: SET is a reserved word, so it must be quoted to be used as a name, such as "SET" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SHOW (x INT);
-- error 42601: syntax error: unexpected SHOW at line 1, column 14 near "CREATE TABLE SHOW ("; hint: SHOW is a reserved word, so it must be quoted to be used as a name, such as "SHOW" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SIMILAR (x INT);
-- error 42601: syntax error: unexpected SIMILAR at line 1, column 14 near "CREATE TABLE SIMILAR ("; hint: SIMILAR is a reserved word, so it must be quoted to be used as a name, such as "SIMILAR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SIN (x INT);
-- error 42601: syntax error: unexpected SIN at line 1, column 14 near "CREATE TABLE SIN ("; hint: SIN is a reserved word, so it must be quoted to be used as a name, such as "SIN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SINH (x INT);
-- error 42601: syntax error: unexpected SINH at line 1, column 14 near "CREATE TABLE SINH ("; hint: SINH is a reserved word, so it must be quoted to be used as a name, such as "SINH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SKIP (x INT);
-- error 42601: syntax error: unexpected SKIP at line 1, column 14 near "CREATE TABLE SKIP ("; hint: SKIP is a reserved word, so it must be quoted to be used as a name, such as "SKIP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SMALLINT (x INT);
-- error 42601: syntax error: unexpected SMALLINT at line 1, column 14 near "CREATE TABLE SMALLINT ("; hint: SMALLINT is a reserved word, so it must be quoted to be used as a name, such as "SMALLINT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SOME (x INT);
-- error 42601: syntax error: unexpected SOME at line 1, column 14 near "CREATE TABLE SOME ("; hint: SOME is a reserved word, so it must be quoted to be used as a name, such as "SOME" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SPECIFIC (x INT);
-- error 42601: syntax error: unexpected SPECIFIC at line 1, column 14 near "CREATE TABLE SPECIFIC ("; hint: SPECIFIC is a reserved word, so it must be quoted to be used as a name, such as "SPECIFIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SPECIFICTYPE (x INT);
-- error 42601: syntax error: unexpected SPECIFICTYPE at line 1, column 14 near "CREATE TABLE SPECIFICTYPE ("; hint: SPECIFICTYPE is a reserved word, so it must be quoted to be used as a name, such as "SPECIFICTYPE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SQL (x INT);
-- error 42601: syntax error: unexpected SQL at line 1, column 14 near "CREATE TABLE SQL ("; hint: SQL is a reserved word, so it must be quoted to be used as a name, such as "SQL" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SQLEXCEPTION (x INT);
-- error 42601: syntax error: unexpected SQLEXCEPTION at line 1, column 14 near "CREATE TABLE SQLEXCEPTION ("; hint: SQLEXCEPTION is a reserved word, so it must be quoted to be used as a name, such as "SQLEXCEPTION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SQLSTATE (x INT);
-- error 42601: syntax error: unexpected SQLSTATE at line 1, column 14 near "CREATE TABLE SQLSTATE ("; hint: SQLSTATE is a reserved word, so it must be quoted to be used as a name, such as "SQLSTATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SQLWARNING (x INT);
-- error 42601: syntax error: unexpected SQLWARNING at line 1, column 14 near "CREATE TABLE SQLWARNING ("; hint: SQLWARNING is a reserved word, so it must be quoted to be used as a name, such as "SQLWARNING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SQRT (x INT);
-- error 42601: syntax error: unexpected SQRT at line 1, column 14 near "CREATE TABLE SQRT ("; hint: SQRT is a reserved word, so it must be quoted to be used as a name, such as "SQRT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE START (x INT);
-- error 42601: syntax error: unexpected START at line 1, column 14 near "CREATE TABLE START ("; hint: START is a reserved word, so it must be quoted to be used as a name, such as "START" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE STATIC (x INT);
-- error 42601: syntax error: unexpected STATIC at line 1, column 14 near "CREATE TABLE STATIC ("; hint: STATIC is a reserved word, so it must be quoted to be used as a name, such as "STATIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE STDDEV_POP (x INT);
-- error 42601: syntax error: unexpected STDDEV_POP at line 1, column 14 near "CREATE TABLE STDDEV_POP ("; hint: STDDEV_POP is a reserved word, so it must be quoted to be used as a name, such as "STDDEV_POP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE STDDEV_SAMP (x INT);
-- error 42601: syntax error: unexpected STDDEV_SAMP at line 1, column 14 near "CREATE TABLE STDDEV_SAMP ("; hint: STDDEV_SAMP is a reserved word, so it must be quoted to be used as a name, such as "STDDEV_SAMP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SUBMULTISET (x INT);
-- error 42601: syntax error: unexpected SUBMULTISET at line 1, column 14 near "CREATE TABLE SUBMULTISET ("; hint: SUBMULTISET is a reserved word, so it must be quoted to be used as a name, such as "SUBMULTISET" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SUBSET (x INT);
-- error 42601: syntax error: unexpected SUBSET at line 1, column 14 near "CREATE TABLE SUBSET ("; hint: SUBSET is a reserved word, so it must be quoted to be used as a name, such as "SUBSET" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SUBSTRING (x INT);
-- error 42601: syntax error: unexpected SUBSTRING at line 1, column 14 near "CREATE TABLE SUBSTRING ("; hint: SUBSTRING is a reserved word, so it must be quoted to be used as a name, such as "SUBSTRING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SUBSTRING_REGEX (x INT);
-- error 42601: syntax error: unexpected SUBSTRING_REGEX at line 1, column 14 near "CREATE TABLE SUBSTRING_REGEX ("; hint: SUBSTRING_REGEX is a reserved word, so it must be quoted to be used as a name, such as "SUBSTRING_REGEX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SUCCEEDS (x INT);
-- error 42601: syntax error: unexpected SUCCEEDS at line 1, column 14 near "CREATE TABLE SUCCEEDS ("; hint: SUCCEEDS is a reserved word, so it must be quoted to be used as a name, such as "SUCCEEDS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SUM (x INT);
-- error 42601: syntax error: unexpected SUM at line 1, column 14 near "CREATE TABLE SUM ("; hint: SUM is a reserved word, so it must be quoted to be used as a name, such as "SUM" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SYMMETRIC (x INT);
-- error 42601: syntax error: unexpected SYMMETRIC at line 1, column 14 near "CREATE TABLE SYMMETRIC ("; hint: SYMMETRIC is a reserved word, so it must be quoted to be used as a name, such as "SYMMETRIC" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SYSTEM (x INT);
-- error 42601: syntax error: unexpected SYSTEM at line 1, column 14 near "CREATE TABLE SYSTEM ("; hint: SYSTEM is a reserved word, so it must be quoted to be used as a name, such as "SYSTEM" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SYSTEM_TIME (x INT);
-- error 42601: syntax error: unexpected SYSTEM_TIME at line 1, column 14 near "CREATE TABLE SYSTEM_TIME ("; hint: SYSTEM_TIME is a reserved word, so it must be quoted to be used as a name, such as "SYSTEM_TIME" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE SYSTEM_USER (x INT);
-- error 42601: syntax error: unexpected SYSTEM_USER at line 1, column 14 near "CREATE TABLE SYSTEM_USER ("; hint: SYSTEM_USER is a reserved word, so it must be quoted to be used as a name, such as "SYSTEM_USER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TABLE (x INT);
-- error 42601: syntax error: unexpected TABLE at line 1, column 14 near "CREATE TABLE TABLE ("; hint: TABLE is a reserved word, so it must be quoted to be used as a name, such as "TABLE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TABLESAMPLE (x INT);
-- error 42601: syntax error: unexpected TABLESAMPLE at line 1, column 14 near "CREATE TABLE TABLESAMPLE ("; hint: TABLESAMPLE is a reserved word, so it must be quoted to be used as a name, such as "TABLESAMPLE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TAN (x INT);
-- error 42601: syntax error: unexpected TAN at line 1, column 14 near "CREATE TABLE TAN ("; hint: TAN is a reserved word, so it must be quoted to be used as a name, such as "TAN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TANH (x INT);
-- error 42601: syntax error: unexpected TANH at line 1, column 14 near "CREATE TABLE TANH ("; hint: TANH is a reserved word, so it must be quoted to be used as a name, such as "TANH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE THEN (x INT);
-- error 42601: syntax error: unexpected THEN at line 1, column 14 near "CREATE TABLE THEN ("; hint: THEN is a reserved word, so it must be quoted to be used as a name, such as "THEN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TIME (x INT);
-- error 42601: syntax error: unexpected TIME at line 1, column 14 near "CREATE TABLE TIME ("; hint: TIME is a reserved word, so it must be quoted to be used as a name, such as "TIME" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TIMESTAMP (x INT);
-- error 42601: syntax error: unexpected TIMESTAMP at line 1, column 14 near "CREATE TABLE TIMESTAMP ("; hint: TIMESTAMP is a reserved word, so it must be quoted to be used as a name, such as "TIMESTAMP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TIMEZONE_HOUR (x INT);
-- error 42601: syntax error: unexpected TIMEZONE_HOUR at line 1, column 14 near "CREATE TABLE TIMEZONE_HOUR ("; hint: TIMEZONE_HOUR is a reserved word, so it must be quoted to be used as a name, such as "TIMEZONE_HOUR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TIMEZONE_MINUTE (x INT);
-- error 42601: syntax error: unexpected TIMEZONE_MINUTE at line 1, column 14 near "CREATE TABLE TIMEZONE_MINUTE ("; hint: TIMEZONE_MINUTE is a reserved word, so it must be quoted to be used as a name, such as "TIMEZONE_MINUTE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TO (x INT);
-- error 42601: syntax error: unexpected TO at line 1, column 14 near "CREATE TABLE TO ("; hint: TO is a reserved word, so it must be quoted to be used as a name, such as "TO" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRAILING (x INT);
-- error 42601: syntax error: unexpected TRAILING at line 1, column 14 near "CREATE TABLE TRAILING ("; hint: TRAILING is a reserved word, so it must be quoted to be used as a name, such as "TRAILING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRANSLATE (x INT);
-- error 42601: syntax error: unexpected TRANSLATE at line 1, column 14 near "CREATE TABLE TRANSLATE ("; hint: TRANSLATE is a reserved word, so it must be quoted to be used as a name, such as "TRANSLATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRANSLATE_REGEX (x INT);
-- error 42601: syntax error: unexpected TRANSLATE_REGEX at line 1, column 14 near "CREATE TABLE TRANSLATE_REGEX ("; hint: TRANSLATE_REGEX is a reserved word, so it must be quoted to be used as a name, such as "TRANSLATE_REGEX" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRANSLATION (x INT);
-- error 42601: syntax error: unexpected TRANSLATION at line 1, column 14 near "CREATE TABLE TRANSLATION ("; hint: TRANSLATION is a reserved word, so it must be quoted to be used as a name, such as "TRANSLATION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TREAT (x INT);
-- error 42601: syntax error: unexpected TREAT at line 1, column 14 near "CREATE TABLE TREAT ("; hint: TREAT is a reserved word, so it must be quoted to be used as a name, such as "TREAT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRIGGER (x INT);
-- error 42601: syntax error: unexpected TRIGGER at line 1, column 14 near "CREATE TABLE TRIGGER ("; hint: TRIGGER is a reserved word, so it must be quoted to be used as a name, such as "TRIGGER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRIM (x INT);
-- error 42601: syntax error: unexpected TRIM at line 1, column 14 near "CREATE TABLE TRIM ("; hint: TRIM is a reserved word, so it must be quoted to be used as a name, such as "TRIM" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRIM_ARRAY (x INT);
-- error 42601: syntax error: unexpected TRIM_ARRAY at line 1, column 14 near "CREATE TABLE TRIM_ARRAY ("; hint: TRIM_ARRAY is a reserved word, so it must be quoted to be used as a name, such as "TRIM_ARRAY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE TRUE (x INT);
-- error 42601: syntax error: unexpected TRUE at line 1, column 14 near "CREATE TABLE TRUE ("

CREATE TABLE TRUNCATE (x INT);
-- error 42601: syntax error: unexpected TRUNCATE at line 1, column 14 near "CREATE TABLE TRUNCATE ("; hint: TRUNCATE is a reserved word, so it must be quoted to be used as a name, such as "TRUNCATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE UESCAPE (x INT);
-- error 42601: syntax error: unexpected UESCAPE at line 1, column 14 near "CREATE TABLE UESCAPE ("; hint: UESCAPE is a reserved word, so it must be quoted to be used as a name, such as "UESCAPE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE UNION (x INT);
-- error 42601: syntax error: unexpected UNION at line 1, column 14 near "CREATE TABLE UNION ("; hint: UNION is a reserved word, so it must be quoted to be used as a name, such as "UNION" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE UNIQUE (x INT);
-- error 42601: syntax error: unexpected UNIQUE at line 1, column 14 near "CREATE TABLE UNIQUE ("; hint: UNIQUE is a reserved word, so it must be quoted to be used as a name, such as "UNIQUE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE UNKNOWN (x INT);
-- error 42601: syntax error: unexpected UNKNOWN at line 1, column 14 near "CREATE TABLE UNKNOWN ("

CREATE TABLE UNNEST (x INT);
-- error 42601: syntax error: unexpected UNNEST at line 1, column 14 near "CREATE TABLE UNNEST ("; hint: UNNEST is a reserved word, so it must be quoted to be used as a name, such as "UNNEST" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE UPDATE (x INT);
-- error 42601: syntax error: unexpected UPDATE at line 1, column 14 near "CREATE TABLE UPDATE ("; hint: UPDATE is a reserved word, so it must be quoted to be used as a name, such as "UPDATE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE UPPER (x INT);
-- error 42601: syntax error: unexpected UPPER at line 1, column 14 near "CREATE TABLE UPPER ("; hint: UPPER is a reserved word, so it must be quoted to be used as a name, such as "UPPER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE USER (x INT);
-- error 42601: syntax error: unexpected USER at line 1, column 14 near "CREATE TABLE USER ("; hint: USER is a reserved word, so it must be quoted to be used as a name, such as "USER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE USING (x INT);
-- error 42601: syntax error: unexpected USING at line 1, column 14 near "CREATE TABLE USING ("; hint: USING is a reserved word, so it must be quoted to be used as a name, such as "USING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VALUE (x INT);
-- error 42601: syntax error: unexpected VALUE at line 1, column 14 near "CREATE TABLE VALUE ("; hint: VALUE is a reserved word, so it must be quoted to be used as a name, such as "VALUE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VALUES (x INT);
-- error 42601: syntax error: unexpected VALUES at line 1, column 14 near "CREATE TABLE VALUES ("; hint: VALUES is a reserved word, so it must be quoted to be used as a name, such as "VALUES" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VALUE_OF (x INT);
-- error 42601: syntax error: unexpected VALUE_OF at line 1, column 14 near "CREATE TABLE VALUE_OF ("; hint: VALUE_OF is a reserved word, so it must be quoted to be used as a name, such as "VALUE_OF" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VAR_POP (x INT);
-- error 42601: syntax error: unexpected VAR_POP at line 1, column 14 near "CREATE TABLE VAR_POP ("; hint: VAR_POP is a reserved word, so it must be quoted to be used as a name, such as "VAR_POP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VAR_SAMP (x INT);
-- error 42601: syntax error: unexpected VAR_SAMP at line 1, column 14 near "CREATE TABLE VAR_SAMP ("; hint: VAR_SAMP is a reserved word, so it must be quoted to be used as a name, such as "VAR_SAMP" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VARBINARY (x INT);
-- error 42601: syntax error: unexpected VARBINARY at line 1, column 14 near "CREATE TABLE VARBINARY ("; hint: VARBINARY is a reserved word, so it must be quoted to be used as a name, such as "VARBINARY" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VARCHAR (x INT);
-- error 42601: syntax error: unexpected VARCHAR at line 1, column 14 near "CREATE TABLE VARCHAR ("; hint: VARCHAR is a reserved word, so it must be quoted to be used as a name, such as "VARCHAR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VARYING (x INT);
-- error 42601: syntax error: unexpected VARYING at line 1, column 14 near "CREATE TABLE VARYING ("; hint: VARYING is a reserved word, so it must be quoted to be used as a name, such as "VARYING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE VERSIONING (x INT);
-- error 42601: syntax error: unexpected VERSIONING at line 1, column 14 near "CREATE TABLE VERSIONING ("; hint: VERSIONING is a reserved word, so it must be quoted to be used as a name, such as "VERSIONING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WHEN (x INT);
-- error 42601: syntax error: unexpected WHEN at line 1, column 14 near "CREATE TABLE WHEN ("; hint: WHEN is a reserved word, so it must be quoted to be used as a name, such as "WHEN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WHENEVER (x INT);
-- error 42601: syntax error: unexpected WHENEVER at line 1, column 14 near "CREATE TABLE WHENEVER ("; hint: WHENEVER is a reserved word, so it must be quoted to be used as a name, such as "WHENEVER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WHERE (x INT);
-- error 42601: syntax error: unexpected WHERE at line 1, column 14 near "CREATE TABLE WHERE ("; hint: WHERE is a reserved word, so it must be quoted to be used as a name, such as "WHERE" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WIDTH_BUCKET (x INT);
-- error 42601: syntax error: unexpected WIDTH_BUCKET at line 1, column 14 near "CREATE TABLE WIDTH_BUCKET ("; hint: WIDTH_BUCKET is a reserved word, so it must be quoted to be used as a name, such as "WIDTH_BUCKET" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WINDOW (x INT);
-- error 42601: syntax error: unexpected WINDOW at line 1, column 14 near "CREATE TABLE WINDOW ("; hint: WINDOW is a reserved word, so it must be quoted to be used as a name, such as "WINDOW" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WITH (x INT);
-- error 42601: syntax error: unexpected WITH at line 1, column 14 near "CREATE TABLE WITH ("; hint: WITH is a reserved word, so it must be quoted to be used as a name, such as "WITH" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WITHIN (x INT);
-- error 42601: syntax error: unexpected WITHIN at line 1, column 14 near "CREATE TABLE WITHIN ("; hint: WITHIN is a reserved word, so it must be quoted to be used as a name, such as "WITHIN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE WITHOUT (x INT);
-- error 42601: syntax error: unexpected WITHOUT at line 1, column 14 near "CREATE TABLE WITHOUT ("; hint: WITHOUT is a reserved word, so it must be quoted to be used as a name, such as "WITHOUT" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE YEAR (x INT);
-- error 42601: syntax error: unexpected YEAR at line 1, column 14 near "CREATE TABLE YEAR ("; hint: YEAR is a reserved word, so it must be quoted to be used as a name, such as "YEAR" (see https://vsql.readthedocs.io/en/latest/keywords.html)

-- # Key words aren't case sensitive (Syntax Rules, 33), and the case-normal
-- # form of an identifier is upper case (Syntax Rules, 24 and 26), so a lower
-- # case reserved word is rejected too, for a column as well as a table.
CREATE TABLE abs (x INT);
-- error 42601: syntax error: unexpected ABS at line 1, column 14 near "CREATE TABLE abs ("; hint: ABS is a reserved word, so it must be quoted to be used as a name, such as "ABS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE foo (ABS INT);
-- error 42601: syntax error: unexpected ABS at line 1, column 19 near "TABLE foo (ABS INT"; hint: ABS is a reserved word, so it must be quoted to be used as a name, such as "ABS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

CREATE TABLE foo (abs int);
-- error 42601: syntax error: unexpected ABS at line 1, column 19 near "TABLE foo (abs int"; hint: ABS is a reserved word, so it must be quoted to be used as a name, such as "ABS" (see https://vsql.readthedocs.io/en/latest/keywords.html)
