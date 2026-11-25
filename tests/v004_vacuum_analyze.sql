-- # VACUUM ANALYZE (V004-01) finds out how much of the file each table and
-- # index takes, and what each mode of VACUUM would leave, without changing
-- # anything. It's in VSQL.LAST_VACUUM_ANALYZE (V004-03).

/* setup */
CREATE TABLE t (k VARCHAR(20) PRIMARY KEY, n INT, v VARCHAR(50) UNIQUE, c CLOB);
INSERT INTO t (k, n, v) VALUES ('kk1', 1, 'v1'), ('kkk2', 2, 'vv2'), ('kkkk3', 3, 'vvv3'), ('kkkkk4', 4, 'vvvv4'), ('kkkkkk5', 5, 'vvvvv5'), ('kkkkkkk6', 6, 'vvvvvv6'), ('kkkkkkkk7', 7, 'vvvvvvv7'), ('kkkkkkkkk8', 8, 'vvvvvvvv8'), ('k9', 9, 'vvvvvvvvv9'), ('kk10', 10, 'vvvvvvvvvv10'), ('kkk11', 11, 'vvvvvvvvvvv11'), ('kkkk12', 12, 'vvvvvvvvvvvv12'), ('kkkkk13', 13, 'vvvvvvvvvvvvv13'), ('kkkkkk14', 14, 'vvvvvvvvvvvvvv14'), ('kkkkkkk15', 15, 'vvvvvvvvvvvvvvv15'), ('kkkkkkkk16', 16, 'vvvvvvvvvvvvvvvv16'), ('kkkkkkkkk17', 17, 'vvvvvvvvvvvvvvvvv17'), ('k18', 18, 'vvvvvvvvvvvvvvvvvv18'), ('kk19', 19, 'vvvvvvvvvvvvvvvvvvv19'), ('kkk20', 20, 'vvvvvvvvvvvvvvvvvvvv20'), ('kkkk21', 21, 'vvvvvvvvvvvvvvvvvvvvv21'), ('kkkkk22', 22, 'vvvvvvvvvvvvvvvvvvvvvv22'), ('kkkkkk23', 23, 'vvvvvvvvvvvvvvvvvvvvvvv23'), ('kkkkkkk24', 24, 'vvvvvvvvvvvvvvvvvvvvvvvv24'), ('kkkkkkkk25', 25, 'vvvvvvvvvvvvvvvvvvvvvvvvv25'), ('kkkkkkkkk26', 26, 'vvvvvvvvvvvvvvvvvvvvvvvvvv26'), ('k27', 27, 'vvvvvvvvvvvvvvvvvvvvvvvvvvv27'), ('kk28', 28, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvv28'), ('kkk29', 29, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvv29'), ('kkkk30', 30, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv30'), ('kkkkk31', 31, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv31'), ('kkkkkk32', 32, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv32'), ('kkkkkkk33', 33, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv33'), ('kkkkkkkk34', 34, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv34'), ('kkkkkkkkk35', 35, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv35'), ('k36', 36, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv36'), ('kk37', 37, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv37'), ('kkk38', 38, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv38'), ('kkkk39', 39, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv39'), ('kkkkk40', 40, '40'), ('kkkkkk41', 41, 'v41'), ('kkkkkkk42', 42, 'vv42'), ('kkkkkkkk43', 43, 'vvv43'), ('kkkkkkkkk44', 44, 'vvvv44'), ('k45', 45, 'vvvvv45'), ('kk46', 46, 'vvvvvv46'), ('kkk47', 47, 'vvvvvvv47'), ('kkkk48', 48, 'vvvvvvvv48'), ('kkkkk49', 49, 'vvvvvvvvv49'), ('kkkkkk50', 50, 'vvvvvvvvvv50'), ('kkkkkkk51', 51, 'vvvvvvvvvvv51'), ('kkkkkkkk52', 52, 'vvvvvvvvvvvv52'), ('kkkkkkkkk53', 53, 'vvvvvvvvvvvvv53'), ('k54', 54, 'vvvvvvvvvvvvvv54'), ('kk55', 55, 'vvvvvvvvvvvvvvv55'), ('kkk56', 56, 'vvvvvvvvvvvvvvvv56'), ('kkkk57', 57, 'vvvvvvvvvvvvvvvvv57'), ('kkkkk58', 58, 'vvvvvvvvvvvvvvvvvv58'), ('kkkkkk59', 59, 'vvvvvvvvvvvvvvvvvvv59'), ('kkkkkkk60', 60, 'vvvvvvvvvvvvvvvvvvvv60'), ('kkkkkkkk61', 61, 'vvvvvvvvvvvvvvvvvvvvv61'), ('kkkkkkkkk62', 62, 'vvvvvvvvvvvvvvvvvvvvvv62'), ('k63', 63, 'vvvvvvvvvvvvvvvvvvvvvvv63'), ('kk64', 64, 'vvvvvvvvvvvvvvvvvvvvvvvv64'), ('kkk65', 65, 'vvvvvvvvvvvvvvvvvvvvvvvvv65'), ('kkkk66', 66, 'vvvvvvvvvvvvvvvvvvvvvvvvvv66'), ('kkkkk67', 67, 'vvvvvvvvvvvvvvvvvvvvvvvvvvv67'), ('kkkkkk68', 68, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvv68'), ('kkkkkkk69', 69, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvv69'), ('kkkkkkkk70', 70, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv70'), ('kkkkkkkkk71', 71, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv71'), ('k72', 72, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv72'), ('kk73', 73, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv73'), ('kkk74', 74, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv74'), ('kkkk75', 75, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv75'), ('kkkkk76', 76, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv76'), ('kkkkkk77', 77, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv77'), ('kkkkkkk78', 78, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv78'), ('kkkkkkkk79', 79, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv79'), ('kkkkkkkkk80', 80, '80'), ('k81', 81, 'v81'), ('kk82', 82, 'vv82'), ('kkk83', 83, 'vvv83'), ('kkkk84', 84, 'vvvv84'), ('kkkkk85', 85, 'vvvvv85'), ('kkkkkk86', 86, 'vvvvvv86'), ('kkkkkkk87', 87, 'vvvvvvv87'), ('kkkkkkkk88', 88, 'vvvvvvvv88'), ('kkkkkkkkk89', 89, 'vvvvvvvvv89'), ('k90', 90, 'vvvvvvvvvv90'), ('kk91', 91, 'vvvvvvvvvvv91'), ('kkk92', 92, 'vvvvvvvvvvvv92'), ('kkkk93', 93, 'vvvvvvvvvvvvv93'), ('kkkkk94', 94, 'vvvvvvvvvvvvvv94'), ('kkkkkk95', 95, 'vvvvvvvvvvvvvvv95'), ('kkkkkkk96', 96, 'vvvvvvvvvvvvvvvv96'), ('kkkkkkkk97', 97, 'vvvvvvvvvvvvvvvvv97'), ('kkkkkkkkk98', 98, 'vvvvvvvvvvvvvvvvvv98'), ('k99', 99, 'vvvvvvvvvvvvvvvvvvv99'), ('kk100', 100, 'vvvvvvvvvvvvvvvvvvvv100'), ('kkk101', 101, 'vvvvvvvvvvvvvvvvvvvvv101'), ('kkkk102', 102, 'vvvvvvvvvvvvvvvvvvvvvv102'), ('kkkkk103', 103, 'vvvvvvvvvvvvvvvvvvvvvvv103'), ('kkkkkk104', 104, 'vvvvvvvvvvvvvvvvvvvvvvvv104'), ('kkkkkkk105', 105, 'vvvvvvvvvvvvvvvvvvvvvvvvv105'), ('kkkkkkkk106', 106, 'vvvvvvvvvvvvvvvvvvvvvvvvvv106'), ('kkkkkkkkk107', 107, 'vvvvvvvvvvvvvvvvvvvvvvvvvvv107'), ('k108', 108, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvv108'), ('kk109', 109, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvv109'), ('kkk110', 110, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv110'), ('kkkk111', 111, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv111'), ('kkkkk112', 112, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv112'), ('kkkkkk113', 113, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv113'), ('kkkkkkk114', 114, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv114'), ('kkkkkkkk115', 115, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv115'), ('kkkkkkkkk116', 116, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv116'), ('k117', 117, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv117'), ('kk118', 118, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv118'), ('kkk119', 119, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv119'), ('kkkk120', 120, '120');
UPDATE t SET c = REPEAT('c', 600) WHERE MOD(n, 10) = 0;
DELETE FROM t WHERE MOD(n, 3) <> 0;
DELETE FROM t WHERE n <= 30;

