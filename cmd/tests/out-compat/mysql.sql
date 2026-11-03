SET SESSION sql_mode = 'ANSI_QUOTES,NO_AUTO_VALUE_ON_ZERO,PIPES_AS_CONCAT,STRICT_ALL_TABLES';
SET SESSION time_zone = '+00:00';
START TRANSACTION;

CREATE SCHEMA "foo";

-- The sequence "foo"."used" is left out, its next value is 11.

CREATE TABLE "foo"."child" (
  "id" INTEGER AUTO_INCREMENT NOT NULL,
  "pid" INTEGER DEFAULT (1),
  "Mixed Case" VARCHAR(20),
  "order" INTEGER,
  PRIMARY KEY ("id"),
  CHECK ("order" > 0)
);
INSERT INTO "foo"."child" ("id", "pid", "Mixed Case", "order") VALUES (1, 1, 'x', 3);
INSERT INTO "foo"."child" ("id", "pid", "Mixed Case", "order") VALUES (2, NULL, NULL, 4);
ALTER TABLE "foo"."child" AUTO_INCREMENT = 3;

CREATE TABLE "foo"."parent" (
  "id" INTEGER NOT NULL,
  "name" VARCHAR(20) DEFAULT ('it''s'),
  "note" VARCHAR(20) DEFAULT ('a\\b'),
  CONSTRAINT "parent_pk" PRIMARY KEY ("id"),
  CONSTRAINT "uq1" UNIQUE ("name"),
  CONSTRAINT "parent_unique_1" UNIQUE ("note")
);
INSERT INTO "foo"."parent" ("id", "name", "note") VALUES (1, 'a\\b''c', NULL);

CREATE SCHEMA "nothing";

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
  "id" BIGINT AUTO_INCREMENT NOT NULL,
  PRIMARY KEY ("id")
);

-- The generated column "g2" is a normal column: CAST(SI AS INTEGER) / 2
-- The DEFAULT of "cat" is left out: CURRENT_CATALOG
-- The DEFAULT of "sch" is left out: CURRENT_SCHEMA
-- A CHECK is left out: CHAR_LENGTH(C) > 0
CREATE TABLE "types" (
  "i" INTEGER AUTO_INCREMENT NOT NULL,
  "b" BOOLEAN DEFAULT (TRUE),
  "si" SMALLINT DEFAULT (NULL),
  "bi" BIGINT,
  "r" FLOAT,
  "d" DOUBLE PRECISION,
  "c" CHARACTER(5),
  "c2" VARCHAR(300),
  "vc" VARCHAR(10),
  "lv" LONGTEXT,
  "de" DECIMAL(10, 2),
  "n" DECIMAL(65, 30),
  "dt" DATE DEFAULT (CURRENT_DATE),
  "t" TIME(0) DEFAULT (LOCALTIME(0)),
  "tz" VARCHAR(30),
  "ts" DATETIME(3) DEFAULT (LOCALTIMESTAMP(3)),
  "tstz" DATETIME(6),
  "g" INTEGER GENERATED ALWAYS AS ("si" + 1) STORED,
  "g2" INTEGER,
  "cat" VARCHAR(128),
  "sch" VARCHAR(128),
  KEY ("i"),
  CHECK ("si" BETWEEN 0 AND 100),
  CONSTRAINT "upper_vc" CHECK (UPPER("vc") = "vc" OR "vc" IS NULL),
  CONSTRAINT "types_check_3" CHECK ("vc" <> 'a\\b' AND "d" < 1.5e+10)
);
INSERT INTO "types" ("i", "b", "si", "bi", "r", "d", "c", "c2", "vc", "lv", "de", "n", "dt", "t", "tz", "ts", "tstz", "g2", "cat", "sch") VALUES (1, TRUE, 7, 9000000000, 1.5e0, 2.25e0, 'ab   ', 'cd                                                                                                                                                                                                                                                                                                          ', 'XY', 'long', 12.50, 3, '2022-06-30', '12:34:56', '12:34:56.123+05:00', '2022-06-30 12:34:56.123', '2022-06-30 12:34:56.123456+05:00', 3, 'db', 'PUBLIC');
INSERT INTO "types" ("i", "b", "si", "bi", "r", "d", "c", "c2", "vc", "lv", "de", "n", "dt", "t", "tz", "ts", "tstz", "g2", "cat", "sch") VALUES (2, FALSE, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2000-01-01', '00:00:00', NULL, '2000-01-01 00:00:00.000', NULL, NULL, 'db', 'PUBLIC');
ALTER TABLE "types" AUTO_INCREMENT = 3;

CREATE TABLE "unique_identity" (
  "id" INTEGER AUTO_INCREMENT NOT NULL,
  "x" INTEGER,
  UNIQUE ("id")
);
INSERT INTO "unique_identity" ("id", "x") VALUES (1, 1);
ALTER TABLE "unique_identity" AUTO_INCREMENT = 2;

ALTER TABLE "foo"."child" ADD CONSTRAINT "fk1" FOREIGN KEY ("pid") REFERENCES "foo"."parent" ("id") ON DELETE CASCADE;
ALTER TABLE "foo"."child" ADD CONSTRAINT "fk2" FOREIGN KEY ("pid") REFERENCES "foo"."parent" ("id");

COMMIT;
