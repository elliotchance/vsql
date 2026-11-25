-- # VACUUM (V004-01) can be ON some objects: ALL (the default, every catalog),
-- # CATALOG, SCHEMA, TABLE (with its indexes and large objects, unless they're
-- # WITHOUT) and INDEX. Only the pages of their objects are packed, but the
-- # file is always shrunk.

/* setup */
CREATE TABLE a (id INT PRIMARY KEY, v VARCHAR(50) CONSTRAINT a_v UNIQUE, c CLOB);
CREATE TABLE b (id INT PRIMARY KEY, v VARCHAR(50) CONSTRAINT b_v UNIQUE, c CLOB);
CREATE SCHEMA s2;
CREATE TABLE s2.d (id INT PRIMARY KEY, v VARCHAR(50));
INSERT INTO a (id, v) VALUES (1, 'av1'), (2, 'avv2'), (3, 'avvv3'), (4, 'avvvv4'), (5, 'avvvvv5'), (6, 'avvvvvv6'), (7, 'avvvvvvv7'), (8, 'avvvvvvvv8'), (9, 'avvvvvvvvv9'), (10, 'avvvvvvvvvv10'), (11, 'avvvvvvvvvvv11'), (12, 'avvvvvvvvvvvv12'), (13, 'avvvvvvvvvvvvv13'), (14, 'avvvvvvvvvvvvvv14'), (15, 'avvvvvvvvvvvvvvv15'), (16, 'avvvvvvvvvvvvvvvv16'), (17, 'avvvvvvvvvvvvvvvvv17'), (18, 'avvvvvvvvvvvvvvvvvv18'), (19, 'avvvvvvvvvvvvvvvvvvv19'), (20, 'avvvvvvvvvvvvvvvvvvvv20'), (21, 'avvvvvvvvvvvvvvvvvvvvv21'), (22, 'avvvvvvvvvvvvvvvvvvvvvv22'), (23, 'avvvvvvvvvvvvvvvvvvvvvvv23'), (24, 'avvvvvvvvvvvvvvvvvvvvvvvv24'), (25, 'avvvvvvvvvvvvvvvvvvvvvvvvv25'), (26, 'avvvvvvvvvvvvvvvvvvvvvvvvvv26'), (27, 'avvvvvvvvvvvvvvvvvvvvvvvvvvv27'), (28, 'avvvvvvvvvvvvvvvvvvvvvvvvvvvv28'), (29, 'avvvvvvvvvvvvvvvvvvvvvvvvvvvvv29'), (30, 'a30'), (31, 'av31'), (32, 'avv32'), (33, 'avvv33'), (34, 'avvvv34'), (35, 'avvvvv35'), (36, 'avvvvvv36'), (37, 'avvvvvvv37'), (38, 'avvvvvvvv38'), (39, 'avvvvvvvvv39'), (40, 'avvvvvvvvvv40'), (41, 'avvvvvvvvvvv41'), (42, 'avvvvvvvvvvvv42'), (43, 'avvvvvvvvvvvvv43'), (44, 'avvvvvvvvvvvvvv44'), (45, 'avvvvvvvvvvvvvvv45'), (46, 'avvvvvvvvvvvvvvvv46'), (47, 'avvvvvvvvvvvvvvvvv47'), (48, 'avvvvvvvvvvvvvvvvvv48'), (49, 'avvvvvvvvvvvvvvvvvvv49'), (50, 'avvvvvvvvvvvvvvvvvvvv50'), (51, 'avvvvvvvvvvvvvvvvvvvvv51'), (52, 'avvvvvvvvvvvvvvvvvvvvvv52'), (53, 'avvvvvvvvvvvvvvvvvvvvvvv53'), (54, 'avvvvvvvvvvvvvvvvvvvvvvvv54'), (55, 'avvvvvvvvvvvvvvvvvvvvvvvvv55'), (56, 'avvvvvvvvvvvvvvvvvvvvvvvvvv56'), (57, 'avvvvvvvvvvvvvvvvvvvvvvvvvvv57'), (58, 'avvvvvvvvvvvvvvvvvvvvvvvvvvvv58'), (59, 'avvvvvvvvvvvvvvvvvvvvvvvvvvvvv59'), (60, 'a60'), (61, 'av61'), (62, 'avv62'), (63, 'avvv63'), (64, 'avvvv64'), (65, 'avvvvv65'), (66, 'avvvvvv66'), (67, 'avvvvvvv67'), (68, 'avvvvvvvv68'), (69, 'avvvvvvvvv69'), (70, 'avvvvvvvvvv70'), (71, 'avvvvvvvvvvv71'), (72, 'avvvvvvvvvvvv72'), (73, 'avvvvvvvvvvvvv73'), (74, 'avvvvvvvvvvvvvv74'), (75, 'avvvvvvvvvvvvvvv75'), (76, 'avvvvvvvvvvvvvvvv76'), (77, 'avvvvvvvvvvvvvvvvv77'), (78, 'avvvvvvvvvvvvvvvvvv78'), (79, 'avvvvvvvvvvvvvvvvvvv79'), (80, 'avvvvvvvvvvvvvvvvvvvv80'), (81, 'avvvvvvvvvvvvvvvvvvvvv81'), (82, 'avvvvvvvvvvvvvvvvvvvvvv82'), (83, 'avvvvvvvvvvvvvvvvvvvvvvv83'), (84, 'avvvvvvvvvvvvvvvvvvvvvvvv84'), (85, 'avvvvvvvvvvvvvvvvvvvvvvvvv85'), (86, 'avvvvvvvvvvvvvvvvvvvvvvvvvv86'), (87, 'avvvvvvvvvvvvvvvvvvvvvvvvvvv87'), (88, 'avvvvvvvvvvvvvvvvvvvvvvvvvvvv88'), (89, 'avvvvvvvvvvvvvvvvvvvvvvvvvvvvv89'), (90, 'a90');
INSERT INTO b (id, v) VALUES (1, 'bv1'), (2, 'bvv2'), (3, 'bvvv3'), (4, 'bvvvv4'), (5, 'bvvvvv5'), (6, 'bvvvvvv6'), (7, 'bvvvvvvv7'), (8, 'bvvvvvvvv8'), (9, 'bvvvvvvvvv9'), (10, 'bvvvvvvvvvv10'), (11, 'bvvvvvvvvvvv11'), (12, 'bvvvvvvvvvvvv12'), (13, 'bvvvvvvvvvvvvv13'), (14, 'bvvvvvvvvvvvvvv14'), (15, 'bvvvvvvvvvvvvvvv15'), (16, 'bvvvvvvvvvvvvvvvv16'), (17, 'bvvvvvvvvvvvvvvvvv17'), (18, 'bvvvvvvvvvvvvvvvvvv18'), (19, 'bvvvvvvvvvvvvvvvvvvv19'), (20, 'bvvvvvvvvvvvvvvvvvvvv20'), (21, 'bvvvvvvvvvvvvvvvvvvvvv21'), (22, 'bvvvvvvvvvvvvvvvvvvvvvv22'), (23, 'bvvvvvvvvvvvvvvvvvvvvvvv23'), (24, 'bvvvvvvvvvvvvvvvvvvvvvvvv24'), (25, 'bvvvvvvvvvvvvvvvvvvvvvvvvv25'), (26, 'bvvvvvvvvvvvvvvvvvvvvvvvvvv26'), (27, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvv27'), (28, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvvv28'), (29, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvvvv29'), (30, 'b30'), (31, 'bv31'), (32, 'bvv32'), (33, 'bvvv33'), (34, 'bvvvv34'), (35, 'bvvvvv35'), (36, 'bvvvvvv36'), (37, 'bvvvvvvv37'), (38, 'bvvvvvvvv38'), (39, 'bvvvvvvvvv39'), (40, 'bvvvvvvvvvv40'), (41, 'bvvvvvvvvvvv41'), (42, 'bvvvvvvvvvvvv42'), (43, 'bvvvvvvvvvvvvv43'), (44, 'bvvvvvvvvvvvvvv44'), (45, 'bvvvvvvvvvvvvvvv45'), (46, 'bvvvvvvvvvvvvvvvv46'), (47, 'bvvvvvvvvvvvvvvvvv47'), (48, 'bvvvvvvvvvvvvvvvvvv48'), (49, 'bvvvvvvvvvvvvvvvvvvv49'), (50, 'bvvvvvvvvvvvvvvvvvvvv50'), (51, 'bvvvvvvvvvvvvvvvvvvvvv51'), (52, 'bvvvvvvvvvvvvvvvvvvvvvv52'), (53, 'bvvvvvvvvvvvvvvvvvvvvvvv53'), (54, 'bvvvvvvvvvvvvvvvvvvvvvvvv54'), (55, 'bvvvvvvvvvvvvvvvvvvvvvvvvv55'), (56, 'bvvvvvvvvvvvvvvvvvvvvvvvvvv56'), (57, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvv57'), (58, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvvv58'), (59, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvvvv59'), (60, 'b60'), (61, 'bv61'), (62, 'bvv62'), (63, 'bvvv63'), (64, 'bvvvv64'), (65, 'bvvvvv65'), (66, 'bvvvvvv66'), (67, 'bvvvvvvv67'), (68, 'bvvvvvvvv68'), (69, 'bvvvvvvvvv69'), (70, 'bvvvvvvvvvv70'), (71, 'bvvvvvvvvvvv71'), (72, 'bvvvvvvvvvvvv72'), (73, 'bvvvvvvvvvvvvv73'), (74, 'bvvvvvvvvvvvvvv74'), (75, 'bvvvvvvvvvvvvvvv75'), (76, 'bvvvvvvvvvvvvvvvv76'), (77, 'bvvvvvvvvvvvvvvvvv77'), (78, 'bvvvvvvvvvvvvvvvvvv78'), (79, 'bvvvvvvvvvvvvvvvvvvv79'), (80, 'bvvvvvvvvvvvvvvvvvvvv80'), (81, 'bvvvvvvvvvvvvvvvvvvvvv81'), (82, 'bvvvvvvvvvvvvvvvvvvvvvv82'), (83, 'bvvvvvvvvvvvvvvvvvvvvvvv83'), (84, 'bvvvvvvvvvvvvvvvvvvvvvvvv84'), (85, 'bvvvvvvvvvvvvvvvvvvvvvvvvv85'), (86, 'bvvvvvvvvvvvvvvvvvvvvvvvvvv86'), (87, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvv87'), (88, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvvv88'), (89, 'bvvvvvvvvvvvvvvvvvvvvvvvvvvvvv89'), (90, 'b90');
INSERT INTO s2.d (id, v) VALUES (1, 'dv1'), (2, 'dvv2'), (3, 'dvvv3'), (4, 'dvvvv4'), (5, 'dvvvvv5'), (6, 'dvvvvvv6'), (7, 'dvvvvvvv7'), (8, 'dvvvvvvvv8'), (9, 'dvvvvvvvvv9'), (10, 'dvvvvvvvvvv10'), (11, 'dvvvvvvvvvvv11'), (12, 'dvvvvvvvvvvvv12'), (13, 'dvvvvvvvvvvvvv13'), (14, 'dvvvvvvvvvvvvvv14'), (15, 'dvvvvvvvvvvvvvvv15'), (16, 'dvvvvvvvvvvvvvvvv16'), (17, 'dvvvvvvvvvvvvvvvvv17'), (18, 'dvvvvvvvvvvvvvvvvvv18'), (19, 'dvvvvvvvvvvvvvvvvvvv19'), (20, 'dvvvvvvvvvvvvvvvvvvvv20'), (21, 'dvvvvvvvvvvvvvvvvvvvvv21'), (22, 'dvvvvvvvvvvvvvvvvvvvvvv22'), (23, 'dvvvvvvvvvvvvvvvvvvvvvvv23'), (24, 'dvvvvvvvvvvvvvvvvvvvvvvvv24'), (25, 'dvvvvvvvvvvvvvvvvvvvvvvvvv25'), (26, 'dvvvvvvvvvvvvvvvvvvvvvvvvvv26'), (27, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvv27'), (28, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvvv28'), (29, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvvvv29'), (30, 'd30'), (31, 'dv31'), (32, 'dvv32'), (33, 'dvvv33'), (34, 'dvvvv34'), (35, 'dvvvvv35'), (36, 'dvvvvvv36'), (37, 'dvvvvvvv37'), (38, 'dvvvvvvvv38'), (39, 'dvvvvvvvvv39'), (40, 'dvvvvvvvvvv40'), (41, 'dvvvvvvvvvvv41'), (42, 'dvvvvvvvvvvvv42'), (43, 'dvvvvvvvvvvvvv43'), (44, 'dvvvvvvvvvvvvvv44'), (45, 'dvvvvvvvvvvvvvvv45'), (46, 'dvvvvvvvvvvvvvvvv46'), (47, 'dvvvvvvvvvvvvvvvvv47'), (48, 'dvvvvvvvvvvvvvvvvvv48'), (49, 'dvvvvvvvvvvvvvvvvvvv49'), (50, 'dvvvvvvvvvvvvvvvvvvvv50'), (51, 'dvvvvvvvvvvvvvvvvvvvvv51'), (52, 'dvvvvvvvvvvvvvvvvvvvvvv52'), (53, 'dvvvvvvvvvvvvvvvvvvvvvvv53'), (54, 'dvvvvvvvvvvvvvvvvvvvvvvvv54'), (55, 'dvvvvvvvvvvvvvvvvvvvvvvvvv55'), (56, 'dvvvvvvvvvvvvvvvvvvvvvvvvvv56'), (57, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvv57'), (58, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvvv58'), (59, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvvvv59'), (60, 'd60'), (61, 'dv61'), (62, 'dvv62'), (63, 'dvvv63'), (64, 'dvvvv64'), (65, 'dvvvvv65'), (66, 'dvvvvvv66'), (67, 'dvvvvvvv67'), (68, 'dvvvvvvvv68'), (69, 'dvvvvvvvvv69'), (70, 'dvvvvvvvvvv70'), (71, 'dvvvvvvvvvvv71'), (72, 'dvvvvvvvvvvvv72'), (73, 'dvvvvvvvvvvvvv73'), (74, 'dvvvvvvvvvvvvvv74'), (75, 'dvvvvvvvvvvvvvvv75'), (76, 'dvvvvvvvvvvvvvvvv76'), (77, 'dvvvvvvvvvvvvvvvvv77'), (78, 'dvvvvvvvvvvvvvvvvvv78'), (79, 'dvvvvvvvvvvvvvvvvvvv79'), (80, 'dvvvvvvvvvvvvvvvvvvvv80'), (81, 'dvvvvvvvvvvvvvvvvvvvvv81'), (82, 'dvvvvvvvvvvvvvvvvvvvvvv82'), (83, 'dvvvvvvvvvvvvvvvvvvvvvvv83'), (84, 'dvvvvvvvvvvvvvvvvvvvvvvvv84'), (85, 'dvvvvvvvvvvvvvvvvvvvvvvvvv85'), (86, 'dvvvvvvvvvvvvvvvvvvvvvvvvvv86'), (87, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvv87'), (88, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvvv88'), (89, 'dvvvvvvvvvvvvvvvvvvvvvvvvvvvvv89'), (90, 'd90');
UPDATE a SET c = REPEAT('c', 500) WHERE MOD(id, 10) = 0;
UPDATE b SET c = REPEAT('c', 500) WHERE MOD(id, 10) = 0;
DELETE FROM a WHERE MOD(id, 3) <> 0;
DELETE FROM b WHERE MOD(id, 3) <> 0;
DELETE FROM s2.d WHERE MOD(id, 3) <> 0;

