/* load_thread is a program, not one of the tests in libvsql/ that end in
 * _test.c, since the library can only be loaded once in a process. A thread
 * loads the library (its path is the first argument) and makes the first call,
 * then exits. Then THREADS threads each connect and run statements that
 * allocate enough for the GC to collect. The GC must not still have the thread
 * that loaded the library, which it can't stop or scan after it exits. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#include <pthread.h>
#endif

#include "libvsql.h"

#define THREADS 8

typedef SQLRETURN (*alloc_handle_fn)(SQLSMALLINT, SQLINTEGER, SQLINTEGER *);
typedef SQLRETURN (*connect_fn)(SQLHDBC, SQLCHAR *, SQLSMALLINT, SQLCHAR *,
                                SQLSMALLINT, SQLCHAR *, SQLSMALLINT);
typedef SQLRETURN (*exec_direct_fn)(SQLHSTMT, SQLCHAR *, SQLINTEGER);
typedef SQLRETURN (*statement_fn)(SQLHSTMT);
typedef SQLRETURN (*free_handle_fn)(SQLSMALLINT, SQLINTEGER);

static alloc_handle_fn sql_alloc_handle;
static connect_fn sql_connect;
static exec_direct_fn sql_exec_direct;
static statement_fn sql_fetch;
static statement_fn sql_close_cursor;
static statement_fn sql_disconnect;
static free_handle_fn sql_free_handle;

/* query compares a long literal, so that each statement allocates a lot. */
static char query[6000];

static const char *library_path;

/* symbol returns the routine called name, or exits. A function pointer can't
 * be converted to or from void * in ISO C, but POSIX and Windows allow it, so
 * it's copied instead. */
#ifdef _WIN32
static void *symbol(HMODULE library, const char *name) {
  FARPROC address = GetProcAddress(library, name);
  void *routine;
  memcpy(&routine, &address, sizeof(routine));
#else
static void *symbol(void *library, const char *name) {
  void *routine = dlsym(library, name);
#endif
  if (routine == NULL) {
    printf("%s not found\n", name);
    exit(1);
  }

  return routine;
}

/* use_libvsql returns 0 if every routine succeeds. */
static int use_libvsql(int statements) {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
  int i;

  if (sql_alloc_handle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env) != SQL_SUCCESS ||
      sql_alloc_handle(SQL_HANDLE_DBC, env, &dbc) != SQL_SUCCESS ||
      sql_connect(dbc, (SQLCHAR *)":memory:", SQL_NTS, NULL, 0, NULL, 0) !=
          SQL_SUCCESS ||
      sql_alloc_handle(SQL_HANDLE_STMT, dbc, &stmt) != SQL_SUCCESS) {
    return 1;
  }
  for (i = 0; i < statements; i++) {
    if (sql_exec_direct(stmt, (SQLCHAR *)query, SQL_NTS) != SQL_SUCCESS ||
        sql_fetch(stmt) != SQL_SUCCESS ||
        sql_close_cursor(stmt) != SQL_SUCCESS) {
      return 1;
    }
  }
  sql_free_handle(SQL_HANDLE_STMT, stmt);
  sql_disconnect(dbc);
  sql_free_handle(SQL_HANDLE_DBC, dbc);
  sql_free_handle(SQL_HANDLE_ENV, env);

  return 0;
}

/* load loads the library and makes the first call. */
static int load(void) {
#ifdef _WIN32
  HMODULE library = LoadLibraryA(library_path);
#else
  void *library = dlopen(library_path, RTLD_NOW);
#endif
  if (library == NULL) {
    printf("%s can't be loaded\n", library_path);
    return 1;
  }

  memcpy(&sql_alloc_handle, (void *[]){symbol(library, "SQLAllocHandle")},
         sizeof(void *));
  memcpy(&sql_connect, (void *[]){symbol(library, "SQLConnect")},
         sizeof(void *));
  memcpy(&sql_exec_direct, (void *[]){symbol(library, "SQLExecDirect")},
         sizeof(void *));
  memcpy(&sql_fetch, (void *[]){symbol(library, "SQLFetch")}, sizeof(void *));
  memcpy(&sql_close_cursor, (void *[]){symbol(library, "SQLCloseCursor")},
         sizeof(void *));
  memcpy(&sql_disconnect, (void *[]){symbol(library, "SQLDisconnect")},
         sizeof(void *));
  memcpy(&sql_free_handle, (void *[]){symbol(library, "SQLFreeHandle")},
         sizeof(void *));

  return use_libvsql(0);
}

#ifdef _WIN32
static DWORD WINAPI run_load(LPVOID failed) {
  *(int *)failed = load();
  return 0;
}

static DWORD WINAPI run_worker(LPVOID failed) {
  *(int *)failed = use_libvsql(20);
  return 0;
}
#else
static void *run_load(void *failed) {
  *(int *)failed = load();
  return NULL;
}

static void *run_worker(void *failed) {
  *(int *)failed = use_libvsql(20);
  return NULL;
}
#endif

int main(int argc, char **argv) {
  int failed[THREADS];
  int result = 0;
  int i;
#ifdef _WIN32
  HANDLE threads[THREADS];
#else
  pthread_t threads[THREADS];
#endif

  if (argc != 2) {
    printf("usage: %s LIBRARY\n", argv[0]);
    return 1;
  }
  library_path = argv[1];

  strcpy(query, "VALUES CASE WHEN '");
  memset(query + strlen(query), 'x', 5000);
  strcpy(query + strlen("VALUES CASE WHEN '") + 5000,
         "' = '' THEN 0 ELSE 1 END");

  /* The thread that loads the library has exited when it's joined. */
  failed[0] = 1;
#ifdef _WIN32
  threads[0] = CreateThread(NULL, 0, run_load, &failed[0], 0, NULL);
  if (threads[0] == NULL) {
    return 1;
  }
  WaitForSingleObject(threads[0], INFINITE);
  CloseHandle(threads[0]);
#else
  if (pthread_create(&threads[0], NULL, run_load, &failed[0]) != 0) {
    return 1;
  }
  pthread_join(threads[0], NULL);
#endif
  if (failed[0]) {
    printf("the first call failed\n");
    return 1;
  }

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
