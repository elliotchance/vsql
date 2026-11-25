-- # The options of VACUUM (V004-01): one of COMPACT (the default), FULL and
-- # FREE PAGES, and TIMEOUT, in any order.

/* setup */
CREATE TABLE t (k VARCHAR(20) PRIMARY KEY, n INT, v VARCHAR(50) UNIQUE, c CLOB);
INSERT INTO t (k, n, v) VALUES ('kk1', 1, 'v1'), ('kkk2', 2, 'vv2'), ('kkkk3', 3, 'vvv3'), ('kkkkk4', 4, 'vvvv4'), ('kkkkkk5', 5, 'vvvvv5'), ('kkkkkkk6', 6, 'vvvvvv6'), ('kkkkkkkk7', 7, 'vvvvvvv7'), ('kkkkkkkkk8', 8, 'vvvvvvvv8'), ('k9', 9, 'vvvvvvvvv9'), ('kk10', 10, 'vvvvvvvvvv10'), ('kkk11', 11, 'vvvvvvvvvvv11'), ('kkkk12', 12, 'vvvvvvvvvvvv12'), ('kkkkk13', 13, 'vvvvvvvvvvvvv13'), ('kkkkkk14', 14, 'vvvvvvvvvvvvvv14'), ('kkkkkkk15', 15, 'vvvvvvvvvvvvvvv15'), ('kkkkkkkk16', 16, 'vvvvvvvvvvvvvvvv16'), ('kkkkkkkkk17', 17, 'vvvvvvvvvvvvvvvvv17'), ('k18', 18, 'vvvvvvvvvvvvvvvvvv18'), ('kk19', 19, 'vvvvvvvvvvvvvvvvvvv19'), ('kkk20', 20, 'vvvvvvvvvvvvvvvvvvvv20'), ('kkkk21', 21, 'vvvvvvvvvvvvvvvvvvvvv21'), ('kkkkk22', 22, 'vvvvvvvvvvvvvvvvvvvvvv22'), ('kkkkkk23', 23, 'vvvvvvvvvvvvvvvvvvvvvvv23'), ('kkkkkkk24', 24, 'vvvvvvvvvvvvvvvvvvvvvvvv24'), ('kkkkkkkk25', 25, 'vvvvvvvvvvvvvvvvvvvvvvvvv25'), ('kkkkkkkkk26', 26, 'vvvvvvvvvvvvvvvvvvvvvvvvvv26'), ('k27', 27, 'vvvvvvvvvvvvvvvvvvvvvvvvvvv27'), ('kk28', 28, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvv28'), ('kkk29', 29, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvv29'), ('kkkk30', 30, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv30'), ('kkkkk31', 31, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv31'), ('kkkkkk32', 32, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv32'), ('kkkkkkk33', 33, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv33'), ('kkkkkkkk34', 34, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv34'), ('kkkkkkkkk35', 35, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv35'), ('k36', 36, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv36'), ('kk37', 37, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv37'), ('kkk38', 38, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv38'), ('kkkk39', 39, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv39'), ('kkkkk40', 40, '40'), ('kkkkkk41', 41, 'v41'), ('kkkkkkk42', 42, 'vv42'), ('kkkkkkkk43', 43, 'vvv43'), ('kkkkkkkkk44', 44, 'vvvv44'), ('k45', 45, 'vvvvv45'), ('kk46', 46, 'vvvvvv46'), ('kkk47', 47, 'vvvvvvv47'), ('kkkk48', 48, 'vvvvvvvv48'), ('kkkkk49', 49, 'vvvvvvvvv49'), ('kkkkkk50', 50, 'vvvvvvvvvv50'), ('kkkkkkk51', 51, 'vvvvvvvvvvv51'), ('kkkkkkkk52', 52, 'vvvvvvvvvvvv52'), ('kkkkkkkkk53', 53, 'vvvvvvvvvvvvv53'), ('k54', 54, 'vvvvvvvvvvvvvv54'), ('kk55', 55, 'vvvvvvvvvvvvvvv55'), ('kkk56', 56, 'vvvvvvvvvvvvvvvv56'), ('kkkk57', 57, 'vvvvvvvvvvvvvvvvv57'), ('kkkkk58', 58, 'vvvvvvvvvvvvvvvvvv58'), ('kkkkkk59', 59, 'vvvvvvvvvvvvvvvvvvv59'), ('kkkkkkk60', 60, 'vvvvvvvvvvvvvvvvvvvv60'), ('kkkkkkkk61', 61, 'vvvvvvvvvvvvvvvvvvvvv61'), ('kkkkkkkkk62', 62, 'vvvvvvvvvvvvvvvvvvvvvv62'), ('k63', 63, 'vvvvvvvvvvvvvvvvvvvvvvv63'), ('kk64', 64, 'vvvvvvvvvvvvvvvvvvvvvvvv64'), ('kkk65', 65, 'vvvvvvvvvvvvvvvvvvvvvvvvv65'), ('kkkk66', 66, 'vvvvvvvvvvvvvvvvvvvvvvvvvv66'), ('kkkkk67', 67, 'vvvvvvvvvvvvvvvvvvvvvvvvvvv67'), ('kkkkkk68', 68, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvv68'), ('kkkkkkk69', 69, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvv69'), ('kkkkkkkk70', 70, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv70'), ('kkkkkkkkk71', 71, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv71'), ('k72', 72, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv72'), ('kk73', 73, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv73'), ('kkk74', 74, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv74'), ('kkkk75', 75, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv75'), ('kkkkk76', 76, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv76'), ('kkkkkk77', 77, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv77'), ('kkkkkkk78', 78, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv78'), ('kkkkkkkk79', 79, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv79'), ('kkkkkkkkk80', 80, '80'), ('k81', 81, 'v81'), ('kk82', 82, 'vv82'), ('kkk83', 83, 'vvv83'), ('kkkk84', 84, 'vvvv84'), ('kkkkk85', 85, 'vvvvv85'), ('kkkkkk86', 86, 'vvvvvv86'), ('kkkkkkk87', 87, 'vvvvvvv87'), ('kkkkkkkk88', 88, 'vvvvvvvv88'), ('kkkkkkkkk89', 89, 'vvvvvvvvv89'), ('k90', 90, 'vvvvvvvvvv90'), ('kk91', 91, 'vvvvvvvvvvv91'), ('kkk92', 92, 'vvvvvvvvvvvv92'), ('kkkk93', 93, 'vvvvvvvvvvvvv93'), ('kkkkk94', 94, 'vvvvvvvvvvvvvv94'), ('kkkkkk95', 95, 'vvvvvvvvvvvvvvv95'), ('kkkkkkk96', 96, 'vvvvvvvvvvvvvvvv96'), ('kkkkkkkk97', 97, 'vvvvvvvvvvvvvvvvv97'), ('kkkkkkkkk98', 98, 'vvvvvvvvvvvvvvvvvv98'), ('k99', 99, 'vvvvvvvvvvvvvvvvvvv99'), ('kk100', 100, 'vvvvvvvvvvvvvvvvvvvv100'), ('kkk101', 101, 'vvvvvvvvvvvvvvvvvvvvv101'), ('kkkk102', 102, 'vvvvvvvvvvvvvvvvvvvvvv102'), ('kkkkk103', 103, 'vvvvvvvvvvvvvvvvvvvvvvv103'), ('kkkkkk104', 104, 'vvvvvvvvvvvvvvvvvvvvvvvv104'), ('kkkkkkk105', 105, 'vvvvvvvvvvvvvvvvvvvvvvvvv105'), ('kkkkkkkk106', 106, 'vvvvvvvvvvvvvvvvvvvvvvvvvv106'), ('kkkkkkkkk107', 107, 'vvvvvvvvvvvvvvvvvvvvvvvvvvv107'), ('k108', 108, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvv108'), ('kk109', 109, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvv109'), ('kkk110', 110, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv110'), ('kkkk111', 111, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv111'), ('kkkkk112', 112, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv112'), ('kkkkkk113', 113, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv113'), ('kkkkkkk114', 114, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv114'), ('kkkkkkkk115', 115, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv115'), ('kkkkkkkkk116', 116, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv116'), ('k117', 117, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv117'), ('kk118', 118, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv118'), ('kkk119', 119, 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv119'), ('kkkk120', 120, '120');
UPDATE t SET c = REPEAT('c', 600) WHERE MOD(n, 10) = 0;
DELETE FROM t WHERE MOD(n, 3) <> 0;
DELETE FROM t WHERE n <= 30;

