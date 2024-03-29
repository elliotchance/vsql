/* types */
VALUES CURRENT_DATE;
-- COL1: 2022-07-04 (DATE)

/* types */
VALUES CURRENT_TIME;
-- COL1: 14:05:03+0500 (TIME(0) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIME(0);
-- COL1: 14:05:03+0500 (TIME(0) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIME(1);
-- COL1: 14:05:03.1+0500 (TIME(1) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIME(2);
-- COL1: 14:05:03.12+0500 (TIME(2) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIME(3);
-- COL1: 14:05:03.120+0500 (TIME(3) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIME(4);
-- COL1: 14:05:03.1200+0500 (TIME(4) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIME(5);
-- COL1: 14:05:03.12005+0500 (TIME(5) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIME(6);
-- COL1: 14:05:03.120056+0500 (TIME(6) WITH TIME ZONE)

VALUES CURRENT_TIME(7);
-- error 42601: syntax error: CURRENT_TIME(7): cannot have precision greater than 6

/* types */
VALUES CURRENT_TIMESTAMP;
-- COL1: 2022-07-04T14:05:03.120056+0500 (TIMESTAMP(6) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIMESTAMP(0);
-- COL1: 2022-07-04T14:05:03+0500 (TIMESTAMP(0) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIMESTAMP(1);
-- COL1: 2022-07-04T14:05:03.1+0500 (TIMESTAMP(1) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIMESTAMP(2);
-- COL1: 2022-07-04T14:05:03.12+0500 (TIMESTAMP(2) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIMESTAMP(3);
-- COL1: 2022-07-04T14:05:03.120+0500 (TIMESTAMP(3) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIMESTAMP(4);
-- COL1: 2022-07-04T14:05:03.1200+0500 (TIMESTAMP(4) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIMESTAMP(5);
-- COL1: 2022-07-04T14:05:03.12005+0500 (TIMESTAMP(5) WITH TIME ZONE)

/* types */
VALUES CURRENT_TIMESTAMP(6);
-- COL1: 2022-07-04T14:05:03.120056+0500 (TIMESTAMP(6) WITH TIME ZONE)

VALUES CURRENT_TIMESTAMP(7);
-- error 42601: syntax error: CURRENT_TIMESTAMP(7): cannot have precision greater than 6

/* types */
VALUES LOCALTIME;
-- COL1: 14:05:03 (TIME(0) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIME(0);
-- COL1: 14:05:03 (TIME(0) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIME(1);
-- COL1: 14:05:03.1 (TIME(1) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIME(2);
-- COL1: 14:05:03.12 (TIME(2) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIME(3);
-- COL1: 14:05:03.120 (TIME(3) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIME(4);
-- COL1: 14:05:03.1200 (TIME(4) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIME(5);
-- COL1: 14:05:03.12005 (TIME(5) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIME(6);
-- COL1: 14:05:03.120056 (TIME(6) WITHOUT TIME ZONE)

VALUES LOCALTIME(7);
-- error 42601: syntax error: LOCALTIME(7): cannot have precision greater than 6

/* types */
VALUES LOCALTIMESTAMP;
-- COL1: 2022-07-04T14:05:03.120056 (TIMESTAMP(6) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIMESTAMP(0);
-- COL1: 2022-07-04T14:05:03 (TIMESTAMP(0) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIMESTAMP(1);
-- COL1: 2022-07-04T14:05:03.1 (TIMESTAMP(1) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIMESTAMP(2);
-- COL1: 2022-07-04T14:05:03.12 (TIMESTAMP(2) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIMESTAMP(3);
-- COL1: 2022-07-04T14:05:03.120 (TIMESTAMP(3) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIMESTAMP(4);
-- COL1: 2022-07-04T14:05:03.1200 (TIMESTAMP(4) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIMESTAMP(5);
-- COL1: 2022-07-04T14:05:03.12005 (TIMESTAMP(5) WITHOUT TIME ZONE)

/* types */
VALUES LOCALTIMESTAMP(6);
-- COL1: 2022-07-04T14:05:03.120056 (TIMESTAMP(6) WITHOUT TIME ZONE)

VALUES LOCALTIMESTAMP(7);
-- error 42601: syntax error: LOCALTIMESTAMP(7): cannot have precision greater than 6