-- # The size of each object, and of the file.
/* extensions V004-01 */
SELECT COUNT(*) FROM vsql.last_vacuum_analyze;
VACUUM ANALYZE;
SELECT object_schema, object_name, object_type, page_size, pages, total_bytes, used_bytes, versions, expired_versions, internal_pages, free_pages FROM vsql.last_vacuum_analyze;
-- COL1: 0
-- msg: VACUUM ANALYZE 69
-- OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T OBJECT_TYPE: TABLE PAGE_SIZE: 256 PAGES: 24 TOTAL_BYTES: 6144 USED_BYTES: 3391 VERSIONS: 36 EXPIRED_VERSIONS: 0 INTERNAL_PAGES: NULL FREE_PAGES: NULL
-- OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGE_SIZE: 256 PAGES: 26 TOTAL_BYTES: 6656 USED_BYTES: 1979 VERSIONS: 30 EXPIRED_VERSIONS: 0 INTERNAL_PAGES: NULL FREE_PAGES: NULL
-- OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGE_SIZE: 256 PAGES: 14 TOTAL_BYTES: 3584 USED_BYTES: 2856 VERSIONS: 24 EXPIRED_VERSIONS: 0 INTERNAL_PAGES: NULL FREE_PAGES: NULL
-- OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGE_SIZE: 256 PAGES: 317 TOTAL_BYTES: 81152 USED_BYTES: 8727 VERSIONS: 96 EXPIRED_VERSIONS: 0 INTERNAL_PAGES: 81 FREE_PAGES: 167

