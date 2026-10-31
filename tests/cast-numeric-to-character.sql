-- # A negative number is cast with a leading minus sign. A CHAR is padded with
-- # spaces, and both CHAR and VARCHAR raise an error (22001) when it's too long.

/* types */
VALUES CAST(-12 AS CHARACTER(5));
-- COL1: -12   (CHARACTER(5))

/* types */
VALUES CAST(-1.25 AS CHARACTER(5));
-- COL1: -1.25 (CHARACTER(5))

VALUES CAST(-1.25 AS CHARACTER(4));
-- error 22001: string data right truncation for CHARACTER(4)

/* types */
VALUES CAST(-12 AS VARCHAR(5));
-- COL1: -12 (CHARACTER VARYING(5))

VALUES CAST(-12 AS VARCHAR(2));
-- error 22001: string data right truncation for CHARACTER VARYING(2)

/* types */
VALUES CAST(1.5e0 AS CHARACTER(10));
-- COL1: 1.5e0      (CHARACTER(10))

/* types */
VALUES CAST(-1.5e0 AS CHARACTER(10));
-- COL1: -1.5e0     (CHARACTER(10))

/* types */
VALUES CAST(-1.5e0 AS CHARACTER(6));
-- COL1: -1.5e0 (CHARACTER(6))

VALUES CAST(-1.5e0 AS CHARACTER(2));
-- error 22001: string data right truncation for CHARACTER(2)

/* types */
VALUES CAST(1.5e0 AS VARCHAR(10));
-- COL1: 1.5e0 (CHARACTER VARYING(10))

/* types */
VALUES CAST(-1.5e0 AS VARCHAR(10));
-- COL1: -1.5e0 (CHARACTER VARYING(10))

VALUES CAST(-1.5e0 AS VARCHAR(2));
-- error 22001: string data right truncation for CHARACTER VARYING(2)
