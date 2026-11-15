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
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"  ", SQL_NTS,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"SUBFEATURE",
                              SQL_NTS, (SQLCHAR *)"E011", SQL_NTS,
                              (SQLCHAR *)"  ", SQL_NTS, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY090");
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"E011-01", SQL_NTS, NULL, 0,
                              &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
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

/* An exception condition raised by the query of the SQL_FEATURES view is
 * returned on the connection handle, and Supported isn't set. */
UTEST_F(env, 6_36_get_feature_info_query_fails) {
  SQLSMALLINT supported = -1;

  remove("libvsql_get_feature_info.vsql");
  ASSERT_EQ(SQLConnect(utest_fixture->dbc,
                       (SQLCHAR *)"libvsql_get_feature_info.vsql", SQL_NTS,
                       NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(vsql_arm_fault("lock_shared", 1), 0);
  EXPECT_EQ(SQLGetFeatureInfo(utest_fixture->dbc, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "58030");
  EXPECT_EQ(supported, -1);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  remove("libvsql_get_feature_info.vsql");
  remove("libvsql_get_feature_info.vsql.wal");
  remove("libvsql_get_feature_info.vsql.session");
}