-- # The estimates of each mode, which are what COMPACT does.
/* extensions V004-01 */
VACUUM ANALYZE;
SELECT object_name, object_type, pages, pages_after_compact, pages_after_full, pages_after_free_pages, total_bytes_after_compact, total_bytes_after_full, total_bytes_after_free_pages, is_finished FROM vsql.last_vacuum_analyze;
VACUUM COMPACT;
SELECT object_name, object_type, pages_read, pages_freed FROM vsql.last_vacuum;
VACUUM ANALYZE;
SELECT object_name, object_type, pages, free_pages FROM vsql.last_vacuum_analyze;
-- msg: VACUUM ANALYZE 69
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 24 PAGES_AFTER_COMPACT: 20 PAGES_AFTER_FULL: 18 PAGES_AFTER_FREE_PAGES: 24 TOTAL_BYTES_AFTER_COMPACT: 5120 TOTAL_BYTES_AFTER_FULL: 4608 TOTAL_BYTES_AFTER_FREE_PAGES: 6144 IS_FINISHED: YES
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 26 PAGES_AFTER_COMPACT: 20 PAGES_AFTER_FULL: 9 PAGES_AFTER_FREE_PAGES: 26 TOTAL_BYTES_AFTER_COMPACT: 5120 TOTAL_BYTES_AFTER_FULL: 2304 TOTAL_BYTES_AFTER_FREE_PAGES: 6656 IS_FINISHED: YES
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES: 14 PAGES_AFTER_COMPACT: 13 PAGES_AFTER_FULL: 12 PAGES_AFTER_FREE_PAGES: 14 TOTAL_BYTES_AFTER_COMPACT: 3328 TOTAL_BYTES_AFTER_FULL: 3072 TOTAL_BYTES_AFTER_FREE_PAGES: 3584 IS_FINISHED: YES
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 317 PAGES_AFTER_COMPACT: 138 PAGES_AFTER_FULL: 56 PAGES_AFTER_FREE_PAGES: 150 TOTAL_BYTES_AFTER_COMPACT: 35328 TOTAL_BYTES_AFTER_FULL: 14336 TOTAL_BYTES_AFTER_FREE_PAGES: 38400 IS_FINISHED: YES
-- msg: VACUUM 149 179
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES_READ: 27 PAGES_FREED: 4
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES_READ: 26 PAGES_FREED: 6
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 16 PAGES_FREED: 1
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 74 PAGES_FREED: 179
-- msg: VACUUM ANALYZE 57
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 20 FREE_PAGES: NULL
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 20 FREE_PAGES: NULL
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES: 13 FREE_PAGES: NULL
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 138 FREE_PAGES: 0

