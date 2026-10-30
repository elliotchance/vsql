Language: C/C++
===============

C and C++ programs use libvsql, a shared library that provides the routines of
the SQL/CLI (ISO/IEC 9075-3, the "Call-Level Interface"). Since it's a C
library, it can also be used from any other language that can call C
functions.

.. contents::

Install/Update
--------------

The release (see :doc:`install`) has the library in ``lib/``
(``libvsql.dylib`` on macOS, ``libvsql.so`` on Linux) or, on Windows, in
``bin/`` next to ``vsql.exe`` (``libvsql.dll``). Its header is
``include/libvsql.h``, and there's an example (``example.c``) in the top
folder. ``bin/``, ``include/`` and ``lib/`` are the usual layout of an install
prefix, so the folder can be copied into one, such as ``/usr/local``.

To build it from C for another platform, or without V, use the amalgamation
(see :doc:`install`) and run ``make libvsql``.

To build it from the repository instead, run ``make libvsql``. That creates
``bin/libvsql.dylib`` (or ``bin/libvsql.so`` or ``bin/libvsql.dll``), and the
header is ``libvsql/libvsql.h``.

Routines
--------

Each routine is documented in
`libvsql.h <https://github.com/elliotchance/vsql/blob/main/libvsql/libvsql.h>`_,
which is C99 and also works with C++. The routines that are supported so far
are listed in :doc:`sql-compliance`.

The integer types have the same width on every platform: ``SQLSMALLINT`` is
16 bits (``int16_t``), ``SQLINTEGER`` (and the handle types) is 32 bits
(``int32_t``) and ``SQLBIGINT`` is 64 bits (``int64_t``). The standard makes
``SQLINTEGER`` a C ``long``, but that's 64 bits on macOS and Linux and 32 bits
on Windows. A binding from another language can use these widths directly.

Threads
-------

The routines can be called from any thread, including threads that weren't
created by libvsql (such as the threads of a Go program).

Each environment (``SQL_HANDLE_ENV``) is its own SQL-agent. Its routines run one
at a time, and it has its own current connection. So a connection in one
environment can have an active transaction while a connection in another
environment is used, and a routine that waits for a lock doesn't stop the other
environments from committing. Use an environment for each thread (or each
connection) that's used at the same time as the others.

Connections to the same file share a lock, so they can be used at the same
time.

Autocommit
----------

By default, the first statement starts a transaction that lasts until
``SQLEndTran``, as the standard requires. Setting the ``SQL_ATTR_AUTOCOMMIT``
connection attribute to ``SQL_AUTOCOMMIT_ON`` commits each statement instead
(this isn't in the standard, and it's the same as in ODBC):

.. code-block:: c

   SQLSetConnectAttr(dbc, SQL_ATTR_AUTOCOMMIT,
                     &(SQLINTEGER){SQL_AUTOCOMMIT_ON}, 0);

- A statement that isn't a query is committed when it finishes, and it's
  rolled back if it fails.
- A query is committed when its cursor is closed (by ``SQLCloseCursor``,
  ``SQLFreeStmt``, ``SQLFreeHandle`` or ``SQLMoreResults``), once no other
  cursor of the connection is open.
- A transaction started by ``SQLStartTran`` lasts until ``SQLEndTran``.
- Turning it on commits the active transaction, if there is one.

Example
-------

``example.c`` is the :doc:`language-v` example, written against libvsql:

.. literalinclude:: ../libvsql/example.c
   :language: c

From the folder of a release, compile and run it as C with:

.. code-block:: sh

   cc example.c -Iinclude -Llib -lvsql -Wl,-rpath,"$PWD/lib" -o example
   ./example

Or as C++ with:

.. code-block:: sh

   c++ -x c++ example.c -Iinclude -Llib -lvsql -Wl,-rpath,"$PWD/lib" -o example
   ./example

The ``-rpath`` is where the program looks for the library when it runs. Leave
it out if the library is installed somewhere the system already looks, such as
``/usr/local/lib``.

On Windows, compile it with MinGW (``gcc``, or ``g++ -x c++``), which links
directly against ``libvsql.dll``, and leave out the ``-rpath``. Windows has no
rpath, so the program finds ``libvsql.dll`` in its own folder or on the
``PATH``:

.. code-block:: sh

   gcc example.c -Iinclude -Lbin -lvsql -o bin/example.exe
   bin/example.exe

The release doesn't have an import library (``libvsql.lib``) for MSVC.

Either way, it outputs:

.. code-block:: text

   1.23
   4.56


SQL-Client Modules
------------------

