PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;

-- The sequence "foo_used" is left out, its next value is 11.

CREATE TABLE "foo_child" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  "pid" INTEGER DEFAULT 1,
  "Mixed Case" CHARACTER VARYING(20),
  "order" INTEGER,
  CONSTRAINT "fk1" FOREIGN KEY ("pid") REFERENCES "foo_parent" ("id") ON DELETE CASCADE,
  CONSTRAINT "fk2" FOREIGN KEY ("pid") REFERENCES "foo_parent" ("id") ON UPDATE SET DEFAULT ON DELETE SET DEFAULT,
  CHECK ("order" > 0)
);
INSERT INTO "foo_child" ("id", "pid", "Mixed Case", "order") VALUES (1, 1, 'x', 3);
INSERT INTO "foo_child" ("id", "pid", "Mixed Case", "order") VALUES (2, NULL, NULL, 4);
DELETE FROM sqlite_sequence WHERE name = 'foo_child';
INSERT INTO sqlite_sequence (name, seq) VALUES ('foo_child', 2);

CREATE TABLE "foo_parent" (
  "id" INTEGER NOT NULL,
  "name" CHARACTER VARYING(20) DEFAULT 'it''s',
  "note" CHARACTER VARYING(20) DEFAULT 'a\b',
  CONSTRAINT "parent_pk" PRIMARY KEY ("id"),
  CONSTRAINT "uq1" UNIQUE ("name"),
  CONSTRAINT "parent_unique_1" UNIQUE ("note")
);
INSERT INTO "foo_parent" ("id", "name", "note") VALUES (1, 'a\b''c', NULL);

-- The sequence "fresh" is left out, its next value is 100.

-- The sequence "moved" is left out, its next value is 50.

-- The identity column "id" is a normal column.
CREATE TABLE "decimal_identity" (
  "id" DECIMAL(10) NOT NULL
);
INSERT INTO "decimal_identity" ("id") VALUES (1);

-- The identity column "id" is a normal column.
CREATE TABLE "descending_identity" (
  "id" INTEGER NOT NULL,
  "x" INTEGER
);
INSERT INTO "descending_identity" ("id", "x") VALUES (-1, 1);

CREATE TABLE "no_rows" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
);

-- The identity column "i" is a normal column.
-- The generated column "g2" is a normal column: CAST(SI AS INTEGER) / 2
-- The DEFAULT of "cat" is left out: CURRENT_CATALOG
-- The DEFAULT of "sch" is left out: CURRENT_SCHEMA
-- A CHECK is left out: CHAR_LENGTH(C) > 0
CREATE TABLE "types" (
  "i" INTEGER NOT NULL,
  "b" BOOLEAN DEFAULT TRUE,
  "si" SMALLINT DEFAULT NULL,
  "bi" BIGINT,
  "r" REAL,
  "d" DOUBLE PRECISION,
  "c" CHARACTER(5),
  "c2" CHARACTER(300),
  "vc" CHARACTER VARYING(10),
  "lv" CHARACTER VARYING(5000),
  "de" DECIMAL(10, 2),
  "n" NUMERIC,
  "dt" DATE DEFAULT CURRENT_DATE,
  "t" TIME DEFAULT CURRENT_TIME,
  "tz" TIME,
  "ts" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  "tstz" TIMESTAMP,
  "g" INTEGER GENERATED ALWAYS AS ("si" + 1) STORED,
  "g2" INTEGER,
  "cat" CHARACTER VARYING(128),
  "sch" CHARACTER VARYING(128),
  CHECK ("si" BETWEEN 0 AND 100),
  CONSTRAINT "upper_vc" CHECK (UPPER("vc") = "vc" OR "vc" IS NULL),
  CONSTRAINT "types_check_3" CHECK ("vc" <> 'a\b' AND "d" < 1.5e+10)
);
INSERT INTO "types" ("i", "b", "si", "bi", "r", "d", "c", "c2", "vc", "lv", "de", "n", "dt", "t", "tz", "ts", "tstz", "g2", "cat", "sch") VALUES (1, TRUE, 7, 9000000000, 1.5e0, 2.25e0, 'ab   ', 'cd                                                                                                                                                                                                                                                                                                          ', 'XY', 'long', 12.50, 3, '2022-06-30', '12:34:56', '12:34:56.123+05:00', '2022-06-30 12:34:56.123', '2022-06-30 12:34:56.123456+05:00', 3, 'db', 'PUBLIC');
INSERT INTO "types" ("i", "b", "si", "bi", "r", "d", "c", "c2", "vc", "lv", "de", "n", "dt", "t", "tz", "ts", "tstz", "g2", "cat", "sch") VALUES (2, FALSE, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2000-01-01', '00:00:00', NULL, '2000-01-01 00:00:00.000', NULL, NULL, 'db', 'PUBLIC');

-- The identity column "id" is a normal column.
CREATE TABLE "unique_identity" (
  "id" INTEGER NOT NULL,
  "x" INTEGER,
  UNIQUE ("id")
);
INSERT INTO "unique_identity" ("id", "x") VALUES (1, 1);

COMMIT;
