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
are listed in :doc:`sql-compliance-9075-3`.

The integer types have the same width on every platform: ``SQLSMALLINT`` is
16 bits (``int16_t``), ``SQLINTEGER`` (and the handle types) is 32 bits
(``int32_t``) and ``SQLBIGINT`` is 64 bits (``int64_t``). The standard makes
``SQLINTEGER`` a C ``long``, but that's 64 bits on macOS and Linux and 32 bits
on Windows. A binding from another language can use these widths directly.

When the ``SQL_ATTR_OUTPUT_NTS`` environment attribute is ``SQL_FALSE``
(strings that are returned aren't null terminated), a routine that returns a
string accepts a buffer length of ``0``: nothing is copied, the length is still
returned, and a value that isn't empty is ``01004`` (string data, right
truncation). So a program can ask for the length first. The standard makes a
buffer length that isn't greater than zero ``HY090``, which it still is with
null termination (the default). A null pointer for the string is still
``HY009``, unless ``libvsql.h`` says the routine allows one.

Threads
-------

The routines can be called from any thread, including threads that weren't
created by libvsql (such as the threads of a Go program). libvsql initializes
itself when it's loaded, so threads can make their first calls at the same time.

Each environment (``SQL_HANDLE_ENV``) is its own SQL-agent. Its routines run one
at a time, and it has its own current connection. So a connection in one
environment can have an active transaction while a connection in another
environment is used, and a routine that waits for a lock doesn't stop the other
environments from committing. Use an environment for each thread (or each
connection) that's used at the same time as the others.

``SQLCancel`` is the exception: it doesn't wait for the routine that's running
on the statement. If that routine is executing a statement (such as with
``SQLExecDirect``), the statement stops soon after, even when it's waiting for
another connection's transaction to finish, and the routine returns
``SQL_ERROR`` with ``HY008`` (operation canceled). The statement has no effect,
and the transaction it's in continues.

Connections to the same file share a lock, so they can be used at the same
time.

Transactions
------------

A transaction can span more than one connection of an environment: while one
connection has a transaction, the first statement on another one starts a part
of it there, with the same access mode and isolation level (unless ``SET LOCAL
TRANSACTION`` changes them first, see :doc:`set-transaction`). ``SQLEndTran``
with any of those connections (or with the environment) ends every part. A
commit checks the deferred constraints of every part first, and if any of them
fail, every part is rolled back. Committing more than one database isn't
atomic, though: if committing one of them fails after that (such as because of
a disk error), the ones before it stay committed. ``SQLStartTran`` with a
connection while the transaction is active on another one is ``25001``.

``SQLStartTran`` with a connection (``SQL_HANDLE_DBC``) starts its transaction
straight away. With an environment (``SQL_HANDLE_ENV``), it starts a transaction
that isn't in any connection yet (it's ``25001`` if one of them already has a
transaction). The first connection that executes a statement takes it, and the
other connections can't be used until it's ended with ``SQLEndTran``. Until
then, any connection can be used, ``SQLEndTran`` doesn't end it (none of the
connections has a transaction to end), and another ``SQLStartTran`` (for the
environment or one of its connections) replaces it.

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
- A transaction started by ``SQLStartTran`` lasts until ``SQLEndTran``. Its
  ``DIAGNOSTICS SIZE`` is the one of a ``SET TRANSACTION`` before it, if there
  was one.
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
against the import library ``libvsql.dll.a`` (next to ``libvsql.dll``), and
leave out the ``-rpath``. Windows has no rpath, so the program finds
``libvsql.dll`` in its own folder or on the ``PATH``:

.. code-block:: sh

   gcc example.c -Iinclude -Lbin -lvsql -o bin/example.exe
   bin/example.exe

The release doesn't have an import library (``libvsql.lib``) for MSVC.

Either way, it outputs:

.. code-block:: text

   1.23
   4.56

See Also
--------

- :doc:`sql-client-modules` to write the SQL in an SQL-client module, which
  is compiled into C that calls libvsql.
- :doc:`embedded-sql-c` to write the SQL in the C program itself.