-- # A table includes its indexes and large objects. The other tables aren't
-- # packed.
/* extensions V004-01 */
VACUUM ON TABLE a;
SELECT * FROM vsql.last_vacuum;
VACUUM;
SELECT * FROM vsql.last_vacuum;
-- msg: VACUUM 145 130
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: TABLE PAGES_READ: 36 PAGES_FREED: 16 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A_V OBJECT_TYPE: INDEX PAGES_READ: 14 PAGES_FREED: 1 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 16 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 79 PAGES_FREED: 130 IS_FINISHED: YES
-- msg: VACUUM 172 39
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: TABLE PAGES_READ: 16 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A_V OBJECT_TYPE: INDEX PAGES_READ: 10 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 14 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: TABLE PAGES_READ: 37 PAGES_FREED: 14 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B_V OBJECT_TYPE: INDEX PAGES_READ: 15 PAGES_FREED: 4 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 12 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: S2 OBJECT_NAME: D OBJECT_TYPE: TABLE PAGES_READ: 40 PAGES_FREED: 20 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 20 PAGES_FREED: 39 IS_FINISHED: YES

-- # WITHOUT INDEXES and WITHOUT LARGE OBJECTS leave them out, in either order.
/* extensions V004-01 */
VACUUM ON TABLE b WITHOUT INDEXES;
SELECT * FROM vsql.last_vacuum;
VACUUM ON TABLE b WITHOUT LARGE OBJECTS WITHOUT INDEXES;
SELECT * FROM vsql.last_vacuum;
VACUUM ON TABLE b WITH INDEXES WITHOUT LARGE OBJECTS;
SELECT * FROM vsql.last_vacuum;
VACUUM ON TABLE b WITH LARGE OBJECTS WITH INDEXES;
-- msg: VACUUM 129 127
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: TABLE PAGES_READ: 38 PAGES_FREED: 14 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 15 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 76 PAGES_FREED: 127 IS_FINISHED: YES
-- msg: VACUUM 22 0
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: TABLE PAGES_READ: 22 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: YES
-- msg: VACUUM 42 4
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: TABLE PAGES_READ: 22 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B_V OBJECT_TYPE: INDEX PAGES_READ: 16 PAGES_FREED: 4 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 4 PAGES_FREED: 4 IS_FINISHED: YES
-- msg: VACUUM 48 0