-- # FULL.
/* extensions V004-01 */
VACUUM ANALYZE;
SELECT object_name, object_type, pages, internal_pages, pages_after_full FROM vsql.last_vacuum_analyze;
VACUUM FULL;
VACUUM ANALYZE;
SELECT object_name, object_type, pages, internal_pages, free_pages FROM vsql.last_vacuum_analyze;
-- msg: VACUUM ANALYZE 69
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 24 INTERNAL_PAGES: NULL PAGES_AFTER_FULL: 18
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 26 INTERNAL_PAGES: NULL PAGES_AFTER_FULL: 9
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES: 14 INTERNAL_PAGES: NULL PAGES_AFTER_FULL: 12
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 317 INTERNAL_PAGES: 81 PAGES_AFTER_FULL: 56
-- msg: VACUUM 150 255
-- msg: VACUUM ANALYZE 43
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 18 INTERNAL_PAGES: NULL FREE_PAGES: NULL
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 9 INTERNAL_PAGES: NULL FREE_PAGES: NULL
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES: 13 INTERNAL_PAGES: NULL FREE_PAGES: NULL
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 62 INTERNAL_PAGES: 19 FREE_PAGES: 0

-- # FREE PAGES.
/* extensions V004-01 */
VACUUM ANALYZE;
SELECT pages_after_free_pages FROM vsql.last_vacuum_analyze WHERE object_type = 'FILE';
VACUUM FREE PAGES;
VACUUM ANALYZE;
SELECT pages, free_pages FROM vsql.last_vacuum_analyze WHERE object_type = 'FILE';
-- msg: VACUUM ANALYZE 69
-- PAGES_AFTER_FREE_PAGES: 150
-- msg: VACUUM 74 167
-- msg: VACUUM ANALYZE 69
-- PAGES: 150 FREE_PAGES: 0

-- # It doesn't change anything, so it's the same again, and LAST_VACUUM
-- # doesn't change.
/* extensions V004-01 */
VACUUM ON TABLE t;
VACUUM ANALYZE;
SELECT pages, used_bytes, free_pages, pages_after_compact, pages_after_full FROM vsql.last_vacuum_analyze WHERE object_type = 'FILE';
VACUUM ANALYZE;
SELECT pages, used_bytes, free_pages, pages_after_compact, pages_after_full FROM vsql.last_vacuum_analyze WHERE object_type = 'FILE';
SELECT COUNT(*) FROM vsql.last_vacuum;
-- msg: VACUUM 153 179
-- msg: VACUUM ANALYZE 57
-- PAGES: 138 USED_BYTES: 8727 FREE_PAGES: 0 PAGES_AFTER_COMPACT: 138 PAGES_AFTER_FULL: 56
-- msg: VACUUM ANALYZE 57
-- PAGES: 138 USED_BYTES: 8727 FREE_PAGES: 0 PAGES_AFTER_COMPACT: 138 PAGES_AFTER_FULL: 56
-- COL1: 4

