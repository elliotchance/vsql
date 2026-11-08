-- # Every kind of constraint can be named, on a column or the table. A
-- # constraint without a name gets the first name of its kind that isn't used,
-- # counting from 1 (or the position of the column for a NOT NULL).
CREATE TABLE t (
  a INT CONSTRAINT a_not_null NOT NULL CONSTRAINT a_check CHECK (a > 0),
  b INT CONSTRAINT b_unique UNIQUE CONSTRAINT b_references REFERENCES t,
  c INT NOT NULL UNIQUE,
  CONSTRAINT pk PRIMARY KEY (a),
  CONSTRAINT "c check" CHECK (c > b),
  CHECK (c > a),
  CONSTRAINT c_references FOREIGN KEY (c) REFERENCES t (b)
);
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
SELECT constraint_name, check_clause FROM information_schema.check_constraints;
SELECT constraint_name, unique_constraint_name FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: PK CONSTRAINT_TYPE: PRIMARY KEY
-- CONSTRAINT_NAME: B_UNIQUE CONSTRAINT_TYPE: UNIQUE
-- CONSTRAINT_NAME: T_UNIQUE_1 CONSTRAINT_TYPE: UNIQUE
-- CONSTRAINT_NAME: B_REFERENCES CONSTRAINT_TYPE: FOREIGN KEY
-- CONSTRAINT_NAME: C_REFERENCES CONSTRAINT_TYPE: FOREIGN KEY
-- CONSTRAINT_NAME: A_NOT_NULL CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: T_NOT_NULL_3 CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: A_CHECK CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: c check CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: T_CHECK_1 CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: A_NOT_NULL CHECK_CLAUSE: A IS NOT NULL
-- CONSTRAINT_NAME: T_NOT_NULL_3 CHECK_CLAUSE: C IS NOT NULL
-- CONSTRAINT_NAME: A_CHECK CHECK_CLAUSE: A > 0
-- CONSTRAINT_NAME: c check CHECK_CLAUSE: C > B
-- CONSTRAINT_NAME: T_CHECK_1 CHECK_CLAUSE: C > A
-- CONSTRAINT_NAME: B_REFERENCES UNIQUE_CONSTRAINT_NAME: PK
-- CONSTRAINT_NAME: C_REFERENCES UNIQUE_CONSTRAINT_NAME: B_UNIQUE

-- # A PRIMARY KEY or REFERENCES on a column can be named.
CREATE TABLE parent (id INT CONSTRAINT parent_pk PRIMARY KEY);
CREATE TABLE child (parent_id INT CONSTRAINT child_parent REFERENCES parent);
SELECT constraint_name, table_name, constraint_type FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: CHILD_PARENT TABLE_NAME: CHILD CONSTRAINT_TYPE: FOREIGN KEY
-- CONSTRAINT_NAME: PARENT_PK TABLE_NAME: PARENT CONSTRAINT_TYPE: PRIMARY KEY
-- CONSTRAINT_NAME: PARENT_NOT_NULL_1 TABLE_NAME: PARENT CONSTRAINT_TYPE: CHECK

-- # A constraint name must be unique in the schema, but the same name can be
-- # used in another schema.
CREATE TABLE t1 (a INT CONSTRAINT c1 CHECK (a > 0), b INT CONSTRAINT c1 UNIQUE);
CREATE TABLE t2 (a INT CONSTRAINT c2 NOT NULL CONSTRAINT c2 CHECK (a > 0));
CREATE TABLE t3 (a INT CONSTRAINT c3 CHECK (a > 0));
CREATE TABLE t4 (a INT, CONSTRAINT c3 PRIMARY KEY (a));
CREATE SCHEMA s;
CREATE TABLE s.t4 (a INT, CONSTRAINT c3 PRIMARY KEY (a));
SELECT constraint_schema, constraint_name, table_name FROM information_schema.table_constraints;
-- error 42710: duplicate constraint: C1
-- error 42710: duplicate constraint: C2
-- msg: CREATE TABLE 1
-- error 42710: duplicate constraint: C3
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: C3 TABLE_NAME: T3
-- CONSTRAINT_SCHEMA: S CONSTRAINT_NAME: C3 TABLE_NAME: T4
-- CONSTRAINT_SCHEMA: S CONSTRAINT_NAME: T4_NOT_NULL_1 TABLE_NAME: T4

-- # A name can't be used for another constraint, even if it's the name that a
-- # constraint without one would get. A constraint without a name gets the next
-- # name that isn't used instead.
CREATE TABLE t (a INT CHECK (a > 0));
CREATE TABLE u (a INT CONSTRAINT t_check_1 CHECK (a > 0));
CREATE TABLE v (a INT CONSTRAINT t_check_1 CHECK (a > 0), CONSTRAINT v_check_1 UNIQUE (a), b INT CHECK (b > 0), CHECK (b > a), CONSTRAINT v_primary_key CHECK (b > 1), PRIMARY KEY (b));
SELECT constraint_name, table_name FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- error 42710: duplicate constraint: T_CHECK_1
-- error 42710: duplicate constraint: T_CHECK_1
-- CONSTRAINT_NAME: T_CHECK_1 TABLE_NAME: T

