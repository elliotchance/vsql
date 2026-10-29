/* windows.h must come before utest.h (in test.h), which otherwise declares
 * some of its functions itself. */
#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

#include "test.h"

/* Threads */

/* THREADS threads each use their own environment at the same time, and
 * aren't created by V, so they aren't registered with the GC. Each inserts
 * ROWS rows into its own table, in a file that they all share, and into an
 * in-memory database, committing each row. */
#define THREADS 8
#define ROWS 50
#define THREADS_FILE "libvsql_threads_test.vsql"

struct worker {
  int n;
  int failures;
  char sqlstate[6];
};

static void fail(struct worker *w, SQLSMALLINT type, SQLINTEGER handle) {
  w->failures++;
  SQLGetDiagRec(type, handle, 1, (SQLCHAR *)w->sqlstate, NULL, NULL, 0, NULL);
}

static void insert_rows(struct worker *w, const char *server) {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
  char sql[100];
  int i;

  if (SQLAllocEnv(&env) != SQL_SUCCESS ||
      SQLAllocConnect(env, &dbc) != SQL_SUCCESS) {
    w->failures++;
    return;
  }
  if (SQLConnect(dbc, (SQLCHAR *)server, SQL_NTS, NULL, 0, NULL, 0) !=
          SQL_SUCCESS ||
      SQLAllocStmt(dbc, &stmt) != SQL_SUCCESS) {
    fail(w, SQL_HANDLE_DBC, dbc);
    return;
  }

  if (strcmp(server, ":memory:") == 0) {
    sprintf(sql, "CREATE TABLE t%d (x INT)", w->n);
    if (run_sql(stmt, sql) != SQL_SUCCESS) {
      fail(w, SQL_HANDLE_STMT, stmt);
    }
  }
  for (i = 0; i < ROWS; i++) {
    /* Each row has its own statement, so the handles are allocated and freed
     * while the other threads use theirs. */
    SQLHSTMT insert;
    if (SQLAllocStmt(dbc, &insert) != SQL_SUCCESS) {
      fail(w, SQL_HANDLE_DBC, dbc);
      continue;
    }
    sprintf(sql, "INSERT INTO t%d (x) VALUES (%d)", w->n, i);
    if (run_sql(insert, sql) != SQL_SUCCESS) {
      fail(w, SQL_HANDLE_STMT, insert);
    }
    SQLFreeStmt(insert, SQL_DROP);
    if (SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_COMMIT) != SQL_SUCCESS) {
      fail(w, SQL_HANDLE_DBC, dbc);
    }
  }

  SQLFreeStmt(stmt, SQL_DROP);
  SQLDisconnect(dbc);
  SQLFreeConnect(dbc);
  SQLFreeEnv(env);
}

static void work(struct worker *w) {
  insert_rows(w, THREADS_FILE);
  insert_rows(w, ":memory:");
}

#ifdef _WIN32
static DWORD WINAPI run_worker(LPVOID w) {
  work((struct worker *)w);
  return 0;
}
#else
static void *run_worker(void *w) {
  work((struct worker *)w);
  return NULL;
}
#endif

UTEST_F(db, threads) {
  struct worker workers[THREADS];
  SQLHDBC dbc;
  SQLHSTMT stmt;
  SQLINTEGER count;
  char sql[100];
  int i;
#ifdef _WIN32
  HANDLE threads[THREADS];
#else
  pthread_t threads[THREADS];
#endif

  remove(THREADS_FILE);
  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc), SQL_SUCCESS);
  ASSERT_EQ(SQLConnect(dbc, (SQLCHAR *)THREADS_FILE, SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc, &stmt), SQL_SUCCESS);
  for (i = 0; i < THREADS; i++) {
    sprintf(sql, "CREATE TABLE t%d (x INT)", i);
    ASSERT_EQ(run_sql(stmt, sql), SQL_SUCCESS);
  }
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_COMMIT), SQL_SUCCESS);

  for (i = 0; i < THREADS; i++) {
    workers[i].n = i;
    workers[i].failures = 0;
    workers[i].sqlstate[0] = '\0';
#ifdef _WIN32
    threads[i] = CreateThread(NULL, 0, run_worker, &workers[i], 0, NULL);
    ASSERT_TRUE(threads[i] != NULL);
#else
    ASSERT_EQ(pthread_create(&threads[i], NULL, run_worker, &workers[i]), 0);
#endif
  }
  for (i = 0; i < THREADS; i++) {
#ifdef _WIN32
    WaitForSingleObject(threads[i], INFINITE);
    CloseHandle(threads[i]);
#else
    pthread_join(threads[i], NULL);
#endif
    EXPECT_EQ(workers[i].failures, 0);
    EXPECT_STREQ(workers[i].sqlstate, "");
  }

  for (i = 0; i < THREADS; i++) {
    sprintf(sql, "SELECT COUNT(*) FROM t%d", i);
    ASSERT_EQ(run_sql(stmt, sql), SQL_SUCCESS);
    ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
    ASSERT_EQ(SQLGetData(stmt, 1, SQL_INTEGER, &count, 0, NULL), SQL_SUCCESS);
    EXPECT_EQ(count, ROWS);
    ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  }

  SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_COMMIT);
  SQLFreeStmt(stmt, SQL_DROP);
  SQLDisconnect(dbc);
  SQLFreeConnect(dbc);
  remove(THREADS_FILE);
}
