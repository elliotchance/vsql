#include "test.h"

/* 6.36 GetFeatureInfo */

UTEST_F(db, 6_36_get_feature_info) {
  SQLSMALLINT supported = -1;

  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_SUCCESS);
  EXPECT_EQ(supported, 1);
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"S011", SQL_NTS, NULL, 0, &supported),
            SQL_SUCCESS);
  EXPECT_EQ(supported, 0);

  /* The arguments are trimmed, and the lengths can be given. */
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)" FEATURE ", 9,
                              (SQLCHAR *)"E011xx", 4, NULL, 0, &supported),
            SQL_SUCCESS);
  EXPECT_EQ(supported, 1);
}

UTEST_F(db, 6_36_get_feature_info_subfeature) {
  SQLSMALLINT supported = -1;

  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"SUBFEATURE",
                              SQL_NTS, (SQLCHAR *)"E011", SQL_NTS,
                              (SQLCHAR *)"01", SQL_NTS, &supported),
            SQL_SUCCESS);
  EXPECT_EQ(supported, 1);
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"SUBFEATURE",
                              SQL_NTS, (SQLCHAR *)"E011", SQL_NTS,
                              (SQLCHAR *)"99", SQL_NTS, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
}

UTEST_F(db, 6_36_get_feature_info_invalid) {
  SQLSMALLINT supported;

  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"X999", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"PACKAGE", SQL_NTS,
                              (SQLCHAR *)"PKG001", SQL_NTS, NULL, 0,
                              &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"OTHER", SQL_NTS,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"  ", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY090");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", -5,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY090");
}

UTEST_F(env, 6_36_get_feature_info_not_connected) {
  SQLSMALLINT supported;

  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}