-- # The next name that isn't used is also used when the default name is used
-- # by another constraint of the same table.
CREATE TABLE v (a INT, CONSTRAINT v_check_1 UNIQUE (a), b INT CHECK (b > 0), CHECK (b > a), CONSTRAINT v_primary_key CHECK (b > 1), PRIMARY KEY (b));
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: V_PRIMARY_KEY_2 CONSTRAINT_TYPE: PRIMARY KEY
-- CONSTRAINT_NAME: V_CHECK_1 CONSTRAINT_TYPE: UNIQUE
-- CONSTRAINT_NAME: V_NOT_NULL_2 CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: V_CHECK_2 CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: V_CHECK_3 CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: V_PRIMARY_KEY CONSTRAINT_TYPE: CHECK

-- # A constraint name can be qualified by the schema of the table, but not
-- # another schema or catalog.
CREATE SCHEMA s;
CREATE TABLE s.t (a INT CONSTRAINT s.c1 CHECK (a > 0), b INT CONSTRAINT c2 CHECK (b > 0));
CREATE TABLE s.u (a INT CONSTRAINT public.c1 CHECK (a > 0));
CREATE TABLE s.v (a INT CONSTRAINT other.s.c1 CHECK (a > 0));
SELECT constraint_schema, constraint_name FROM information_schema.table_constraints;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- error 42601: syntax error: constraint PUBLIC.C1 must be in the same schema as table ":memory:".S.U
-- error 42601: syntax error: constraint OTHER.S.C1 must be in the same schema as table ":memory:".S.V
-- CONSTRAINT_SCHEMA: S CONSTRAINT_NAME: C1
-- CONSTRAINT_SCHEMA: S CONSTRAINT_NAME: C2

-- # A column can only have one named NOT NULL.
CREATE TABLE t (a INT CONSTRAINT a1 NOT NULL CONSTRAINT a2 NOT NULL);
CREATE TABLE u (a INT CONSTRAINT a1 NOT NULL NOT NULL);
SELECT constraint_name FROM information_schema.table_constraints;
-- error 42601: syntax error: column A has more than one named NOT NULL
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: A1

-- # A column added by ALTER TABLE ADD COLUMN can have named constraints, and
-- # the other constraints keep their names.
CREATE TABLE t (a INT CONSTRAINT a_check CHECK (a > 0), b INT CHECK (b > 0));
ALTER TABLE t ADD COLUMN c INT CONSTRAINT c_unique UNIQUE CONSTRAINT c_not_null NOT NULL;
ALTER TABLE t ADD COLUMN d INT CONSTRAINT a_check CHECK (d > 0);
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- error 42710: duplicate constraint: A_CHECK
-- CONSTRAINT_NAME: C_UNIQUE CONSTRAINT_TYPE: UNIQUE
-- CONSTRAINT_NAME: C_NOT_NULL CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: A_CHECK CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: T_CHECK_1 CONSTRAINT_TYPE: CHECK

-- # The names are read back from the file, including a name that isn't the
-- # default because the default was already used.
/* connection 1 */
CREATE TABLE u (a INT CONSTRAINT t_check_1 CHECK (a > 0));
CREATE TABLE t (a INT CONSTRAINT "a not null" NOT NULL CONSTRAINT a_unique UNIQUE CHECK (a > 0), b INT, CONSTRAINT pk PRIMARY KEY (b), CONSTRAINT fk FOREIGN KEY (a) REFERENCES t (b));
/* connection 2 */
SELECT constraint_name, table_name FROM information_schema.table_constraints;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 2: CONSTRAINT_NAME: PK TABLE_NAME: T
-- 2: CONSTRAINT_NAME: A_UNIQUE TABLE_NAME: T
-- 2: CONSTRAINT_NAME: FK TABLE_NAME: T
-- 2: CONSTRAINT_NAME: a not null TABLE_NAME: T
-- 2: CONSTRAINT_NAME: T_NOT_NULL_2 TABLE_NAME: T
-- 2: CONSTRAINT_NAME: T_CHECK_2 TABLE_NAME: T
-- 2: CONSTRAINT_NAME: T_CHECK_1 TABLE_NAME: U

-- # Only a name that isn't the default for its position is in the definition.
CREATE TABLE t (a INT CONSTRAINT "a not null" NOT NULL CONSTRAINT t_unique_1 UNIQUE, b INT NOT NULL CONSTRAINT b_check CHECK (b > 0) CHECK (b > 1), CONSTRAINT pk PRIMARY KEY (b), CONSTRAINT fk FOREIGN KEY (a) REFERENCES t (b));
/* out */
/* in */
SELECT constraint_name FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" INTEGER CONSTRAINT "a not null" NOT NULL,
-- out:   "B" INTEGER NOT NULL,
-- out:   CONSTRAINT "PK" PRIMARY KEY ("B"),
-- out:   UNIQUE ("A"),
-- out:   CONSTRAINT "B_CHECK" CHECK (B > 0),
-- out:   CONSTRAINT "T_CHECK_1" CHECK (B > 1)
-- out: );
-- out: ALTER TABLE "PUBLIC"."T" ADD CONSTRAINT "FK" FOREIGN KEY ("A") REFERENCES "PUBLIC"."T" ("B");
-- CONSTRAINT_NAME: PK
-- CONSTRAINT_NAME: T_UNIQUE_1
-- CONSTRAINT_NAME: FK
-- CONSTRAINT_NAME: a not null
-- CONSTRAINT_NAME: T_NOT_NULL_2
-- CONSTRAINT_NAME: B_CHECK
-- CONSTRAINT_NAME: T_CHECK_1
