Virtual Tables
==============

Virtual tables allow you to register tables that have their rows provided at the
time of a ``SELECT``:

.. code-block:: v

   db.register_virtual_table('CREATE TABLE foo ( "num" INT, word VARCHAR (32) )', fn (mut t vsql.VirtualTable) ! {
   	t.next_values([
   		vsql.new_integer_value(1),
   		vsql.new_varchar_value('hi'),
   	])

   	t.next_values([
   		vsql.new_integer_value(2),
   		vsql.new_varchar_value('there'),
   	])

   	t.done()
   })!

   result := db.query('SELECT * FROM foo')!
   for row in result {
   	num := row.get_int('num')!
   	word := row.get_string('WORD')!
   	println('${num} ${word}')
   }

Outputs:

.. code-block:: text

   1 hi
   2 there

See also
`examples/virtual-tables.v <https://github.com/elliotchance/vsql/blob/main/examples/virtual-tables.v>`_.

.. contents::

Registering a Virtual Table
---------------------------

The first argument of ``register_virtual_table`` must be a ``CREATE TABLE``
statement (see :doc:`create-table`), otherwise it's an error ``42601``. Only the
name of the table and the name and type of each column are used. The table
is in the current schema, unless the name has a schema, which must already
exist. A virtual table can't be in ``INFORMATION_SCHEMA`` (an error ``42501``).

A virtual table can't have the same name as a table (or another virtual table),
and a table can't be created with the name of a virtual table. Both are an error
``42P07``.

A virtual table belongs to the connection that registered it. It isn't stored
in the database file, so another connection to the same file (or the same
connection after it's opened again) doesn't have it. That's also why it isn't
in the :doc:`information-schema` views, or in a dump. It can't be dropped.

When the Rows Are Read
----------------------

The function is called each time the table is read, which is once for each time
the table is named in a statement. So each ``SELECT`` sees the rows as they are
at that time, and a ``SELECT`` that names the table twice (such as a join of the
table with itself) calls the function twice. Nothing is kept between them,
including inside a transaction.

Each call adds rows with ``t.next_values()``. The function is called again and
again until it calls ``t.done()``, even if a call doesn't add any rows, so the
rows can be provided in batches. If the function returns an error, the
statement fails with that error.

Values and Types
----------------

Each row must have a value for each column, in the order of the columns.
Otherwise the statement that reads the table fails with an error ``42601``,
such as:

.. code-block:: text

   virtual table PUBLIC.BAD has 2 columns, but a row has 1 value

The values are converted to the types of the columns, like an ``INSERT`` (see
:doc:`insert`), so a value that can't be converted is an error when the table is
read. For example, for an ``INTEGER`` column:

- An ``INTEGER``, ``SMALLINT`` or ``BIGINT`` value that fits is fine, and a
  ``BIGINT`` that's too large is ``22003`` (numeric value out of range).
- A ``CHARACTER VARYING`` value (even ``'12'``) is ``42846`` (cannot coerce),
  just like an ``INSERT`` of a string into an ``INTEGER`` column.

A string that's too long for a ``VARCHAR(n)`` column is ``22001`` (string data
right truncation), and a number for a string column is ``42846``. A ``NULL``
(of any type) is ``NULL``.

The constraints of the ``CREATE TABLE`` (such as ``NOT NULL``, ``CHECK`` and
``PRIMARY KEY``) aren't checked, since the rows can't be changed, so the
function must provide the rows the way they should be.

Queries
-------

A virtual table can be used anywhere a table is read: joined with other tables
(including tables in the file, and other virtual tables), in a subquery, in a
view (see :doc:`create-view`), or as the source of an
``INSERT INTO ... SELECT``. A view that reads a virtual table only works on a
connection that has registered it. ``EXPLAIN`` shows it as a
``VIRTUAL TABLE``:

.. code-block:: text

   VIRTUAL TABLE PUBLIC.FOO ("num" INTEGER, WORD CHARACTER VARYING(32))

A virtual table can't be changed. An ``INSERT``, ``UPDATE`` or ``DELETE``, or a
``CREATE INDEX`` on it, is an error ``42P01`` (no such table).

Transactions
------------

A virtual table isn't part of a transaction. Its rows are read again each time,
even inside a transaction, so two reads in the same transaction can see
different rows. A ``ROLLBACK`` doesn't change it.
