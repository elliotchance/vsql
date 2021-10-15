File Format
===========

vsql stores all data in a single file, usually with a ``.vsql`` extension
(although, that is not required).

The database file consists of a header followed by zero or more pages. All pages
are the same size and the file will expand in whole pages as more storage is
needed.

.. contents::

Header
------

The header is always one page or 4kb (4096 bytes).

At the moment only the first byte is used for a rudimentary version. It will be
expanded out in the future to contain a magic number and other metadata for the
file. See https://github.com/elliotchance/vsql/issues/42.

Pages
-----

Pages are fixed width and may be layed out in any order since they represent a
single B-tree that contains all records, tables, etc. (these are called
"objects" - described below) for the database.

A file will start with zero pages (this does not include the header) since there
is nothing stored and will expand as the B-tree needs to.

All pages within a file are the same size (4kb) and each page reserves 3 bytes
for metadata. The metadata describes the type of page (leaf or non-leaf) and the
current usage (how full the page is).

Objects within a page are kept sorted by key and unused space is always located
after the used data. You should not assume that the unused portion is zeroed,

A page that contains 2 objects will look like:

.. list-table::
  :header-rows: 1

  * - Byte Offset
    - Length
    - Description

  * - 0
    - 1 (byte)
    - Kind (0 = leaf, 1 = non-leaf)

  * - 1
    - 2 (u16)
    - Usage of page (including header). The value in this case will be 63. An
      empty page will have used bytes of 3.

  * - 3
    - 23 ([]byte)
    - An object of 23 bytes.

  * - 26
    - 37 ([]byte)
    - An object of 37 bytes.

Objects
-------

Pages are made up of objects. Objects wrap different types of entities (such as
a table or row) and the page does not need to be dedicated to a particular
object type.

The key uses a single character prefix to designate what type of object it is.
For example, ``T`` for tables. See the specific object definitions for more
information.

An object is serialized as:

- 4 bytes (signed integer) for the total length of the object (including self).
  4 bytes may seem excessive since the page cannot hold that much, but this is
  to prepare for a future when a single record spans multiple pages. See
  https://github.com/elliotchance/vsql/issues/43.
- 4 bytes for the created transaction ID (also called the "tid").
- 4 bytes for the expired transaction ID (also called the "xid").
- 2 bytes (signed integer) for the key length.
- *n* bytes for the key
- *n* bytes for the value. The length of the value can be calculated from the
  total length - 2 - key length.

Here is an example of a *Row Object* (91 bytes) stored as an *Object* (102
bytes):

.. list-table::
  :header-rows: 1

  * - Byte Offset
    - Length
    - Value/Description

  * - 0
    - 4 (signed 32-bit int)
    - 102 (the total length of the object, including self)

  * - 4
    - 4 (signed 32-bit int)
    - 123 (the transaction ID that created this row)

  * - 8
    - 4 (signed 32-bit int)
    - 0 (the transaction ID that expired this row, 0 means not expired)

  * - 12
    - 2 (signed 16-bit int)
    - 5 (key length)

  * - 14
    - 5
    - ``R12345`` (not the true representation, see *Row Objects*)

  * - 19
    - 91
    - The *Row Objects* data.

Table Objects
-------------

The object key for a table is ``T`` followed by the table name, for example
``TFOO`` for the ``foo`` table (notice the uppercase is because of the SQL
standard). Whereas the table ``"foo"`` would be ``Tfoo``.
   
The table definition is stored as:

- 1 byte (signed integer) for the table name length.
- *n* bytes for the table name.
- 1 byte (signed integer) for the number of columns in the primary key (0 means
  there is no primary key defined).
- For each primary key column:

  * 1 byte (signed integer) for the column name length.
  * *n* bytes for the column name.

- For each column:

  * 1 byte (signed integer) for the column name length.
  * *n* bytes for the table name.
  * 1 byte (signed integer) for the column type (see *Type Number* in *Row Objects*)
  * 1 byte (signed integer) for NULL constraint (1 = NOT NULL, 0 = nullable).
  * 2 bytes (signed integer) for size (eg. 100 in ``VARCHAR(100)``).
  * 2 bytes (signed integer) for precision (eg. 6 in ``DECIMAL(10, 6)``).

For example:

.. code-block:: sql

   CREATE TABLE products (
       product_id INT NOT NULL,
       product_name VARCHAR(64) NOT NULL,
       product_desc VARCHAR(1000),
       PRIMARY KEY (product_id)
   );

Is serialized as 41 bytes:

.. list-table::
  :header-rows: 1

  * - Byte Offset
    - Length
    - Description

  * - 0
    - 4 (signed int)
    - 1

  * - 4
    - 8 ([]byte)
    - ``PRODUCTS``

  * - 8
    - 1 (signed int)
    - 1

  * - 9
    - 1 (signed int)
    - 10

  * - 10
    - 10 ([]byte)
    - ``PRODUCT_ID``

  * - 24
    - 1 (signed int)
    - 10

  * - 25
    - 10 ([]byte)
    - ``PRODUCT_ID``

  * - 35
    - 1 (signed int)
    - 4 (INTEGER)

  * - 36
    - 1 (signed int)
    - 0 (NOT NULL)

  * - 37
    - 2 (signed int)
    - 0 (size, ignored)

  * - 39
    - 2 (signed int)
    - 0 (precision, ignored)

  * - 41
    - 1 (signed int)
    - 7 (CHARACTER VARYING)

  * - 42
    - 1 (signed int)
    - 0 (NOT NULL)

  * - 44
    - 2 (signed int)
    - 64 (size)

  * - 45
    - 2 (signed int)
    - 0 (precision, ignored)

  * - 47
    - 1 (signed int)
    - 7 (CHARACTER VARYING)

  * - 48
    - 1 (signed int)
    - 1 (nullable)

  * - 49
    - 2 (signed int)
    - 1000 (size)

  * - 51
    - 2 (signed int)
    - 0 (precision, ignored)

Row Objects
-----------

The object key for a row is ``R<table>:<id>``, where *<table>* is the name of
the table and *<id>* is a unique set of bytes for the row within the table. The
*<id>* will either be the binary representation of the `PRIMARY KEY` or a random
but sequental value. The *<id>* does not need to be the same length for all rows
within the table, but in many cases it will be. See
https://github.com/elliotchance/vsql/issues/44.

Within a row each of the values may be stored with a fixed or variable length.
The length of the row is the sum of all columns.

Some types that are nullable may include an extra byte on the front. If so, 0
for ``NOT NULL`` and 1 for ``NULL``.

The *Type Number* is not used in the row, but is used to identify this type for
describing columns in a *Table Object*.

.. list-table::
  :header-rows: 1

  * - Data Type
    - Bytes
    - Type Number
    - Description

  * - ``BOOLEAN``
    - 1
    - 1
    - ``0`` (FALSE), ``1`` (TRUE), ``2`` (UNKNOWN), ``3`` (NULL)

  * - ``BIGINT``
    - 8 (NOT NULL) or 9 (nullable)
    - 2
    -

  * - ``DOUBLE PRECISION``
    - 8 (NOT NULL) or 9 (nullable)
    - 3
    - 64-bit floating point.

  * - ``INTEGER``
    - 4 (NOT NULL) or 5 (nullable)
    - 4
    -

  * - ``REAL``
    - 4 (NOT NULL) or 5 (nullable)
    - 5
    - 32-bit floating point.

  * - ``SMALLINT``
    - 2 (NOT NULL) or 3 (nullable)
    - 6
    -

  * - ``CHARACTER VARYING``
    - 4 + len
    - 7
    - ``len`` may be zero. ``-1`` is a special length to signify NULL (followed
      by zero bytes).

  * - ``CHARACTER(n)``
    - 4 + len
    - 8
    - ``len`` may only be ``-1`` (for ``NULL``) or ``n``. Values that are less
      than ``n`` length will be right padded with spaces.

So, for example, following table:

.. code-block:: sql

   CREATE TABLE products (
       product_id INT NOT NULL,
       product_name VARCHAR(64) NOT NULL,
       product_desc VARCHAR(1000),
       PRIMARY KEY (product_id)
   );

   INSERT INTO products (product_id, product_name, product_desc) VALUES
     (100, 'Espresso Maker', 'Extra-large portafilter brews up to 4 shots of rich espresso');

   INSERT INTO products (product_id, product_name, product_desc) VALUES
     (200, 'Self Cleaning Juicer', NULL);
   
Will have the combined row layouts of 112 bytes:

.. list-table::
  :header-rows: 1

  * - Byte Offset
    - Length
    - Value

  * - 0
    - 4 (signed 32-bit int)
    - 100

  * - 4
    - 4 (signed 32-bit int)
    - 14

  * - 8
    - 14 ([]byte)
    - ``Espresso Maker``

  * - 22
    - 1 (byte)
    - 0

  * - 23
    - 60 ([]byte)
    - ``Extra-large portafilter brews up to 4 shots of rich espresso``

  * - 83
    - 4 (signed 32-bit int)
    - 200

  * - 87
    - 4 (signed 32-bit int)
    - 20

  * - 91
    - 20 ([]byte)
    - ``Self Cleaning Juicer``

  * - 111
    - 1 (byte)
    - 1