-- # FULL rebuilds the whole file, so there's nothing left for COMPACT to
-- # remove.
/* extensions V004-01 */
VACUUM FULL;
VACUUM;
SELECT COUNT(*), SUM(n), SUM(CHAR_LENGTH(c)) FROM t;
SELECT COUNT(*), SUM(n) FROM t WHERE v >= '';
-- msg: VACUUM 150 255
-- msg: VACUUM 50 0
-- warning 01003: null value eliminated in set function
-- COL1: 30 COL2: 2295 COL3: 1800
-- COL1: 30 COL2: 2295

-- # COMPACT packs the pages, and then moves pages from the end of the file
-- # into the free pages.
/* extensions V004-01 */
VACUUM COMPACT;
VACUUM COMPACT;
SELECT COUNT(*), SUM(n), SUM(CHAR_LENGTH(c)) FROM t;
SELECT COUNT(*), SUM(n) FROM t WHERE v >= '';
SELECT n FROM t WHERE k = 'kkkkkkk87';
-- msg: VACUUM 149 179
-- msg: VACUUM 59 0
-- warning 01003: null value eliminated in set function
-- COL1: 30 COL2: 2295 COL3: 1800
-- COL1: 30 COL2: 2295
-- N: 87

-- # FREE PAGES only moves pages into the free pages, without packing them,
-- # so COMPACT can still remove more pages after it.
/* extensions V004-01 */
VACUUM FREE PAGES;
VACUUM FREE PAGES;
VACUUM COMPACT;
SELECT COUNT(*), SUM(n), SUM(CHAR_LENGTH(c)) FROM t;
SELECT COUNT(*), SUM(n) FROM t WHERE v >= '';
-- msg: VACUUM 74 167
-- msg: VACUUM 0 0
-- msg: VACUUM 86 12
-- warning 01003: null value eliminated in set function
-- COL1: 30 COL2: 2295 COL3: 1800
-- COL1: 30 COL2: 2295

