#include "test.h"

/* 6.29 GetCursorName */

/* A statement gets a unique name. */
UTEST_F(db, 6_29_get_cursor_name) {
  SQLHSTMT stmt2;
  SQLCHAR name1[32], name2[32];
  SQLSMALLINT len;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  EXPECT_EQ(SQLGetCursorName(utest_fixture->stmt, name1, sizeof(name1), &len),
            SQL_SUCCESS);
  EXPECT_EQ(strncmp((char *)name1, "SQL_CUR", 7), 0);
  EXPECT_EQ(len, (SQLSMALLINT)strlen((char *)name1));
  EXPECT_EQ(SQLGetCursorName(stmt2, name2, sizeof(name2), NULL), SQL_SUCCESS);
  EXPECT_STRNE((char *)name1, (char *)name2);

  /* It stays the same. */
  EXPECT_EQ(SQLGetCursorName(utest_fixture->stmt, name2, sizeof(name2), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name1, (char *)name2);
}

UTEST_F(db, 6_29_get_cursor_name_truncated) {
  SQLCHAR name[4];

  EXPECT_EQ(SQLGetCursorName(utest_fixture->stmt, name, sizeof(name), NULL),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ((char *)name, "SQL");
}