-- # An index on its own, a schema, and more than one object.
/* extensions V004-01 */
VACUUM ON INDEX a_v;
SELECT * FROM vsql.last_vacuum;
VACUUM ON SCHEMA s2;
SELECT * FROM vsql.last_vacuum;
VACUUM ON TABLE a INDEX b_v SCHEMA s2;
VACUUM ON TABLE public.a TABLE a INDEX public.a_v;
-- msg: VACUUM 82 114
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A_V OBJECT_TYPE: INDEX PAGES_READ: 14 PAGES_FREED: 1 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 68 PAGES_FREED: 114 IS_FINISHED: YES
-- msg: VACUUM 50 20
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: S2 OBJECT_NAME: D OBJECT_TYPE: TABLE PAGES_READ: 39 PAGES_FREED: 20 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 11 PAGES_FREED: 20 IS_FINISHED: YES
-- msg: VACUUM 112 20
-- msg: VACUUM 46 0

-- # The rows are all still there, through the tables and the indexes.
/* extensions V004-01 */
VACUUM ON TABLE a;
VACUUM ON INDEX b_v;
VACUUM ON SCHEMA s2;
SELECT COUNT(*), SUM(id), SUM(CHAR_LENGTH(c)) FROM a;
SELECT COUNT(*), SUM(id) FROM a WHERE v >= '';
SELECT COUNT(*), SUM(id), SUM(CHAR_LENGTH(c)) FROM b;
SELECT COUNT(*), SUM(id) FROM b WHERE v >= '';
SELECT COUNT(*), SUM(id) FROM s2.d;
-- msg: VACUUM 145 130
-- msg: VACUUM 20 4
-- msg: VACUUM 48 20
-- warning 01003: null value eliminated in set function
-- COL1: 30 COL2: 1395 COL3: 1500
-- COL1: 30 COL2: 1395
-- warning 01003: null value eliminated in set function
-- COL1: 30 COL2: 1395 COL3: 1500
-- COL1: 30 COL2: 1395
-- COL1: 30 COL2: 1395