-- # VSQL.LAST_VACUUM (V004-02) has a row for each table, index and the large
-- # objects of a table that had pages packed, and one for the file. A page with
-- # only definitions isn't counted for an object, so PAGES_READ can add up to
-- # less than the first number of the message. FULL and FREE PAGES don't pack
-- # the objects, so they only have the file.
/* extensions V004-01 */
VACUUM;
SELECT * FROM vsql.last_vacuum;
VACUUM FULL;
SELECT * FROM vsql.last_vacuum;
VACUUM FREE PAGES;
SELECT * FROM vsql.last_vacuum;
-- msg: VACUUM 149 179
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T OBJECT_TYPE: TABLE PAGES_READ: 27 PAGES_FREED: 4 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T_UNIQUE_1 OBJECT_TYPE: INDEX PAGES_READ: 26 PAGES_FREED: 6 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: PUBLIC OBJECT_NAME: T OBJECT_TYPE: LARGE OBJECTS PAGES_READ: 16 PAGES_FREED: 1 IS_FINISHED: YES
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 74 PAGES_FREED: 179 IS_FINISHED: YES
-- msg: VACUUM 138 76
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 138 PAGES_FREED: 76 IS_FINISHED: YES
-- msg: VACUUM 0 0
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: YES

-- # TIMEOUT stops it after the batch that's running when the time is up, which
-- # isn't an error. IS_FINISHED is NO for what it didn't get to (an object of a
-- # whole catalog that wasn't reached doesn't have a row). FULL is either
-- # finished or doesn't change anything.
/* extensions V004-01 */
VACUUM TIMEOUT 0;
SELECT * FROM vsql.last_vacuum;
VACUUM FULL TIMEOUT 0;
SELECT * FROM vsql.last_vacuum;
VACUUM FREE PAGES TIMEOUT 0;
VACUUM TIMEOUT 3600;
VACUUM TIMEOUT 60.5 COMPACT;
-- msg: VACUUM 0 0
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- msg: VACUUM 0 0
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: NO
-- msg: VACUUM 0 0
-- msg: VACUUM 149 179
-- msg: VACUUM 59 0

