#include "test.h"

/* 6.45 GetTypeInfo */

UTEST_F(db, 6_45_get_type_info) {
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_ALL_TYPES), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 2),
               "1,2,3,4,5,6,7,8,12,16,25,91,92,93,94,95");

  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_ALL_TYPES), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1),
               "CHARACTER,NUMERIC,DECIMAL,INTEGER,SMALLINT,FLOAT,REAL,DOUBLE "
               "PRECISION,CHARACTER VARYING,BOOLEAN,BIGINT,DATE,TIME,"
               "TIMESTAMP,TIME WITH TIME ZONE,TIMESTAMP WITH TIME ZONE");
}

UTEST_F(db, 6_45_get_type_info_one) {
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_TYPE_DATE), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "DATE '");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_VARCHAR), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 6), "LENGTH");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_NUMERIC), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 15), "1000");
}

/* A data type that vsql doesn't support has no rows. */
UTEST_F(db, 6_45_get_type_info_unsupported) {
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, 30), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "");
  EXPECT_EQ(SQLGetTypeInfo(utest_fixture->stmt, 999), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY004");
}
