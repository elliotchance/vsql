/* windows.h must come before utest.h (in test.h), which otherwise declares
 * some of its functions itself. */
#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#include "test.h"

/* 6.7 Cancel */

/* With nothing to cancel, Cancel only empties the diagnostics area. */
UTEST_F(db, 6_7_cancel) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_STREQ(sqlstate(SQL_HANDLE_STMT, utest_fixture->stmt), "");
}

/* The cursor stays open. */
UTEST_F(db, 6_7_cancel_open_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
}

UTEST_F(db, 6_7_cancel_invalid_handle) {
  EXPECT_EQ(SQLCancel(utest_fixture->dbc), SQL_INVALID_HANDLE);
}

/* A query that's executing on another thread is canceled. The join compares
 * 4096 * 4096 pairs of rows, which takes much longer than the test waits. */
struct running {
  SQLHSTMT stmt;
  SQLRETURN rc;
  char sqlstate[6];
};

static void run_long_query(struct running *r) {
  r->rc = run_sql(r->stmt, "SELECT COUNT(*) FROM t AS a JOIN t AS b "
                           "ON a.x + b.x < 0");
  SQLGetDiagRec(SQL_HANDLE_STMT, r->stmt, 1, (SQLCHAR *)r->sqlstate, NULL, NULL,
                0, NULL);
}

#ifdef _WIN32
static DWORD WINAPI run_running(LPVOID r) {
  run_long_query((struct running *)r);
  return 0;
}
#else
static void *run_running(void *r) {
  run_long_query((struct running *)r);
  return NULL;
}
#endif

UTEST_F(db, 6_7_cancel_running) {
  struct running r;
  SQLINTEGER count;
  int i;
#ifdef _WIN32
  HANDLE thread;
#else
  pthread_t thread;
#endif

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  for (i = 0; i < 12; i++) {
    ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t SELECT x FROM t"),
              SQL_SUCCESS);
  }

  r.stmt = utest_fixture->stmt;
  r.rc = SQL_SUCCESS;
  r.sqlstate[0] = '\0';
#ifdef _WIN32
  thread = CreateThread(NULL, 0, run_running, &r, 0, NULL);
  ASSERT_TRUE(thread != NULL);
  Sleep(1000);
#else
  ASSERT_EQ(pthread_create(&thread, NULL, run_running, &r), 0);
  sleep(1);
#endif

  /* Cancel doesn't wait for the query to finish. */
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
#ifdef _WIN32
  WaitForSingleObject(thread, INFINITE);
  CloseHandle(thread);
#else
  pthread_join(thread, NULL);
#endif
  EXPECT_EQ(r.rc, SQL_ERROR);
  EXPECT_STREQ(r.sqlstate, "HY008");

  /* The statement can be used again, and so can the table. */
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT COUNT(*) FROM t"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &count, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(count, 4096);
}