-- # CATALOG is every object of a catalog, and ALL (or no objects) is every
-- # catalog.
/* extensions V004-01 */
/* create_catalog FOO */
SET CATALOG 'FOO';
CREATE TABLE e (id INT PRIMARY KEY);
INSERT INTO e (id) VALUES (1), (2), (3);
SET CATALOG ':memory:';
VACUUM ON CATALOG foo;
SELECT * FROM vsql.last_vacuum;
VACUUM ON CATALOG ":memory:" FREE PAGES;
VACUUM ON ALL;
SELECT * FROM vsql.last_vacuum;
VACUUM ON TABLE foo.public.e;
SELECT * FROM vsql.last_vacuum;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: SET CATALOG 1
-- msg: VACUUM 2 0
-- OBJECT_CATALOG: FOO OBJECT_SCHEMA: PUBLIC OBJECT_NAME: E OBJECT_TYPE: TABLE PAGES_READ: 1 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: FOO OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: YES
-- msg: VACUUM 68 113
-- msg: VACUUM 204 56
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: TABLE PAGES_READ: 34 PAGES_FREED: 16 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A_V OBJECT_TYPE: INDEX PAGES_READ: 12 PAGES_FREED: 1 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 14 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: TABLE PAGES_READ: 35 PAGES_FREED: 14 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B_V OBJECT_TYPE: INDEX PAGES_READ: 15 PAGES_FREED: 4 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 12 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: S2 OBJECT_NAME: D OBJECT_TYPE: TABLE PAGES_READ: 40 PAGES_FREED: 20 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 32 PAGES_FREED: 56 IS_FINISHED: YES
-- OBJECT_CATALOG: FOO OBJECT_SCHEMA: PUBLIC OBJECT_NAME: E OBJECT_TYPE: TABLE PAGES_READ: 1 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: FOO OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: YES
-- msg: VACUUM 2 0
-- OBJECT_CATALOG: FOO OBJECT_SCHEMA: PUBLIC OBJECT_NAME: E OBJECT_TYPE: TABLE PAGES_READ: 2 PAGES_FREED: 0 IS_FINISHED: YES
-- OBJECT_CATALOG: FOO OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: YES