Instead of calling the routines yourself, you can write the SQL in an
SQL-client module (ISO/IEC 9075-2, Clause 13, Feature B112 "Module language
C"). Each ``PROCEDURE`` in the module has one SQL statement, and ``vsql
module`` compiles the module into a C header and source file. Each procedure
becomes a C function that executes its statement with libvsql.

Here's ``libvsql/module/example.mod``:

.. literalinclude:: ../libvsql/module/example.mod
   :language: sql

Compile it with:

.. code-block:: sh

   vsql module example.mod

That creates ``example.h`` and ``example.c`` next to it. The header declares a
function for each procedure:

.. code-block:: c

   void open_database(char SQLSTATE[6], char file[101]);
   void create_items(char SQLSTATE[6]);
   void add_item(char SQLSTATE[6], long *id, char name[21], double *price, short *price_indicator);
   void change_prices(char SQLSTATE[6], double *factor);
   void get_item(char SQLSTATE[6], long *id, char name[21], double *price, short *price_indicator);
   void rows_changed(char SQLSTATE[6], long *rows);
   void error_message(char SQLSTATE[6], char message[201]);
   void commit_work(char SQLSTATE[6]);
   void close_database(char SQLSTATE[6]);

A program includes the header and calls the functions, checking the
``SQLSTATE`` after each one (``"00000"`` is success, see :doc:`sqlstate`).
Here's ``libvsql/module/example_main.c``:

.. literalinclude:: ../libvsql/module/example_main.c
   :language: c

Compile the generated source with the program, and link them with libvsql,
the same as any other program that uses libvsql (C99, or C++ with ``c++ -x
c++``):

.. code-block:: sh

   cc example.c example_main.c -Iinclude -Llib -lvsql -Wl,-rpath,"$PWD/lib" -o example
   ./example

From the root of the repository, ``make module-example`` does all of this.

Modules
^^^^^^^

A module starts with:

.. code-block:: text

   MODULE [ <name> ]
   LANGUAGE C
   { SCHEMA <schema name> [ AUTHORIZATION <name> ] | AUTHORIZATION <name> }

The schema is the default schema of the statements in the module. Without
``SCHEMA``, it's the schema with the same name as the ``AUTHORIZATION``. The
schema must exist when the first SQL-connection is made (it's set with ``SET
SCHEMA`` at the start of each SQL-connection). For the default schema, use
``SCHEMA "PUBLIC"``.

Each procedure is:

.. code-block:: text

   PROCEDURE <name> ( <parameter> [, <parameter> ]... ) ;
     <statement> ;

The procedure name, and the name of each parameter, is also its name in C, so
it's a regular identifier (not a delimited one), kept as it's written. One of
the parameters must be ``SQLSTATE``, which is set to the SQLSTATE of the
statement. The other parameters are ``:name <data type>``, and the statement
uses them as ``:name``. Each one has this C type:

============================ =============================
SQL data type                C data type
============================ =============================
``CHARACTER(L)``             ``char name[L + 1]``
``CHARACTER VARYING(L)``     ``char name[L + 1]``
``SMALLINT``                 ``short *name``
``INTEGER``                  ``long *name``
``BIGINT``                   ``long long *name``
``REAL``                     ``float *name``
``DOUBLE PRECISION``         ``double *name``
``BOOLEAN``                  ``long *name`` (0 is FALSE)
============================ =============================

The other data types (such as ``NUMERIC`` and ``DATE``) have no C type. A
string must end with a null character within its length, otherwise the
``SQLSTATE`` is ``22024`` (unterminated C string).

A parameter can be NULL with an indicator parameter (a ``SMALLINT``,
``INTEGER`` or ``BIGINT``), which is written after it as ``:name INDICATOR
:indicator`` (or just ``:name :indicator``). The value is NULL when the
indicator is negative.

Statements
^^^^^^^^^^

A statement can be any statement that vsql supports, except a query (``SELECT``
or ``VALUES``), since cursors aren't supported yet. Use ``SELECT ... INTO``
instead to get one row. It can also be one of the connection statements:

- ``CONNECT TO <server> [ AS <name> ] [ USER <user> ]`` or ``CONNECT TO
  DEFAULT``. The server is the path to a database file (or ``:memory:``). Each
  value is a string, or a ``CHARACTER`` or ``CHARACTER VARYING`` parameter.
  Without ``AS``, the name is the server, so it must also be a valid name
  (otherwise the ``SQLSTATE`` is ``2E000``).
- ``SET CONNECTION <name>`` or ``SET CONNECTION DEFAULT``.
- ``DISCONNECT <name>``, ``DISCONNECT DEFAULT``, ``DISCONNECT CURRENT`` or
  ``DISCONNECT ALL``.

``SELECT ... INTO`` (ISO/IEC 9075-2, 14.7, Feature E111 "Single row SELECT
statement") is a ``SELECT`` with ``INTO`` and a parameter for each column
before the ``FROM``:

.. code-block:: text

   SELECT [ DISTINCT | ALL ] <select list>
   INTO <parameter> [, <parameter> ]...
   FROM ... [ WHERE ... ] [ GROUP BY ... ] [ HAVING ... ]

Each parameter is ``:name``, with an optional indicator parameter (``:name
INDICATOR :indicator`` or ``:name :indicator``), and is set to the value of its
column. It can't have ``UNION``, ``EXCEPT``, ``INTERSECT``, ``ORDER BY``,
``OFFSET`` or ``FETCH``. The ``SQLSTATE`` is:

- ``00000`` when there's one row.
- ``02000`` (no data) when there are no rows. The parameters aren't changed.
- ``21000`` (cardinality violation) when there's more than one row.
- ``22002`` (null value, no indicator parameter) for a NULL value without an
  indicator parameter. With one, the indicator is set to ``-1`` for a NULL
  value, otherwise ``0``.
- ``01004`` (string data, right truncation) when a string doesn't fit in its
  parameter. The string is cut, and its indicator (if there is one) is set to
  the length of the whole string.
- ``07002`` when the number of columns isn't the number of parameters. Without
  an asterisk (``*``) in the select list, this is an error when the module is
  compiled.

A ``CHARACTER(L)`` parameter is padded with spaces to its length.

``GET DIAGNOSTICS`` (ISO/IEC 9075-2, 23.1, Feature F121 "Basic diagnostics
management") gets information about the last statement that was executed (that
wasn't ``GET DIAGNOSTICS``):

.. code-block:: text

   GET DIAGNOSTICS <parameter> = <item> [, <parameter> = <item> ]...
   GET DIAGNOSTICS CONDITION <number> <parameter> = <item> [, <parameter> = <item> ]...

The first form gets information about the statement:

============================ ==================================================
Item                         Value
============================ ==================================================
``NUMBER``                   The number of conditions (``0`` for success).
``MORE``                     Always ``N``, since every condition is kept.
``COMMAND_FUNCTION``         The statement, such as ``INSERT`` or
                             ``UPDATE WHERE``.
``COMMAND_FUNCTION_CODE``    The code of the statement, such as ``50`` for
                             ``INSERT``.
``DYNAMIC_FUNCTION``         Always empty, since a statement in a module isn't
                             dynamic. ``DYNAMIC_FUNCTION_CODE`` is ``0``.
``ROW_COUNT``                The number of rows that were inserted, updated or
                             deleted.
``TRANSACTIONS_COMMITTED``   ``1`` if a transaction was committed, otherwise
                             ``0``.
``TRANSACTIONS_ROLLED_BACK`` ``1`` if a transaction was rolled back, otherwise
                             ``0``.
``TRANSACTION_ACTIVE``       ``1`` if there's a transaction now, otherwise ``0``.
============================ ==================================================

The second form gets information about a condition (an error or warning). The
number is from ``1`` to ``NUMBER``, and is an integer or a ``SMALLINT``,
``INTEGER`` or ``BIGINT`` parameter. Condition ``1`` is the one in the
``SQLSTATE`` of the statement. Any other number is ``35000`` (invalid condition
number).

============================ ==================================================
Item                         Value
============================ ==================================================
``RETURNED_SQLSTATE``        The SQLSTATE of the condition.
``MESSAGE_TEXT``             The message.
``MESSAGE_LENGTH``           The length of the message in characters.
``MESSAGE_OCTET_LENGTH``     The length of the message in bytes.
``CONDITION_NUMBER``         The number of the condition.
``CLASS_ORIGIN``             ``ISO 9075`` if the first two characters of the
                             SQLSTATE are defined by the SQL standard,
                             otherwise ``vsql``.
``SUBCLASS_ORIGIN``          Likewise for the last three characters.
``CONNECTION_NAME``          The name of the SQL-connection (``DEFAULT`` for
                             the default SQL-connection).
``SERVER_NAME``              The server of the SQL-connection.
============================ ==================================================

The other condition items (``CATALOG_NAME``, ``COLUMN_NAME``,
``CONSTRAINT_CATALOG``, ``CONSTRAINT_NAME``, ``CONSTRAINT_SCHEMA``,
``CURSOR_NAME``, ``PARAMETER_MODE``, ``PARAMETER_NAME``,
``PARAMETER_ORDINAL_POSITION``, ``ROUTINE_CATALOG``, ``ROUTINE_NAME``,
``ROUTINE_SCHEMA``, ``SCHEMA_NAME``, ``SPECIFIC_NAME``, ``TABLE_NAME``,
``TRIGGER_CATALOG``, ``TRIGGER_NAME`` and ``TRIGGER_SCHEMA``) are always empty
(or ``0``).

A number must be put in a ``SMALLINT``, ``INTEGER`` or ``BIGINT`` parameter, and
a string in a ``CHARACTER`` or ``CHARACTER VARYING`` parameter (a string that
doesn't fit is cut, and the ``SQLSTATE`` is ``01004``). ``GET DIAGNOSTICS ... =
ALL`` isn't supported.

If the first statement isn't a connection statement, it connects to
``DEFAULT``, which is a new in-memory database. Each SQL-connection has its own
transaction, which is started by the first statement (or ``START
TRANSACTION``) and ended by ``COMMIT`` or ``ROLLBACK``. A connection statement
can't be used while the current SQL-connection has a transaction (``0A001``,
or ``25001`` for ``DISCONNECT``).

When the program exits, every SQL-connection is disconnected, and a transaction
that wasn't committed is rolled back.

The SQL-connections belong to the module, so two modules in the same program
don't share them.