-- # Only some objects. The columns that need every page of the file are NULL.
/* extensions V004-01 */
VACUUM ANALYZE ON TABLE t WITHOUT INDEXES;
SELECT * FROM vsql.last_vacuum_analyze;
VACUUM ANALYZE ON TABLE t WITHOUT LARGE OBJECTS;
SELECT object_name, object_type, pages, used_bytes, versions FROM vsql.last_vacuum_analyze;
VACUUM ANALYZE ON INDEX t_unique_1 TABLE t;
SELECT object_name, object_type, pages, used_bytes, versions FROM vsql.last_vacuum_analyze;
VACUUM ANALYZE ON SCHEMA public;
SELECT object_name, object_type, pages, pages_after_compact FROM vsql.last_vacuum_analyze;
VACUUM ON TABLE t;
SELECT object_name, object_type, pages_freed FROM vsql.last_vacuum;
-- msg: VACUUM ANALYZE 51
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T OBJECT_TYPE: TABLE PAGE_SIZE: 256 PAGES: 24 TOTAL_BYTES: 6144 USED_BYTES: 3391 VERSIONS: 36 EXPIRED_VERSIONS: 0 INTERNAL_PAGES: NULL FREE_PAGES: NULL PAGES_AFTER_COMPACT: 19 PAGES_AFTER_FULL: NULL PAGES_AFTER_FREE_PAGES: 24 TOTAL_BYTES_AFTER_COMPACT: 4864 TOTAL_BYTES_AFTER_FULL: NULL TOTAL_BYTES_AFTER_FREE_PAGES: 6144 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGE_SIZE: 256 PAGES: 14 TOTAL_BYTES: 3584 USED_BYTES: 2856 VERSIONS: 24 EXPIRED_VERSIONS: 0 INTERNAL_PAGES: NULL FREE_PAGES: NULL PAGES_AFTER_COMPACT: 13 PAGES_AFTER_FULL: NULL PAGES_AFTER_FREE_PAGES: 14 TOTAL_BYTES_AFTER_COMPACT: 3328 TOTAL_BYTES_AFTER_FULL: NULL TOTAL_BYTES_AFTER_FREE_PAGES: 3584 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGE_SIZE: 256 PAGES: 317 TOTAL_BYTES: 81152 USED_BYTES: NULL VERSIONS: NULL EXPIRED_VERSIONS: NULL INTERNAL_PAGES: NULL FREE_PAGES: 167 PAGES_AFTER_COMPACT: 144 PAGES_AFTER_FULL: NULL PAGES_AFTER_FREE_PAGES: 150 TOTAL_BYTES_AFTER_COMPACT: 36864 TOTAL_BYTES_AFTER_FULL: NULL TOTAL_BYTES_AFTER_FREE_PAGES: 38400 IS_FINISHED: YES
-- msg: VACUUM ANALYZE 63
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 24 USED_BYTES: 3391 VERSIONS: 36
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 26 USED_BYTES: 1979 VERSIONS: 30
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 317 USED_BYTES: NULL VERSIONS: NULL
-- msg: VACUUM ANALYZE 82
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 24 USED_BYTES: 3391 VERSIONS: 36
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 26 USED_BYTES: 1979 VERSIONS: 30
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES: 14 USED_BYTES: 2856 VERSIONS: 24
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 317 USED_BYTES: NULL VERSIONS: NULL
-- msg: VACUUM ANALYZE 82
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 24 PAGES_AFTER_COMPACT: 19
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 26 PAGES_AFTER_COMPACT: 20
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES: 14 PAGES_AFTER_COMPACT: 13
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 317 PAGES_AFTER_COMPACT: 138
-- msg: VACUUM 153 179
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES_FREED: 5
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES_FREED: 6
-- OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES_FREED: 1
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_FREED: 179

