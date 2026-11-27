Embedded SQL: C/C++
===================

Instead of calling the routines of libvsql (see :doc:`language-c`), the SQL
can also be written in the C program itself (ISO/IEC 9075-2, Clause 21,
Feature B012 "Embedded C"). Each ``EXEC SQL ... ;`` is an SQL statement, and
``vsql precompile`` turns the program into C by putting each statement in the
procedure of a module (see :doc:`sql-client-modules`), and calling it. Here's
``libvsql/embed/example.sqc``:

.. literalinclude:: ../libvsql/embed/example.sqc
   :language: text

Precompile, compile and run it with:

.. code-block:: sh

   vsql precompile example.sqc
   cc example.c -Iinclude -Llib -lvsql -Wl,-rpath,"$PWD/lib" -o example
   ./example

``vsql precompile example.sqc`` creates ``example.c`` next to it, which is the
program with the module's procedures (as ``static`` functions) before it. The
C compiler still reports the lines of ``example.sqc``. With ``-module``, it
also creates ``example.mod``, the module (the "implied" module) that the
statements are compiled from. From the root of the repository, ``make
embed-example`` does all of this.

Host variables are C variables that are defined between ``EXEC SQL BEGIN
DECLARE SECTION;`` and ``EXEC SQL END DECLARE SECTION;``, and a statement uses
them as ``:name``. They must be defined before the statements that use them,
and each one must have a different name. Each definition is one of these
types, and each variable can have an initial value:

============================ =============================
C data type                  SQL data type
============================ =============================
``char name[L + 1]``         ``CHARACTER(L)``
``VARCHAR name[L + 1]``      ``CHARACTER VARYING(L)``
``short name``               ``SMALLINT``
``long name``                ``INTEGER``
``long long name``           ``BIGINT``
``float name``               ``REAL``
``double name``              ``DOUBLE PRECISION``
``SQL TYPE IS BINARY(L)``    ``BINARY(L)``
``SQL TYPE IS VARBINARY(L)`` ``BINARY VARYING(L)``
``SQL TYPE IS CLOB(L)``      ``CHARACTER LARGE OBJECT(L)``
``SQL TYPE IS BLOB(L)``      ``BINARY LARGE OBJECT(L)``
============================ =============================

``SQL TYPE IS BINARY(L) name`` is replaced with ``unsigned char name[L]``, and
``SQL TYPE IS VARBINARY(L) name`` is replaced with the struct of a ``BINARY
VARYING(L)`` (see :ref:`sql-client-modules:Modules`), so its length is
``name.name_length`` and its octets are ``name.name_data``. ``SQL TYPE IS CLOB(L) name`` and ``SQL TYPE IS
BLOB(L) name`` are replaced with the struct of a ``CHARACTER LARGE OBJECT(L)``
and a ``BINARY LARGE OBJECT(L)`` in the same way (the data of a CLOB has ``L *
4`` octets, and its length is in characters).

``VARCHAR`` is replaced with ``char``, and the length of each array is
multiplied by 4 (so that it can hold L characters of up to 4 bytes each, see
:ref:`sql-client-modules:Modules`). One of the host variables must be
``char SQLSTATE[6]``, which is set to the SQLSTATE of each statement.

A statement can be anything that a procedure of a module can be, and a cursor
is declared with ``EXEC SQL DECLARE <cursor name> CURSOR FOR ...;`` before the
statements that use it. The host variables of the cursor's query are used each
time it's opened, and a program can have any number of ``OPEN`` statements for
a cursor.

``WHENEVER`` (ISO/IEC 9075-2, 21.2) goes to a C label when a later statement
(later in the text of the program) has a condition:

.. code-block:: text

   EXEC SQL WHENEVER <condition> { CONTINUE | GOTO <label> | GO TO <label> };

   <condition> ::=
       SQLEXCEPTION
     | SQLWARNING
     | NOT FOUND
     | SQLSTATE ( <class> [ , <subclass> ] )
     | CONSTRAINT [ [ <catalog> . ] <schema> . ] <constraint_name>

``SQLEXCEPTION`` is an exception (any SQLSTATE that doesn't start with ``00``,
``01`` or ``02``), ``SQLWARNING`` is a warning (``01``) and ``NOT FOUND`` is no
data (``02``). ``SQLSTATE (22)`` is any SQLSTATE in the class ``22``, and
``SQLSTATE (22, 012)`` is only ``22012``. ``CONSTRAINT`` is a violation of the
constraint, which is in the ``PUBLIC`` schema when a schema isn't given.
``CONTINUE`` stops going to the label.

When more than one applies, the label is the first of a violated constraint,
the SQLSTATE, its class, then ``SQLEXCEPTION``, ``SQLWARNING`` or ``NOT
FOUND``. A ``WHENEVER`` replaces the earlier ones that it includes: for example,
``WHENEVER SQLEXCEPTION CONTINUE`` also stops any ``SQLSTATE`` or
``CONSTRAINT`` for an exception, and ``WHENEVER SQLSTATE (23) CONTINUE`` stops
any ``CONSTRAINT``.

The precompiler is simple, so:

- ``EXEC SQL`` must be on one line, separated by spaces, and it isn't found in
  a C comment or string. The statement ends at the first semicolon that isn't
  in an SQL string, delimited identifier or comment.
- A declare section can only contain host variable definitions, one type in
  each (such as ``long a, b = 2;``), and not ``#define`` or other C.
- ``#include`` is not followed, so the host variables and statements must be in
  the same file.
