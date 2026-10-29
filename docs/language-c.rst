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