-- # Each option can only be given once, and only one of COMPACT, FULL and FREE
-- # PAGES.
VACUUM TIMEOUT 1 TIMEOUT 2;
VACUUM FULL COMPACT;
VACUUM FREE PAGES FULL;
VACUUM COMPACT COMPACT;
-- error 42601: syntax error: VACUUM TIMEOUT is given more than once
-- error 42601: syntax error: VACUUM can only have one of COMPACT, FULL and FREE PAGES
-- error 42601: syntax error: VACUUM can only have one of COMPACT, FULL and FREE PAGES
-- error 42601: syntax error: VACUUM COMPACT is given more than once

-- # The words of the options aren't reserved.
CREATE TABLE full_pages (compact INT, pages INT, timeout INT);
INSERT INTO full_pages (compact, pages, timeout) VALUES (1, 2, 3);
SELECT compact, pages, timeout FROM full_pages;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COMPACT: 1 PAGES: 2 TIMEOUT: 3

-- # When the first key of a page that some of its objects were moved out of is
-- # longer than the one before, the pointer to it in its parent page is longer,
-- # which can split the parent.
/* extensions V004-01 */
CREATE TABLE s (k VARCHAR(100) PRIMARY KEY);
INSERT INTO s (k) VALUES ('a000'), ('a000zzzzzzzzzzzzzzzzzzzz'), ('a001'), ('a002'), ('a002zzzzzzzzzzzzzzzzzzzz'), ('a003'), ('a004'), ('a004zzzzzzzzzzzzzzzzzzzz'), ('a005'), ('a006'), ('a006zzzzzzzzzzzzzzzzzzzz'), ('a007'), ('a008'), ('a008zzzzzzzzzzzzzzzzzzzz'), ('a009'), ('a010'), ('a010zzzzzzzzzzzzzzzzzzzz'), ('a011'), ('a012'), ('a012zzzzzzzzzzzzzzzzzzzz'), ('a013'), ('a014'), ('a014zzzzzzzzzzzzzzzzzzzz'), ('a015'), ('a016'), ('a016zzzzzzzzzzzzzzzzzzzz'), ('a017'), ('a018'), ('a018zzzzzzzzzzzzzzzzzzzz'), ('a019'), ('a020'), ('a020zzzzzzzzzzzzzzzzzzzz'), ('a021'), ('a022'), ('a022zzzzzzzzzzzzzzzzzzzz'), ('a023'), ('a024'), ('a024zzzzzzzzzzzzzzzzzzzz'), ('a025'), ('a026'), ('a026zzzzzzzzzzzzzzzzzzzz'), ('a027'), ('a028'), ('a028zzzzzzzzzzzzzzzzzzzz'), ('a029'), ('a030'), ('a030zzzzzzzzzzzzzzzzzzzz'), ('a031'), ('a032'), ('a032zzzzzzzzzzzzzzzzzzzz'), ('a033'), ('a034'), ('a034zzzzzzzzzzzzzzzzzzzz'), ('a035'), ('a036'), ('a036zzzzzzzzzzzzzzzzzzzz'), ('a037'), ('a038'), ('a038zzzzzzzzzzzzzzzzzzzz'), ('a039'), ('a040'), ('a040zzzzzzzzzzzzzzzzzzzz'), ('a041'), ('a042'), ('a042zzzzzzzzzzzzzzzzzzzz'), ('a043'), ('a044'), ('a044zzzzzzzzzzzzzzzzzzzz'), ('a045'), ('a046'), ('a046zzzzzzzzzzzzzzzzzzzz'), ('a047'), ('a048'), ('a048zzzzzzzzzzzzzzzzzzzz'), ('a049'), ('a050'), ('a050zzzzzzzzzzzzzzzzzzzz'), ('a051'), ('a052'), ('a052zzzzzzzzzzzzzzzzzzzz'), ('a053'), ('a054'), ('a054zzzzzzzzzzzzzzzzzzzz'), ('a055'), ('a056'), ('a056zzzzzzzzzzzzzzzzzzzz'), ('a057'), ('a058'), ('a058zzzzzzzzzzzzzzzzzzzz'), ('a059'), ('a060'), ('a060zzzzzzzzzzzzzzzzzzzz'), ('a061'), ('a062'), ('a062zzzzzzzzzzzzzzzzzzzz'), ('a063'), ('a064'), ('a064zzzzzzzzzzzzzzzzzzzz'), ('a065'), ('a066'), ('a066zzzzzzzzzzzzzzzzzzzz'), ('a067'), ('a068'), ('a068zzzzzzzzzzzzzzzzzzzz'), ('a069'), ('a070'), ('a070zzzzzzzzzzzzzzzzzzzz'), ('a071'), ('a072'), ('a072zzzzzzzzzzzzzzzzzzzz'), ('a073'), ('a074'), ('a074zzzzzzzzzzzzzzzzzzzz'), ('a075'), ('a076'), ('a076zzzzzzzzzzzzzzzzzzzz'), ('a077'), ('a078'), ('a078zzzzzzzzzzzzzzzzzzzz'), ('a079'), ('a080'), ('a080zzzzzzzzzzzzzzzzzzzz'), ('a081'), ('a082'), ('a082zzzzzzzzzzzzzzzzzzzz'), ('a083'), ('a084'), ('a084zzzzzzzzzzzzzzzzzzzz'), ('a085'), ('a086'), ('a086zzzzzzzzzzzzzzzzzzzz'), ('a087'), ('a088'), ('a088zzzzzzzzzzzzzzzzzzzz'), ('a089'), ('a090'), ('a090zzzzzzzzzzzzzzzzzzzz'), ('a091'), ('a092'), ('a092zzzzzzzzzzzzzzzzzzzz'), ('a093'), ('a094'), ('a094zzzzzzzzzzzzzzzzzzzz'), ('a095'), ('a096'), ('a096zzzzzzzzzzzzzzzzzzzz'), ('a097'), ('a098'), ('a098zzzzzzzzzzzzzzzzzzzz'), ('a099'), ('a100'), ('a100zzzzzzzzzzzzzzzzzzzz'), ('a101'), ('a102'), ('a102zzzzzzzzzzzzzzzzzzzz'), ('a103'), ('a104'), ('a104zzzzzzzzzzzzzzzzzzzz'), ('a105'), ('a106'), ('a106zzzzzzzzzzzzzzzzzzzz'), ('a107'), ('a108'), ('a108zzzzzzzzzzzzzzzzzzzz'), ('a109'), ('a110'), ('a110zzzzzzzzzzzzzzzzzzzz'), ('a111'), ('a112'), ('a112zzzzzzzzzzzzzzzzzzzz'), ('a113'), ('a114'), ('a114zzzzzzzzzzzzzzzzzzzz'), ('a115'), ('a116'), ('a116zzzzzzzzzzzzzzzzzzzz'), ('a117'), ('a118'), ('a118zzzzzzzzzzzzzzzzzzzz'), ('a119'), ('a120'), ('a120zzzzzzzzzzzzzzzzzzzz'), ('a121'), ('a122'), ('a122zzzzzzzzzzzzzzzzzzzz'), ('a123'), ('a124'), ('a124zzzzzzzzzzzzzzzzzzzz'), ('a125'), ('a126'), ('a126zzzzzzzzzzzzzzzzzzzz'), ('a127'), ('a128'), ('a128zzzzzzzzzzzzzzzzzzzz'), ('a129'), ('a130'), ('a130zzzzzzzzzzzzzzzzzzzz'), ('a131'), ('a132'), ('a132zzzzzzzzzzzzzzzzzzzz'), ('a133'), ('a134'), ('a134zzzzzzzzzzzzzzzzzzzz'), ('a135'), ('a136'), ('a136zzzzzzzzzzzzzzzzzzzz'), ('a137'), ('a138'), ('a138zzzzzzzzzzzzzzzzzzzz'), ('a139'), ('a140'), ('a140zzzzzzzzzzzzzzzzzzzz'), ('a141'), ('a142'), ('a142zzzzzzzzzzzzzzzzzzzz'), ('a143'), ('a144'), ('a144zzzzzzzzzzzzzzzzzzzz'), ('a145'), ('a146'), ('a146zzzzzzzzzzzzzzzzzzzz'), ('a147'), ('a148'), ('a148zzzzzzzzzzzzzzzzzzzz'), ('a149'), ('a150'), ('a150zzzzzzzzzzzzzzzzzzzz'), ('a151'), ('a152'), ('a152zzzzzzzzzzzzzzzzzzzz'), ('a153'), ('a154'), ('a154zzzzzzzzzzzzzzzzzzzz'), ('a155'), ('a156'), ('a156zzzzzzzzzzzzzzzzzzzz'), ('a157'), ('a158'), ('a158zzzzzzzzzzzzzzzzzzzz'), ('a159'), ('a160'), ('a160zzzzzzzzzzzzzzzzzzzz'), ('a161'), ('a162'), ('a162zzzzzzzzzzzzzzzzzzzz'), ('a163'), ('a164'), ('a164zzzzzzzzzzzzzzzzzzzz'), ('a165'), ('a166'), ('a166zzzzzzzzzzzzzzzzzzzz'), ('a167'), ('a168'), ('a168zzzzzzzzzzzzzzzzzzzz'), ('a169'), ('a170'), ('a170zzzzzzzzzzzzzzzzzzzz'), ('a171'), ('a172'), ('a172zzzzzzzzzzzzzzzzzzzz'), ('a173'), ('a174'), ('a174zzzzzzzzzzzzzzzzzzzz'), ('a175'), ('a176'), ('a176zzzzzzzzzzzzzzzzzzzz'), ('a177'), ('a178'), ('a178zzzzzzzzzzzzzzzzzzzz'), ('a179'), ('a180'), ('a180zzzzzzzzzzzzzzzzzzzz'), ('a181'), ('a182'), ('a182zzzzzzzzzzzzzzzzzzzz'), ('a183'), ('a184'), ('a184zzzzzzzzzzzzzzzzzzzz'), ('a185'), ('a186'), ('a186zzzzzzzzzzzzzzzzzzzz'), ('a187'), ('a188'), ('a188zzzzzzzzzzzzzzzzzzzz'), ('a189'), ('a190'), ('a190zzzzzzzzzzzzzzzzzzzz'), ('a191'), ('a192'), ('a192zzzzzzzzzzzzzzzzzzzz'), ('a193'), ('a194'), ('a194zzzzzzzzzzzzzzzzzzzz'), ('a195'), ('a196'), ('a196zzzzzzzzzzzzzzzzzzzz'), ('a197'), ('a198'), ('a198zzzzzzzzzzzzzzzzzzzz'), ('a199'), ('a200'), ('a200zzzzzzzzzzzzzzzzzzzz'), ('a201'), ('a202'), ('a202zzzzzzzzzzzzzzzzzzzz'), ('a203'), ('a204'), ('a204zzzzzzzzzzzzzzzzzzzz'), ('a205'), ('a206'), ('a206zzzzzzzzzzzzzzzzzzzz'), ('a207'), ('a208'), ('a208zzzzzzzzzzzzzzzzzzzz'), ('a209'), ('a210'), ('a210zzzzzzzzzzzzzzzzzzzz'), ('a211'), ('a212'), ('a212zzzzzzzzzzzzzzzzzzzz'), ('a213'), ('a214'), ('a214zzzzzzzzzzzzzzzzzzzz'), ('a215'), ('a216'), ('a216zzzzzzzzzzzzzzzzzzzz'), ('a217'), ('a218'), ('a218zzzzzzzzzzzzzzzzzzzz'), ('a219'), ('a220'), ('a220zzzzzzzzzzzzzzzzzzzz'), ('a221'), ('a222'), ('a222zzzzzzzzzzzzzzzzzzzz'), ('a223'), ('a224'), ('a224zzzzzzzzzzzzzzzzzzzz'), ('a225'), ('a226'), ('a226zzzzzzzzzzzzzzzzzzzz'), ('a227'), ('a228'), ('a228zzzzzzzzzzzzzzzzzzzz'), ('a229'), ('a230'), ('a230zzzzzzzzzzzzzzzzzzzz'), ('a231'), ('a232'), ('a232zzzzzzzzzzzzzzzzzzzz'), ('a233'), ('a234'), ('a234zzzzzzzzzzzzzzzzzzzz'), ('a235'), ('a236'), ('a236zzzzzzzzzzzzzzzzzzzz'), ('a237'), ('a238'), ('a238zzzzzzzzzzzzzzzzzzzz'), ('a239'), ('a240'), ('a240zzzzzzzzzzzzzzzzzzzz'), ('a241'), ('a242'), ('a242zzzzzzzzzzzzzzzzzzzz'), ('a243'), ('a244'), ('a244zzzzzzzzzzzzzzzzzzzz'), ('a245'), ('a246'), ('a246zzzzzzzzzzzzzzzzzzzz'), ('a247'), ('a248'), ('a248zzzzzzzzzzzzzzzzzzzz'), ('a249'), ('a250'), ('a250zzzzzzzzzzzzzzzzzzzz'), ('a251'), ('a252'), ('a252zzzzzzzzzzzzzzzzzzzz'), ('a253'), ('a254'), ('a254zzzzzzzzzzzzzzzzzzzz'), ('a255'), ('a256'), ('a256zzzzzzzzzzzzzzzzzzzz'), ('a257'), ('a258'), ('a258zzzzzzzzzzzzzzzzzzzz'), ('a259'), ('a260'), ('a260zzzzzzzzzzzzzzzzzzzz'), ('a261'), ('a262'), ('a262zzzzzzzzzzzzzzzzzzzz'), ('a263'), ('a264'), ('a264zzzzzzzzzzzzzzzzzzzz'), ('a265'), ('a266'), ('a266zzzzzzzzzzzzzzzzzzzz'), ('a267'), ('a268'), ('a268zzzzzzzzzzzzzzzzzzzz'), ('a269'), ('a270'), ('a270zzzzzzzzzzzzzzzzzzzz'), ('a271'), ('a272'), ('a272zzzzzzzzzzzzzzzzzzzz'), ('a273'), ('a274'), ('a274zzzzzzzzzzzzzzzzzzzz'), ('a275'), ('a276'), ('a276zzzzzzzzzzzzzzzzzzzz'), ('a277'), ('a278'), ('a278zzzzzzzzzzzzzzzzzzzz'), ('a279'), ('a280'), ('a280zzzzzzzzzzzzzzzzzzzz'), ('a281'), ('a282'), ('a282zzzzzzzzzzzzzzzzzzzz'), ('a283'), ('a284'), ('a284zzzzzzzzzzzzzzzzzzzz'), ('a285'), ('a286'), ('a286zzzzzzzzzzzzzzzzzzzz'), ('a287'), ('a288'), ('a288zzzzzzzzzzzzzzzzzzzz'), ('a289'), ('a290'), ('a290zzzzzzzzzzzzzzzzzzzz'), ('a291'), ('a292'), ('a292zzzzzzzzzzzzzzzzzzzz'), ('a293'), ('a294'), ('a294zzzzzzzzzzzzzzzzzzzz'), ('a295'), ('a296'), ('a296zzzzzzzzzzzzzzzzzzzz'), ('a297'), ('a298'), ('a298zzzzzzzzzzzzzzzzzzzz'), ('a299');
DELETE FROM s WHERE CHAR_LENGTH(k) = 4 AND MOD(CAST(SUBSTRING(k FROM 2 FOR 3) AS INT), 3) = 0;
VACUUM;
SELECT COUNT(*) FROM s;
SELECT COUNT(*) FROM s AS x JOIN s AS y ON x.k = y.k;
SELECT k FROM s WHERE k = 'a299';
SELECT k FROM s WHERE k = 'a298zzzzzzzzzzzzzzzzzzzz';
-- msg: CREATE TABLE 1
-- msg: INSERT 450
-- msg: DELETE 100
-- msg: VACUUM 323 0
-- COL1: 350
-- COL1: 350
-- K: a299
-- K: a298zzzzzzzzzzzzzzzzzzzz

