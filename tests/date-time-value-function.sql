VALUES CURRENT_DATE;
-- COL1: 2022-07-04

VALUES CURRENT_TIME;
-- COL1: 14:05:03+0500

VALUES CURRENT_TIME(0);
-- COL1: 14:05:03+0500

VALUES CURRENT_TIME(1);
-- COL1: 14:05:03.1+0500

VALUES CURRENT_TIME(2);
-- COL1: 14:05:03.12+0500

VALUES CURRENT_TIME(3);
-- COL1: 14:05:03.120+0500

VALUES CURRENT_TIME(4);
-- COL1: 14:05:03.1200+0500

VALUES CURRENT_TIME(5);
-- COL1: 14:05:03.12005+0500

VALUES CURRENT_TIME(6);
-- COL1: 14:05:03.120056+0500

VALUES CURRENT_TIME(7);
-- error 42601: syntax error: CURRENT_TIME(7): cannot have precision greater than 6

VALUES CURRENT_TIMESTAMP;
-- COL1: 2022-07-04T14:05:03.120056+0500

VALUES CURRENT_TIMESTAMP(0);
-- COL1: 2022-07-04T14:05:03+0500

VALUES CURRENT_TIMESTAMP(1);
-- COL1: 2022-07-04T14:05:03.1+0500

VALUES CURRENT_TIMESTAMP(2);
-- COL1: 2022-07-04T14:05:03.12+0500

VALUES CURRENT_TIMESTAMP(3);
-- COL1: 2022-07-04T14:05:03.120+0500

VALUES CURRENT_TIMESTAMP(4);
-- COL1: 2022-07-04T14:05:03.1200+0500

VALUES CURRENT_TIMESTAMP(5);
-- COL1: 2022-07-04T14:05:03.12005+0500

VALUES CURRENT_TIMESTAMP(6);
-- COL1: 2022-07-04T14:05:03.120056+0500

VALUES CURRENT_TIMESTAMP(7);
-- error 42601: syntax error: CURRENT_TIMESTAMP(7): cannot have precision greater than 6

VALUES LOCALTIME;
-- COL1: 14:05:03

VALUES LOCALTIME(0);
-- COL1: 14:05:03

VALUES LOCALTIME(1);
-- COL1: 14:05:03.1

VALUES LOCALTIME(2);
-- COL1: 14:05:03.12

VALUES LOCALTIME(3);
-- COL1: 14:05:03.120

VALUES LOCALTIME(4);
-- COL1: 14:05:03.1200

VALUES LOCALTIME(5);
-- COL1: 14:05:03.12005

VALUES LOCALTIME(6);
-- COL1: 14:05:03.120056

VALUES LOCALTIME(7);
-- error 42601: syntax error: LOCALTIME(7): cannot have precision greater than 6

VALUES LOCALTIMESTAMP;
-- COL1: 2022-07-04T14:05:03.120056

VALUES LOCALTIMESTAMP(0);
-- COL1: 2022-07-04T14:05:03

VALUES LOCALTIMESTAMP(1);
-- COL1: 2022-07-04T14:05:03.1

VALUES LOCALTIMESTAMP(2);
-- COL1: 2022-07-04T14:05:03.12

VALUES LOCALTIMESTAMP(3);
-- COL1: 2022-07-04T14:05:03.120

VALUES LOCALTIMESTAMP(4);
-- COL1: 2022-07-04T14:05:03.1200

VALUES LOCALTIMESTAMP(5);
-- COL1: 2022-07-04T14:05:03.12005

VALUES LOCALTIMESTAMP(6);
-- COL1: 2022-07-04T14:05:03.120056

VALUES LOCALTIMESTAMP(7);
-- error 42601: syntax error: LOCALTIMESTAMP(7): cannot have precision greater than 6
