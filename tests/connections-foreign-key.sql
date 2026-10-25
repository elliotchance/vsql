/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
INSERT INTO parent (id) VALUES (1);
START TRANSACTION;
CREATE TABLE child (parent_id INT REFERENCES parent);
INSERT INTO child (parent_id) VALUES (1);
/* connection 2 */
DELETE FROM parent WHERE id = 1;
UPDATE parent SET id = 2;
INSERT INTO parent (id) VALUES (3);
/* connection 1 */
COMMIT;
SELECT * FROM parent;
SELECT * FROM child;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: avoiding concurrent write on referencing table definition
-- 2: error 40001: serialization failure: avoiding concurrent write on referencing table definition
-- 2: msg: INSERT 1
-- 1: msg: COMMIT
-- 1: ID: 1
-- 1: ID: 3
-- 1: PARENT_ID: 1

/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
INSERT INTO parent (id) VALUES (1);
/* connection 2 */
START TRANSACTION;
DELETE FROM parent WHERE id = 1;
/* connection 1 */
CREATE TABLE child (parent_id INT REFERENCES parent);
/* connection 2 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: DELETE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on table definition
-- 2: msg: COMMIT

/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
INSERT INTO parent (id) VALUES (1);
CREATE TABLE child (parent_id INT);
INSERT INTO child (parent_id) VALUES (1);
START TRANSACTION;
ALTER TABLE child ADD CONSTRAINT fk FOREIGN KEY (parent_id) REFERENCES parent;
/* connection 2 */
UPDATE parent SET id = 2;
/* connection 1 */
COMMIT;
SELECT * FROM parent;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: ALTER TABLE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on referencing table definition
-- 1: msg: COMMIT
-- 1: ID: 1

/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (a INT);
START TRANSACTION;
ALTER TABLE child ADD COLUMN parent_id INT REFERENCES parent;
/* connection 2 */
DROP TABLE parent;
/* connection 1 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: ALTER TABLE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on referencing table definition
-- 1: msg: COMMIT

/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
/* connection 2 */
START TRANSACTION;
INSERT INTO parent (id) VALUES (1);
/* connection 1 */
ALTER TABLE child ADD COLUMN a INT;
/* connection 2 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: msg: ALTER TABLE 1
-- 2: msg: COMMIT