-- # An empty table, and another catalog, with a different page size.
/* extensions V004-01 */
/* page_size 1024 */
/* create_catalog FOO */
CREATE TABLE z (x INT);
SET CATALOG 'FOO';
CREATE TABLE e (id INT PRIMARY KEY);
INSERT INTO e (id) VALUES (1), (2), (3);
SET CATALOG ':memory:';
VACUUM ANALYZE ON TABLE z TABLE foo.public.e;
SELECT object_catalog, object_name, object_type, page_size, pages, total_bytes, used_bytes, versions FROM foo.vsql.last_vacuum_analyze;
VACUUM ANALYZE ON CATALOG foo;
SELECT object_catalog, object_name, object_type, pages, total_bytes, used_bytes, versions, internal_pages FROM vsql.last_vacuum_analyze;
-- msg: CREATE TABLE 1
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: SET CATALOG 1
-- msg: VACUUM ANALYZE 17
-- OBJECT_CATALOG: :memory: OBJECT_NAME: Z OBJECT_TYPE: TABLE PAGE_SIZE: 1024 PAGES: 0 TOTAL_BYTES: 0 USED_BYTES: 0 VERSIONS: 0
-- OBJECT_CATALOG: :memory: OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGE_SIZE: 1024 PAGES: 55 TOTAL_BYTES: 56320 USED_BYTES: NULL VERSIONS: NULL
-- OBJECT_CATALOG: FOO OBJECT_NAME: E OBJECT_TYPE: TABLE PAGE_SIZE: 1024 PAGES: 1 TOTAL_BYTES: 1024 USED_BYTES: 144 VERSIONS: 3
-- OBJECT_CATALOG: FOO OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGE_SIZE: 1024 PAGES: 1 TOTAL_BYTES: 1024 USED_BYTES: NULL VERSIONS: NULL
-- msg: VACUUM ANALYZE 1
-- OBJECT_CATALOG: FOO OBJECT_NAME: E OBJECT_TYPE: TABLE PAGES: 1 TOTAL_BYTES: 1024 USED_BYTES: 144 VERSIONS: 3 INTERNAL_PAGES: NULL
-- OBJECT_CATALOG: FOO OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 1 TOTAL_BYTES: 1024 USED_BYTES: 303 VERSIONS: 5 INTERNAL_PAGES: 0

-- # The versions of rows that a transaction can still see are kept.
/* extensions V004-01 */
/* connection 1 */
CREATE TABLE v (id INT);
INSERT INTO v (id) VALUES (1), (2), (3);
CREATE TABLE w (id INT PRIMARY KEY, s VARCHAR(100));
INSERT INTO w (id, s) VALUES (1, 'sssssssssssssssssssss'), (2, 'ssssssssssssssssssssss'), (3, 'sssssssssssssssssssssss'), (4, 'ssssssssssssssssssssssss'), (5, 'sssssssssssssssssssssssss'), (6, 'ssssssssssssssssssssssssss'), (7, 'sssssssssssssssssssssssssss'), (8, 'ssssssssssssssssssssssssssss'), (9, 'sssssssssssssssssssssssssssss'), (10, 'ssssssssssssssssssssssssssssss'), (11, 'sssssssssssssssssssssssssssssss'), (12, 'ssssssssssssssssssssssssssssssss'), (13, 'sssssssssssssssssssssssssssssssss'), (14, 'ssssssssssssssssssssssssssssssssss'), (15, 'sssssssssssssssssssssssssssssssssss'), (16, 'ssssssssssssssssssssssssssssssssssss'), (17, 'sssssssssssssssssssssssssssssssssssss'), (18, 'ssssssssssssssssssssssssssssssssssssss'), (19, 'sssssssssssssssssssssssssssssssssssssss'), (20, 'ssssssssssssssssssssssssssssssssssssssss');
/* connection 2 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM v;
/* connection 1 */
DELETE FROM v WHERE id = 1;
VACUUM ANALYZE ON TABLE v;
SELECT versions, expired_versions FROM vsql.last_vacuum_analyze WHERE object_name = 'V';
UPDATE w SET s = s || 'x';
VACUUM ANALYZE;
SELECT object_name, pages, versions, expired_versions, pages_after_full FROM vsql.last_vacuum_analyze WHERE object_type = 'TABLE';
/* connection 2 */
COMMIT;
/* connection 1 */
VACUUM ANALYZE ON TABLE v;
SELECT versions, expired_versions FROM vsql.last_vacuum_analyze WHERE object_name = 'V';
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 3
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 20
-- 2: msg: START TRANSACTION
-- 2: COL1: 3
-- 1: msg: DELETE 1
-- 1: msg: VACUUM ANALYZE 13
-- 1: VERSIONS: 3 EXPIRED_VERSIONS: 1
-- 1: msg: UPDATE 20
-- 1: msg: VACUUM ANALYZE 31
-- 1: OBJECT_NAME: V PAGES: 2 VERSIONS: 3 EXPIRED_VERSIONS: 1 PAGES_AFTER_FULL: 1
-- 1: OBJECT_NAME: W PAGES: 19 VERSIONS: 40 EXPIRED_VERSIONS: 20 PAGES_AFTER_FULL: 19
-- 2: msg: COMMIT
-- 1: msg: VACUUM ANALYZE 8
-- 1: VERSIONS: 2 EXPIRED_VERSIONS: 0

