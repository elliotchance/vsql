V ORM
=====

.. contents::

A ``vsql.Connection`` can be used with V's built-in ORM (``sql db { ... }``).

Example
-------

.. code-block:: v

   import elliotchance.vsql.vsql

   struct Product {
     id    int @[primary; sql: serial]
     name  string
     price f64
   }

   fn example() ! {
     mut db := vsql.open('test.vsql')!

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

Since it's the same connection, ORM statements can be mixed with
``db.query()``.

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

- ``UNIQUE``, ``@[default]`` and ``@[references]`` cannot be used, because
  vsql cannot declare them yet. Creating a table that uses them returns an
  error.

- Indexes (``@[index]``) are ignored.

- ``in`` and ``!in`` in a ``where`` are not supported, because vsql doesn't
  have the ``IN`` predicate yet.

- A ``PRIMARY KEY`` must be a single ``SMALLINT``, ``INTEGER`` or ``BIGINT``
  field.
