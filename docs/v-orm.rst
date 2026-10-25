V ORM
=====

.. contents::

The ``vorm`` module is a driver for V's built-in ORM (``sql db { ... }``).

Example
-------

.. code-block:: v

   import elliotchance.vsql.vorm

   struct Product {
     id    int @[primary; sql: serial]
     name  string
     price f64
   }

   fn example() ! {
     mut db := vorm.open('test.vsql')!

     sql db {
       create table Product
     }!

     product := Product{
       name:  'Bagel'
       price: 1.25
     }
     sql db {
       insert product into Product
     }!

     cheap_products := sql db {
       select from Product where price < 3.0 order by name
     }!
     println(cheap_products)
   }

``db.conn`` is the ``vsql.Connection``, so ORM statements can be mixed with SQL
in the same connection (and transaction) with ``db.conn.query()``. An existing
connection can also be used with ``vorm.new()``:

.. code-block:: v

   mut conn := vsql.open('test.vsql')!
   mut db := vorm.new(conn)

See also ``examples/orm.v``.

Tables and Columns
------------------

Table and column names are always quoted, so they keep the same case as the ORM
uses (the ORM uses the struct name in lower case, unless you use
``@[table: 'name']``). Names that are reserved words in SQL, such as ``order``,
can be used. When you query an ORM table with SQL, remember to quote the names:

.. code-block:: sql

   SELECT "name", "price" FROM "product" WHERE "id" = 1

The V types are stored as:

.. list-table::
  :header-rows: 1

  * - V Type
    - SQL Type

  * - ``bool``
    - ``BOOLEAN``

  * - ``i8``, ``i16``, ``u8``
    - ``SMALLINT``

  * - ``int``, ``u16``, enums
    - ``INTEGER``

  * - ``i64``, ``u32``
    - ``BIGINT``

  * - ``u64``
    - ``NUMERIC(20)`` (since it can be larger than a ``BIGINT``)

  * - ``f32``
    - ``REAL``

  * - ``f64``
    - ``DOUBLE PRECISION``

  * - ``string``
    - ``CHARACTER VARYING(2048)``

  * - ``time.Time``
    - ``TIMESTAMP(6) WITHOUT TIME ZONE``

Fields that are not options are ``NOT NULL``. Values are converted to the type
of the column, so the V type of a field can be different to its SQL type, such
as a ``string`` that is stored as ``NUMERIC(5,2)``.

Attributes
----------

.. list-table::
  :header-rows: 1

  * - Attribute
    - Description

  * - ``@[table: 'name']``
    - On the struct, sets the table name.

  * - ``@[sql: 'name']``
    - Sets the column name.

  * - ``@[sql: i8]``
    - Uses the SQL type of a different V type (``SMALLINT`` in this case).

  * - ``@[sql_type: 'NUMERIC(5,2)']``
    - Sets the SQL type. Don't include ``NOT NULL``, it's added for fields that
      are not options.

  * - ``@[primary]``
    - Makes the field the ``PRIMARY KEY``.

  * - ``@[sql: serial]``
    - See *Serial Fields*.

  * - ``@[unique]``
    - Adds a ``UNIQUE`` constraint for the field.

  * - ``@[unique: 'group']``
    - Adds one ``UNIQUE`` constraint for all of the fields in the group.

  * - ``@[unique_key: 'a, b']``
    - On the struct, adds a ``UNIQUE`` constraint for the fields.

  * - ``@[references]``
    - Adds a ``REFERENCES`` constraint. A field named ``parent_id`` references
      the ``id`` of the ``parent`` table. Use ``@[references: 'table']`` or
      ``@[references: 'table(field)']`` to name the table or field. The
      referenced table must be created first.

  * - ``@[default: 7]``
    - Sets the column default. The value is SQL, so it must be a literal,
      ``NULL``, or one of the values that vsql allows for a default, such as
      ``CURRENT_TIMESTAMP``. Put a string in backticks (``@[default:
      '`none`']``).

  * - ``@[skip]`` or ``@[sql: '-']``
    - The field is not stored.

Serial Fields
-------------

vsql does not have identity columns, so each ``@[sql: serial]`` field gets a
sequence called ``"<table>_<field>_seq"`` when the table is created. A row that
is inserted with the field set to zero is given the next value of
the sequence. The sequence is dropped with the table.

Where
-----

A ``where`` can use ``==``, ``!=``, ``<``, ``<=``, ``>``, ``>=``, ``like``,
``is none`` and ``!is none``, combined with ``&&``, ``||`` and parentheses:

.. code-block:: v

   products := sql db {
     select from Product where (price < 3.0 || name like 'Ice%') && id != 1
   }!

Transactions
------------

``orm_begin()``, ``orm_commit()`` and ``orm_rollback()`` use ``START
TRANSACTION``, ``COMMIT`` and ``ROLLBACK``. vsql doesn't have savepoints, so the
savepoint functions return an error.

Limitations
-----------

- Indexes (``@[index]``) and comments (``@[comment]``) are ignored.

- A ``PRIMARY KEY`` must be a ``SMALLINT``, ``INTEGER`` or ``BIGINT`` field,
  so a ``string`` field can't be ``@[primary]``.

- These are not supported, because vsql doesn't support the SQL that the ORM
  generates for them yet:

  - ``in`` and ``!in`` in a ``where`` (the ``IN`` predicate).
  - ``select distinct``.
  - ``sum``, ``min`` and ``max`` of a field that isn't an ``f64``.
  - Updating rows from an array (``set name = rows.name where id ==
    rows.id``), which uses ``IN``.
  - ``ilike``, which isn't part of the SQL standard.
  - Nested transactions, which use savepoints (see `Transactions`_).

  Each of these returns an error from vsql when the query runs.
