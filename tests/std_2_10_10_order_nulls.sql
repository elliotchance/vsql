/* setup */
CREATE TABLE bar (x FLOAT);
INSERT INTO bar (x) VALUES (4.567);
INSERT INTO bar (x) VALUES (NULL);
INSERT INTO bar (x) VALUES (1.234);
INSERT INTO bar (x) VALUES (NULL);

-- # NULLs are equal to each other (General Rules, 1.e.ii.1) and come before
-- # every other value, so they're first in ascending order and last in
-- # descending order. Where they go is implementation-defined (Syntax Rules,
-- # 3).
SELECT * FROM bar ORDER BY x;
-- X: NULL
-- X: NULL
-- X: 1.234e0
-- X: 4.567e0

SELECT * FROM bar ORDER BY x DESC;
-- X: 4.567e0
-- X: 1.234e0
-- X: NULL
-- X: NULL
