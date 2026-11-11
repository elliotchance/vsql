ISO/IEC 9075-3:2003 (Call-Level Interface)
==========================================

.. contents::

This page is for **ISO/IEC 9075-3:2003(E)** (the SQL:2003 working draft,
2003-09), which is the edition of this part that vsql is pinned to (see
:doc:`standard-index`). The feature IDs, feature names, table numbers and
Subclause numbers on this page are all from that edition, and can be different
in other editions.

Part 3 (SQL/CLI) defines routines for using SQL from another programming
language. ``make libvsql`` builds ``bin/libvsql.so`` (``bin/libvsql.dylib`` on
macOS, ``bin/libvsql.dll`` on Windows), a shared library that provides them for
C (Feature C002, "CLI routine invocation in C"). The declarations are in
``libvsql/libvsql.h``, which is C99, and :doc:`language-c` shows how to use
them. The ``ServerName`` for ``SQLConnect`` is the path to the database file
(or ``:memory:``), and an empty ``ServerName`` connects to a new in-memory
database.

Each connection has its own transaction, which is started when a statement is
executed (or with ``SQLStartTran``) and ended with ``SQLEndTran``.

Mandatory Features
------------------

As of the latest version (or at least the version of this documentation)
**vsql supports 0 of the 1 mandatory features** of ISO/IEC 9075-3:2003.

.. list-table:: Table 52 — Feature taxonomy and definition for mandatory features
   :header-rows: 1

   * - Feature ID
     - Feature Name

   * - ⭕ **C011**
     - **All facilities defined by this part of ISO/IEC 9075**

CLI Routines
------------

C011 requires all of the routines in Clause 6. **vsql supports 56 of the
63 routines.**

Each of the other routines exists in libvsql, so programs can still link to
them, but it returns ``SQL_ERROR`` because the feature it depends on isn't
supported: ``SQLGetLength``, ``SQLGetPosition`` and ``SQLGetSubString`` need
large object locators, ``SQLGetParamData`` needs output parameters, and
``SQLColumnPrivileges`` and ``SQLTablePrivileges`` need privileges (SQLSTATE
``HYC00``, optional feature not implemented). ``SQLGetSessionInfo`` selects
``CURRENT_USER``, ``SESSION_USER``, etc., which vsql doesn't support yet.

.. list-table:: Clause 6 — SQL/CLI routines
   :header-rows: 1

   * - Subclause
     - Routine

   * - ✅ 6.1
     - ``SQLAllocConnect``

   * - ✅ 6.2
     - ``SQLAllocEnv``

   * - ✅ 6.3
     - ``SQLAllocHandle``

   * - ✅ 6.4
     - ``SQLAllocStmt``

   * - ✅ 6.5
     - ``SQLBindCol``

   * - ✅ 6.6
     - ``SQLBindParameter``

   * - ✅ 6.7
     - ``SQLCancel``

   * - ✅ 6.8
     - ``SQLCloseCursor``

   * - ✅ 6.9
     - ``SQLColAttribute``

   * - ❌ 6.10
     - ``SQLColumnPrivileges``

   * - ✅ 6.11
     - ``SQLColumns``

   * - ✅ 6.12
     - ``SQLConnect``

   * - ✅ 6.13
     - ``SQLCopyDesc``

   * - ✅ 6.14
     - ``SQLDataSources``

   * - ✅ 6.15
     - ``SQLDescribeCol``

   * - ✅ 6.16
     - ``SQLDisconnect``

   * - ✅ 6.17
     - ``SQLEndTran``

   * - ✅ 6.18
     - ``SQLError``

   * - ✅ 6.19
     - ``SQLExecDirect``

   * - ✅ 6.20
     - ``SQLExecute``

   * - ✅ 6.21
     - ``SQLFetch``

   * - ✅ 6.22
     - ``SQLFetchScroll``

   * - ✅ 6.23
     - ``SQLForeignKeys``

   * - ✅ 6.24
     - ``SQLFreeConnect``

   * - ✅ 6.25
     - ``SQLFreeEnv``

   * - ✅ 6.26
     - ``SQLFreeHandle``

   * - ✅ 6.27
     - ``SQLFreeStmt``

   * - ✅ 6.28
     - ``SQLGetConnectAttr``

   * - ✅ 6.29
     - ``SQLGetCursorName``

   * - ✅ 6.30
     - ``SQLGetData``

   * - ✅ 6.31
     - ``SQLGetDescField``

   * - ✅ 6.32
     - ``SQLGetDescRec``

   * - ✅ 6.33
     - ``SQLGetDiagField``

   * - ✅ 6.34
     - ``SQLGetDiagRec``

   * - ✅ 6.35
     - ``SQLGetEnvAttr``

   * - ✅ 6.36
     - ``SQLGetFeatureInfo``

   * - ✅ 6.37
     - ``SQLGetFunctions``

   * - ✅ 6.38
     - ``SQLGetInfo``

   * - ❌ 6.39
     - ``SQLGetLength``

   * - ❌ 6.40
     - ``SQLGetParamData``

   * - ❌ 6.41
     - ``SQLGetPosition``

   * - ❌ 6.42
     - ``SQLGetSessionInfo``

   * - ✅ 6.43
     - ``SQLGetStmtAttr``

   * - ❌ 6.44
     - ``SQLGetSubString``

   * - ✅ 6.45
     - ``SQLGetTypeInfo``

   * - ✅ 6.46
     - ``SQLMoreResults``

   * - ✅ 6.47
     - ``SQLNextResult``

   * - ✅ 6.48
     - ``SQLNumResultCols``

   * - ✅ 6.49
     - ``SQLParamData``

   * - ✅ 6.50
     - ``SQLPrepare``

   * - ✅ 6.51
     - ``SQLPrimaryKeys``

   * - ✅ 6.52
     - ``SQLPutData``

   * - ✅ 6.53
     - ``SQLRowCount``

   * - ✅ 6.54
     - ``SQLSetConnectAttr``

   * - ✅ 6.55
     - ``SQLSetCursorName``

   * - ✅ 6.56
     - ``SQLSetDescField``

   * - ✅ 6.57
     - ``SQLSetDescRec``

   * - ✅ 6.58
     - ``SQLSetEnvAttr``

   * - ✅ 6.59
     - ``SQLSetStmtAttr``

   * - ✅ 6.60
     - ``SQLSpecialColumns``

   * - ✅ 6.61
     - ``SQLStartTran``

   * - ❌ 6.62
     - ``SQLTablePrivileges``

   * - ✅ 6.63
     - ``SQLTables``

See Also
--------

- :doc:`sql-compliance` for the other parts.
- `ISO/IEC 9075-3 - Information technology — Database languages — SQL — Part 3: Call-Level Interface (SQL/CLI) <https://www.iso.org/standard/63557.html>`_ (the 2016 edition, which is newer than the edition used here)
