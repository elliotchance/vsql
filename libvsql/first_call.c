/* first_call is a program, not one of the tests in libvsql/ that end in _test.c,
 * since the first routine can only be called once in a process. "make
 * libvsql-test" runs it many times: THREADS threads make the first libvsql call
 * of the process at the same time. A thread that uses libvsql before it's
 * initialized aborts the program. */

#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

#include "libvsql.h"

#define THREADS 16

static volatile int start = 0;

/* use_libvsql returns 0 if every routine succeeds. */
static int use_libvsql(void) {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
  SQLINTEGER value = 0;

  if (SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env) != SQL_SUCCESS ||
      SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc) != SQL_SUCCESS ||
      SQLConnect(dbc, (SQLCHAR *)":memory:", SQL_NTS, NULL, 0, NULL, 0) !=
          SQL_SUCCESS ||
      SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt) != SQL_SUCCESS ||
      SQLExecDirect(stmt, (SQLCHAR *)"VALUES 123", SQL_NTS) != SQL_SUCCESS ||
      SQLFetch(stmt) != SQL_SUCCESS ||
      SQLGetData(stmt, 1, SQL_INTEGER, &value, 0, NULL) != SQL_SUCCESS ||
      value != 123) {
    return 1;
  }

  SQLCloseCursor(stmt);
  SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_COMMIT);
  SQLFreeHandle(SQL_HANDLE_STMT, stmt);
  SQLDisconnect(dbc);
  SQLFreeHandle(SQL_HANDLE_DBC, dbc);
  SQLFreeHandle(SQL_HANDLE_ENV, env);

  return 0;
}

static void work(int *failed) {
  while (!start) {
  }
  *failed = use_libvsql();
}

#ifdef _WIN32
static DWORD WINAPI run_worker(LPVOID failed) {
  work((int *)failed);
  return 0;
}
#else
static void *run_worker(void *failed) {
  work((int *)failed);
  return NULL;
}
#endif

int main(void) {
  int failed[THREADS];
  int result = 0;
  int i;
#ifdef _WIN32
  HANDLE threads[THREADS];
#else
  pthread_t threads[THREADS];
#endif

  for (i = 0; i < THREADS; i++) {
    failed[i] = 1;
#ifdef _WIN32
    threads[i] = CreateThread(NULL, 0, run_worker, &failed[i], 0, NULL);
    if (threads[i] == NULL) {
      return 1;
    }
#else
    if (pthread_create(&threads[i], NULL, run_worker, &failed[i]) != 0) {
      return 1;
    }
#endif
  }

  start = 1;

  for (i = 0; i < THREADS; i++) {
#ifdef _WIN32
    WaitForSingleObject(threads[i], INFINITE);
    CloseHandle(threads[i]);
#else
    pthread_join(threads[i], NULL);
#endif
    if (failed[i]) {
      printf("thread %d failed\n", i);
      result = 1;
    }
  }

  return result;
}