-- # The objects must exist.
/* extensions V004-01 */
VACUUM ON TABLE nope;
VACUUM ON INDEX nope;
VACUUM ON SCHEMA nope;
VACUUM ON CATALOG nope;
VACUUM ON TABLE nope.a;
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE
-- error 42704: no such index: ":memory:".PUBLIC.NOPE
-- error 3F000: invalid schema name: NOPE
-- error 3D000: invalid catalog name: NOPE
-- error 3F000: invalid schema name: NOPE

-- # ALL is on its own, FULL is only for whole catalogs, and INDEXES and LARGE
-- # OBJECTS can each only be given once.
VACUUM ON ALL TABLE a;
VACUUM ON TABLE a FULL;
VACUUM ON SCHEMA s2 FULL;
VACUUM ON TABLE a WITH INDEXES WITHOUT INDEXES;
VACUUM ON TABLE a WITH LARGE OBJECTS WITH LARGE OBJECTS;
-- error 42601: syntax error: VACUUM ALL can only be on its own
-- error 42601: syntax error: VACUUM FULL can only be used for ALL or a CATALOG
-- error 42601: syntax error: VACUUM FULL can only be used for ALL or a CATALOG
-- error 42601: syntax error: VACUUM TABLE can only have one of WITH INDEXES and WITHOUT INDEXES
-- error 42601: syntax error: VACUUM TABLE can only have one of WITH LARGE OBJECTS and WITHOUT LARGE OBJECTS

-- # FULL with a catalog, and TIMEOUT with objects.
/* extensions V004-01 */
VACUUM ON CATALOG ":memory:" FULL;
VACUUM ON TABLE a TABLE b TIMEOUT 0;
SELECT * FROM vsql.last_vacuum;
VACUUM ON INDEX a_v FREE PAGES;
SELECT * FROM vsql.last_vacuum;
-- msg: VACUUM 241 251
-- msg: VACUUM 0 0
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: TABLE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A_V OBJECT_TYPE: INDEX PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: A OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: TABLE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B_V OBJECT_TYPE: INDEX PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: B OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- msg: VACUUM 0 0
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: YES

-- # The words aren't reserved.
CREATE TABLE indexes (objects INT);
INSERT INTO indexes (objects) VALUES (1);
SELECT objects FROM indexes;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- OBJECTS: 1

-- # A page that can't be read fails the VACUUM, which leaves LAST_VACUUM
-- # empty.
/* extensions V004-01 */
VACUUM ON TABLE a;
/* fault read_page */
VACUUM ON TABLE a;
SELECT COUNT(*) FROM vsql.last_vacuum;
-- msg: VACUUM 145 130
-- error 58030: read_page failed (fault injected by test)
-- COL1: 0