-- # TIMEOUT.
/* extensions V004-01 */
VACUUM ANALYZE TIMEOUT 0;
SELECT object_name, object_type, pages, is_finished FROM vsql.last_vacuum_analyze;
VACUUM ANALYZE ON TABLE t TIMEOUT 0;
SELECT object_name, object_type, pages, is_finished FROM vsql.last_vacuum_analyze;
VACUUM ANALYZE TIMEOUT 100;
SELECT COUNT(*) FROM vsql.last_vacuum_analyze WHERE is_finished = 'YES';
-- msg: VACUUM ANALYZE 0
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 0 IS_FINISHED: NO
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 0 IS_FINISHED: NO
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 317 IS_FINISHED: NO
-- msg: VACUUM ANALYZE 0
-- OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES: 0 IS_FINISHED: NO
-- OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES: 0 IS_FINISHED: NO
-- OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES: 317 IS_FINISHED: NO
-- msg: VACUUM ANALYZE 69
-- COL1: 4

-- # It can be in a transaction, and fails without changing LAST_VACUUM_ANALYZE.
/* extensions V004-01 */
START TRANSACTION;
VACUUM ANALYZE;
SELECT COUNT(*) FROM vsql.last_vacuum_analyze;
VACUUM ANALYZE ON TABLE nope;
SELECT COUNT(*) FROM vsql.last_vacuum_analyze;
COMMIT;
-- msg: START TRANSACTION
-- msg: VACUUM ANALYZE 69
-- COL1: 4
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE
-- COL1: 0
-- msg: COMMIT

-- # COMPACT, FULL and FREE PAGES can't be used with ANALYZE.
VACUUM ANALYZE COMPACT;
VACUUM ANALYZE ON TABLE t FULL;
VACUUM ANALYZE FREE PAGES TIMEOUT 5;
VACUUM ANALYZE TIMEOUT 5 TIMEOUT 5;
VACUUM ANALYZE ON ALL TABLE t;
-- error 42601: syntax error: VACUUM ANALYZE can't have COMPACT
-- error 42601: syntax error: VACUUM ANALYZE can't have FULL
-- error 42601: syntax error: VACUUM ANALYZE can't have FREE PAGES
-- error 42601: syntax error: VACUUM TIMEOUT is given more than once
-- error 42601: syntax error: VACUUM ALL can only be on its own

-- # LAST_VACUUM_ANALYZE is read-only, and ANALYZE isn't reserved.
INSERT INTO vsql.last_vacuum_analyze (object_catalog) VALUES ('x');
CREATE TABLE analyze (analyze INT);
INSERT INTO analyze (analyze) VALUES (1);
SELECT analyze FROM analyze;
-- error 42501: insufficient privilege: VSQL is read-only
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- ANALYZE: 1

-- # Reading LAST_VACUUM_ANALYZE is flagged.
/* flags */
SELECT COUNT(*) FROM vsql.last_vacuum_analyze;
-- flags: F391, V004-03
-- COL1: 0