-- # A B-tree that's only one page has nothing to pack.
/* extensions V004-01 */
DROP TABLE t RESTRICT;
VACUUM FULL;
VACUUM;
VACUUM;
SELECT * FROM vsql.last_vacuum;
-- msg: DROP TABLE 1
-- msg: VACUUM 7 316
-- msg: VACUUM 1 0
-- msg: VACUUM 1 0
-- OBJECT_CATALOG: :memory: OBJECT_SCHEMA: NULL OBJECT_NAME: NULL OBJECT_TYPE: FILE PAGES_READ: 0 PAGES_FREED: 0 IS_FINISHED: YES

-- # LAST_VACUUM is empty before the first VACUUM of the connection, and after
-- # a VACUUM that fails. It's only the rows of the connection that ran it.
/* extensions V004-01 */
SELECT COUNT(*) FROM vsql.last_vacuum;
VACUUM FREE PAGES;
SELECT COUNT(*) FROM vsql.last_vacuum;
VACUUM ON TABLE nope;
SELECT COUNT(*) FROM vsql.last_vacuum;
-- COL1: 0
-- msg: VACUUM 74 167
-- COL1: 1
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE
-- COL1: 0

-- # LAST_VACUUM is the same in every catalog, and can be filtered or copied
-- # into a table like any other view. It can be read in a transaction.
/* extensions V004-01 */
/* create_catalog FOO */
VACUUM;
START TRANSACTION;
CREATE TABLE vac AS (SELECT * FROM vsql.last_vacuum) WITH DATA;
SELECT object_name, SUM(pages_read) FROM vac WHERE object_schema = 'PUBLIC' AND object_type <> 'INDEX' GROUP BY object_name;
SELECT COUNT(*) FROM foo.vsql.last_vacuum;
COMMIT;
-- msg: VACUUM 150 179
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- OBJECT_NAME: T COL2: 43
-- COL1: 5
-- msg: COMMIT

-- # LAST_VACUUM is read-only, and VERBOSE isn't an option any more.
INSERT INTO vsql.last_vacuum (object_catalog, object_type, pages_read, pages_freed, is_finished) VALUES ('x', 'FILE', 0, 0, 'NO');
DELETE FROM vsql.last_vacuum;
VACUUM VERBOSE;
-- error 42501: insufficient privilege: VSQL is read-only
-- error 42501: insufficient privilege: VSQL is read-only
-- error 42601: syntax error: unexpected identifier at line 1, column 8 near "VACUUM VERBOSE"

-- # Reading LAST_VACUUM is flagged.
/* flags */
SELECT COUNT(*) FROM vsql.last_vacuum;
-- flags: V004-02
-- COL1: 0
