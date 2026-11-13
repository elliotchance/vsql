File Format
===========

.. contents::

Overview
--------

vsql stores the entire database (also known as the catalog) in a single file.
The default extension is ``.vsql``, although that is not required.

A second file, with the same name followed by ``.session``, is created next to
the database file. It is always empty and is only used for locking (see
:doc:`mvcc`). It can be deleted whenever there are no open connections to the
database.

A third file, with the same name followed by ``.wal``, is the `Write-Ahead
Log`_. It must not be deleted, because it may contain the only copy of a
statement that was committed when the process stopped.

A fourth file, with the same name followed by ``.isolation``, is created the
first time a ``SERIALIZABLE`` transaction (the default) is started (see
:doc:`transactions`). Like the ``.session`` file,
it's always empty, is only used for locking, and can be deleted whenever there
are no open connections to the database. The same goes for a fifth file, with
that name followed by ``.queue``, which is created the first time a connection
waits for a transaction to start.

The file must include a *Header*, followed by zero or more pages. That is, when
the database file is initially created it will only have a *Header* and zero
pages.

Every page must be the same size, but this is configurable. The page size cannot
be changed after the file is created (the page size is stored in the *Header*).

A page can be one of two types: leaf and non-leaf, and they may appear in any
order in the file. They may also be reordered or removed as the file expands and
contracts.

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Size

  * - 0
    - `Header`_
    - 4096 bytes

  * - 4096
    - Page 0
    - *Page Size*

  * - 4096 + *Page Size*
    - Page 1
    - *Page Size*

  * - 4096 + (*N* x *Page Size*)
    - Page *N*
    - *Page Size*

Also see :doc:`limitations`.

Header
------

The header is always 4kb (4096 bytes), regardless of the page size. Like the
rest of the file, all numbers are big-endian. Not all of this space is used, the
remaining space is reserved (see `Compatibility`_).

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Format
    - Description

  * - 0
    - *Magic*
    - 8 bytes
    - Always ``76 73 71 6c 0d 0a 1a 0a`` (``vsql\r\n\x1a\n``). Any file that
      does not start with these bytes is not a vsql database.

  * - 8
    - *Read Version*
    - u16 (2 bytes)
    - The oldest version of the file format that can read this file. See
      `Compatibility`_.

  * - 10
    - *Write Version*
    - u16 (2 bytes)
    - The oldest version of the file format that can change this file. See
      `Compatibility`_.

  * - 12
    - *Schema Version*
    - i32 (4 bytes)
    - Incremented whenever the schema changes, so that connections know when
      to reload it.

  * - 16
    - *Page Size*
    - i32 (4 bytes)
    - The size of every page, in bytes.

  * - 20
    - *Root Page*
    - i32 (4 bytes)
    - The page number (not including the header) of the root of the B-tree.

  * - 24
    - *Transaction ID*
    - u64 (8 bytes)
    - The last transaction ID that was issued.

  * - 32
    - *Row ID*
    - u64 (8 bytes)
    - The last row ID that was issued. Rows in a table without a ``PRIMARY
      KEY`` are keyed by a row ID. Row IDs are never reused.

  * - 40
    - *Active Transactions*
    - 256 x u64 (2048 bytes)
    - The IDs of the transactions that are in progress. Unused slots are 0.

  * - 2088
    - *Table ID*
    - u64 (8 bytes)
    - The last table ID that was issued. Table IDs are never reused.

  * - 2096
    - *Index ID*
    - u64 (8 bytes)
    - The last index ID that was issued. Index IDs are never reused. Added in
      version 2 (it was reserved, so it's zero in an older file).

  * - 2104
    - *Reserved*
    - 1992 bytes
    - Zero in this version of the file format. See `Compatibility`_.

Compatibility
-------------

The version of the file format that vsql reads and writes is 3. Every version
of vsql can open a file created by an older version, and most features don't
need to change the file format at all. The *Read Version* and *Write Version*
in the `Header`_ work the same way as the read and write versions of SQLite:

- If the *Read Version* is newer than the version of the file format that vsql
  supports, the file is refused. Some part of the file can't be understood.

- If the *Write Version* is newer, the file can be read but not changed. Any
  statement that changes the file returns a ``25006`` error. The file uses a
  feature that this version of vsql doesn't know how to keep correct, such as
  an index that wouldn't be updated when a row is inserted.

A new file has both set to 1. A feature that needs a newer version only raises
them the first time it's used, so a file that never uses the feature can still
be read and changed by older versions of vsql. Neither is ever lowered, even if
the feature is no longer used.

.. list-table::
  :header-rows: 1

  * - Version
    - Changes

  * - 1
    - The first version.

  * - 2
    - Indexes (see `Index Object`_). The first ``CREATE INDEX`` (or the first
      index of a ``UNIQUE`` or ``FOREIGN KEY`` constraint) raises the
      *Write Version* to 2. The *Read Version* stays at 1, because version 1
      ignores the new objects.

  * - 3
    - Snapshots of ``REPEATABLE READ`` transactions (see `Snapshot Object`_
      and `Retained Version Object`_). The first ``REPEATABLE READ``
      transaction raises the *Write Version* to 3, because an older version
      would remove versions of rows that the snapshot needs when it commits.
      The *Read Version* stays at 1, because older versions ignore the new
      objects.

These rules keep changes compatible:

1. The *Magic*, *Read Version* and *Write Version* never move, so that every
   version of vsql can check them.

2. New header fields go in the *Reserved* space, which is zero until a field is
   added. vsql writes the reserved space back exactly as it read it, so a field
   added by a newer version isn't lost when an older version changes the file.

3. Schema objects, such as tables, are stored as SQL (see `Schema Objects`_).
   Most features that add to a definition, such as ``DEFAULT`` or ``CHECK``,
   only need the SQL to be extended, rather than a new layout. This doesn't
   raise the *Read Version*: an older version can't parse the new syntax, so
   it already refuses to open the file (every definition is parsed when the
   file is opened).

4. Things that can be described separately from the object they belong to
   should be stored as their own objects, with a new key prefix (see
   `Object`_), rather than added to the existing definition. For example,
   constraints can be stored as ``ALTER TABLE ... ADD CONSTRAINT`` statements.
   Older versions ignore key prefixes they don't know about, so this only needs
   to raise the *Write Version* (or nothing at all, if it doesn't change how
   rows are written).

5. A change to how values are encoded, such as a new data type, must raise the
   *Read Version* when a table that uses it is created. Existing encodings
   never change.

Page
----

All pages types (defined by *Kind*) use the same basic structure: a 16 byte
*Page Header* followed by the *Data*. The format of the data itself depends on
the *Kind*.

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Format
    - Description

  * - 0
    - *Kind*
    - u8 (1 byte)
    - The page type, see below.

  * - 1
    - *Flags*
    - u8 (1 byte)
    - Always 0. Reserved for changes to the layout of individual pages.

  * - 2
    - *Used*
    - u16 (2 bytes)
    - The number of bytes used by the page, including the *Page Header*.

  * - 4
    - *Checksum*
    - u32 (4 bytes)
    - Always 0. Reserved for detecting torn or corrupted pages.

  * - 8
    - *Log Sequence Number*
    - u64 (8 bytes)
    - Always 0. Reserved for a write-ahead log.

  * - 16
    - *Data*
    - (page size - 16) bytes
    - The objects in the page.

.. list-table::
  :header-rows: 1

  * - Kind
    - Page Type

  * - 0
    - `Leaf Page`_

  * - 1
    - `Non-leaf Page`_

Since *Used* has a max value of 65535 this is also the maximum possible size
for a page. Although, the default page size for new files is 4096 bytes. [1]_

So an empty page has a *Used* of 16 and an entirely full page has a *Used* equal
to the page size.

Leaf Page
---------

The *Page Header* has a *Kind* of ``0``.

The *Data* will contain zero or more objects. Although, zero objects is valid if
that were the case the page should be removed as part of the garbage collection.

Each `Object`_ may be variable length and can be any number of bytes so long as
the *Object* size is equal to or less than the (page size - 16). For objects
that cannot fit into a page, they are stored in as a `Blob Object`_ and
referenced from the *Object*.

Objects within a page are kept sorted by key and unused space is always located
after the used data. You should not assume that the unused portion is zeroed.
For example, a leaf page of 4096 bytes that contains three objects:

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Size

  * - 0
    - *Page Header* (*Used* is 979)
    - 16 bytes

  * - 16
    - Object 0
    - 230 bytes

  * - 246
    - Object 1
    - 512 bytes

  * - 758
    - Object 2
    - 221 bytes

  * - 979
    - Unused
    - 3117 bytes

Non-leaf Page
-------------

A non-leaf page share a lot of similarities with a `Leaf Page`_. However, the
Objects are pointers to Leaf pages. That is the *Value* within the *Object* is a
i32 that references the `Leaf Page`_ number. For example, a non-leaf page of
4096 bytes that contains three objects:

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Size

  * - 0
    - *Page Header* (*Kind* is 1, *Used* is 120)
    - 16 bytes

  * - 16
    - Object 0 (23 bytes of metadata, a 5 byte *Key* and an i32 *Value*)
    - 32 bytes

  * - 48
    - Object 1 (a 13 byte *Key*)
    - 40 bytes

  * - 88
    - Object 2 (a 5 byte *Key*)
    - 32 bytes

  * - 120
    - Unused
    - 3976 bytes

Objects within a non-leaf page are ordered based on the objects *Key*. This is
important for scanning (such as range queries) to improve performance as the
*Key* itself is the first *Key* in the referenced `Leaf Page`_. Here is an
example of how a `Non-leaf Page`_ references a `Leaf Page`_ (the keys are
written as text to keep them short):

.. list-table:: Page 123 (non-leaf)
  :header-rows: 1

  * - Object
    - *Key*
    - *Value*

  * - 0
    - ``apple``
    - 234 (i32)

  * - 1
    - ``mango``
    - 345 (i32)

.. list-table:: Page 234 (leaf)
  :header-rows: 1

  * - Object
    - *Key*
    - *Value*

  * - 0
    - ``apple``
    - ...

  * - 1
    - ``banana``
    - ...

  * - 2
    - ``kiwi``
    - ...

Any key from ``apple`` up to (but not including) ``mango`` is in page 234, and
keys from ``mango`` onwards are in page 345.

It's also important to note that as the B-tree gets larger, there may be
multiple non-leaf pages that need to be traversed this way. The process will
always end with a leaf page. A parent of a non-leaf (which must also be a
non-leaf) uses the *Key* that points to the first *Key* in the child page.

Object
------

Individual objects can be of different types and are encoded/decoded based on
the first byte of the *Key*. Objects with a first byte that isn't listed here
are ignored, so that new types of objects can be added (see
`Compatibility`_):

.. list-table::
  :header-rows: 1

  * - First Byte
    - Object Type

  * - ``B``
    - `Blob Object`_

  * - ``F``
    - `Fragment Object`_

  * - ``G``
    - `Retained Version Object`_

  * - ``I``
    - `Identity Value Object`_

  * - ``N``
    - `Index Object`_

  * - ``P``
    - `Snapshot Object`_

  * - ``Q``
    - `Sequence Object`_

  * - ``R``
    - `Row Object`_

  * - ``S``
    - `Schema Object`_

  * - ``T``
    - `Table Object`_

  * - ``V``
    - `Sequence Value Object`_

  * - ``X``
    - `Index Entry Object`_

Every object has this layout. Everything except the *Key* and *Value* is
metadata, which is 23 bytes in total:

.. list-table::
  :header-rows: 1

  * - Part
    - Format
    - Description

  * - *Length*
    - i32 (4 bytes)
    - Is the total length of the object (including the metadata).

  * - *TID*
    - u64 (8 bytes)
    - Transaction ID that created this object. [2]_

  * - *XID*
    - u64 (8 bytes)
    - Transaction ID that expired this object. [2]_

  * - *Key Len*
    - i16 (2 bytes)
    - The number of bytes in the *Key*.

  * - *Key*
    - *Key Len* bytes
    - The key. The first byte is the type of the object (see above).

  * - *Ref*
    - bool (1 byte)
    - When ``true``, the *Value* is a reference to blob objects. See
      `Blob Object`_.

  * - *Value*
    - The rest of the object
    - Depends on the type of the object.

Using this metadata we can say that the length of *Value* will be: (*Length* -
23 - *Key Len*). For example, an object of 230 bytes with a 4 byte *Key*:

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Size

  * - 0
    - *Length* (230)
    - 4 bytes

  * - 4
    - *TID*
    - 8 bytes

  * - 12
    - *XID*
    - 8 bytes

  * - 20
    - *Key Len* (4)
    - 2 bytes

  * - 22
    - *Key*
    - 4 bytes

  * - 26
    - *Ref*
    - 1 byte

  * - 27
    - *Value*
    - 203 bytes (230 - 23 - 4)

Blob Object
-----------

When an object is added to the B-tree that is larger than half a page, it must
be split into *blob* (B) and *fragment* (F) objects. Half a page, rather than a
whole page, because two versions of the same key (such as the row before and
after an ``UPDATE`` that hasn't been committed yet) must always fit into the
same page, and that includes their blob and fragment objects.

All of the bytes of the original object (including its metadata, see
`Object`_) are divided, in order, into blob objects that are each as large as
possible without being larger than half a page, followed by a fragment object
containing any left over data. The fragment is optional because the object
might happen to fit perfectly in a whole number of blob objects. The original
object is then replaced with a reference to them, which has the same key.

If the original object has the key *K*, it's stored as:

.. list-table::
  :header-rows: 1

  * - Key
    - *Ref*
    - Value

  * - ``B``, *K*, ``0`` (the character) and then the part number as an i32,
      starting at 0. There is one of these for each blob object.
    - ``false``
    - The next part of the bytes of the original object.

  * - ``F`` and then *K*, if there is a fragment.
    - ``false``
    - The remaining bytes of the original object.

  * - *K*
    - ``true``
    - The number of blob objects (i32), followed by whether there is a fragment
      object (bool). 5 bytes in total.

The blob and fragment objects have the *TID* of the original object. Only the
reference is expired when the object is deleted, and the blob and fragment
objects are removed along with it. When the object is read, the reference is
replaced with the original object, put back together from the blob and fragment
objects.

Fragment Object
---------------

A fragment object (uses the prefix ``F``) contains a portion of data from
splitting a large object. See `Blob Object`_.

Row Object
----------

A Row Object (has the ``R`` prefix) contains a table row:

.. list-table::
  :header-rows: 1

  * - Part
    - Format
    - Description

  * - *Row ID Length*
    - u16 (2 bytes)
    - The length of *Row ID*.

  * - *Row ID*
    - *Row ID Length* bytes
    - The same as the end of the key.

  * - *Column Count*
    - u16 (2 bytes)
    - The number of columns in the table when the row was written.

  * - *Values*
    - variable
    - The value of each column, in the order of the columns in the table.

A row with fewer columns than the table was written before the remaining
columns existed, and those columns are ``NULL``. Values after the last column of
the table are ignored. This lets columns be added to (or removed from the end
of) a table without rewriting its rows.

The serialization of each value does not need to be explained in detail here.
You can check the code for ``Row.bytes()`` and ``new_row_from_bytes()``
respectively.

Primary Key
^^^^^^^^^^^

For a table with a ``PRIMARY KEY``, the *Row ID* (which is also at the end of
the key of the row) is the value of each column in the ``PRIMARY KEY``, one
after another in the order that they are listed in the ``PRIMARY KEY``. Each
value is encoded so that comparing the bytes gives the same order as comparing
the values. This
keeps the rows in order of their ``PRIMARY KEY``, so that a range of keys can
be read without reading the whole table.

.. list-table::
  :header-rows: 1

  * - Type
    - Encoding

  * - ``SMALLINT``, ``INTEGER``, ``BIGINT``
    - Big-endian, 2, 4 and 8 bytes respectively, with the sign bit flipped (so
      that negative values come before positive values). For example, the
      ``INTEGER`` values -1, 0 and 1 are ``7fffffff``, ``80000000`` and
      ``80000001``.

  * - ``BOOLEAN``
    - One byte, 1 for ``FALSE`` and 2 for ``TRUE``.

  * - ``REAL``, ``DOUBLE PRECISION``
    - The IEEE 754 bits, big-endian, 4 and 8 bytes respectively. A positive
      number has the sign bit flipped and a negative number has every bit
      flipped. -0 is written as 0, because they are equal.

  * - ``NUMERIC``, ``DECIMAL``
    - One byte for the sign (0 negative, 1 zero, 2 positive). A zero has nothing
      else. Otherwise, the exponent as a 2 byte integer (like ``SMALLINT``),
      which is the number of digits before the decimal point, or minus the
      number of zeros after the decimal point for a number less than 1. Then
      each significant digit plus 1 as a byte, without leading or trailing
      zeros, and a 0 byte. Every byte after the sign is flipped for a negative
      number. For example, 1.5 and 1.50 are both ``02 8001 02 06 00``, and
      0.05 is ``02 7fff 06 00``. The digits are of the value truncated to
      2 × *s* + 3 decimal places, where *s* is the scale. A value always has
      exactly *s* decimal places now, so that doesn't change its digits, but
      files written by older versions can have a ``DECIMAL`` with more digits
      than its scale (such as 123/500 in a ``DECIMAL(3, 2)``), and that's
      enough to keep those values apart.

  * - ``CHARACTER``, ``CHARACTER VARYING``
    - The UTF-8 bytes of the string, without trailing spaces (because 'a' is
      equal to 'a '). Each space is followed by ``02`` if the next character
      that isn't a space sorts after a space, or ``00`` if it sorts before a
      space (such as a tab). The string ends with ``20 01``. This sorts the
      same way as comparing the strings, where the shorter one is padded with
      spaces. For example, 'a b' is ``61 20 02 62 20 01``.

  * - ``DATE``, ``TIME WITHOUT TIME ZONE``, ``TIMESTAMP WITHOUT TIME ZONE``
    - The value in the internal datetime format (the same number that is used to
      compare them) as an 8 byte integer (like ``BIGINT``).

  * - ``TIME WITH TIME ZONE``, ``TIMESTAMP WITH TIME ZONE``
    - The number of microseconds in UTC as an 8 byte integer (like ``BIGINT``),
      so that values in different time zones that are equal have the same key.
      The time zone is kept in the row.

The encoding of any type added later must also keep the order of the values,
and must be self-delimiting (the length can be worked out from the bytes
themselves), so that the values of each column in a ``PRIMARY KEY`` with more
than one column can be put one after another and still be in order.

Schema Objects
--------------

The definition of each schema, sequence and table is stored as the SQL
statement that would create it, like SQLite does. When the file is opened, the
statements are parsed to rebuild the schema in memory.

The SQL is written so that it means the same thing in any version of vsql:

- Every name is a delimited identifier (``"PUBLIC"."FOO"``), so it isn't
  affected by case folding or by new reserved words.

- Names don't include the catalog, since the catalog is the file itself.

- Data types are written in full, such as ``TIMESTAMP(0) WITHOUT TIME ZONE``,
  rather than relying on defaults.

Schema Object
-------------

A Schema Object (has the ``S`` prefix) contains a schema definition, as a
``CREATE SCHEMA`` statement:

.. code-block:: sql

  CREATE SCHEMA "PUBLIC"

Sequence Object
---------------

A Sequence Object (has the ``Q`` prefix) contains the definition for a sequence
(not including the next value, see `Sequence Value Object`_), as a ``CREATE
SEQUENCE`` statement:

.. code-block:: sql

  CREATE SEQUENCE "PUBLIC"."SEQ1"
    AS SMALLINT
    START WITH 10
    INCREMENT BY 5
    MINVALUE 10

The ``AS`` is only written when the data type isn't ``BIGINT``, which is the
data type of a sequence without one (including one from an older version of
vsql). The ``START WITH`` is the value that ``ALTER SEQUENCE ... RESTART`` goes back
to. Older versions of vsql didn't write it. Without it, the start value is the
``MINVALUE`` (or ``MAXVALUE`` for a descending sequence), otherwise 1.

Sequence Value Object
---------------------

A Sequence Value Object (has the ``V`` prefix) contains the current value of a
sequence (as an i64). It's followed by a bool that's true when the current value
is the last value of the sequence, because adding the increment would go past
the range of a ``BIGINT``. Then a bool that's true when the current value plus
the increment hasn't been returned by ``NEXT VALUE FOR`` yet (a new sequence, or
one that has been restarted), otherwise the current value is the last value that
was returned. Each bool is only written when it, or the one after it, is true,
so they're false if the object is shorter. Older versions of vsql didn't write
the second bool.

``NEXT VALUE FOR`` is not part of the transaction (a value is never handed out
twice, even if the transaction is rolled back), so it changes the value of the
visible version in place, without changing its *TID* or *XID*. However,
``CREATE SEQUENCE``, ``DROP SEQUENCE`` and an ``ALTER SEQUENCE`` that changes
the value (such as ``RESTART``) create or expire versions like any other object,
so they are undone by a ``ROLLBACK``.

Identity Value Object
---------------------

An Identity Value Object (has the ``I`` prefix, followed by the table ID as a
u64) contains the current value of the sequence of the identity column of the
table, the same as a `Sequence Value Object`_. The options of the sequence are
part of the column in the `Table Object`_. It's created with the table (or by
``ALTER TABLE ... ADD COLUMN``), and expired when the table or the column is
dropped. Like a sequence, the value is changed in place, but
``ALTER TABLE ... ALTER COLUMN`` creates a new version.

Table Object
------------

A Table Object (has the ``T`` prefix, followed by the table ID as a u64)
contains a table definition, as a ``CREATE TABLE`` statement:

.. code-block:: sql

  CREATE TABLE "PUBLIC"."FOO" (
    "ID" INTEGER NOT NULL,
    "BAR" CHARACTER VARYING(10),
    PRIMARY KEY ("ID")
  )

Each row of the table is a `Row Object`_ with a key of ``R``, the table ID as a
u64 and then the row ID. The row ID is the encoded ``PRIMARY KEY``, or a u64
from the *Row ID* in the `Header`_ for a table without a ``PRIMARY KEY``.
Since rows are keyed by the table ID rather than its name, a table or schema
can be renamed without changing its rows.

``ALTER TABLE ... ADD COLUMN`` replaces the definition with a new version that
has the same table ID. The new column is NULL for the existing rows (see
`Row Object`_), so they're only rewritten when its ``DEFAULT`` isn't ``NULL``.
``ALTER TABLE ... ALTER COLUMN`` only replaces the definition, the rows aren't
changed.

A constraint only has a ``CONSTRAINT "<name>"`` when its name isn't the
default for its position (``<table>_CHECK_2`` for the second ``CHECK``, see
:doc:`create-table`), such as a name that was given by the ``CREATE TABLE``,
or the name of a constraint that has moved because an earlier constraint was
dropped. A constraint without one gets the default name for its position when
the file is opened, so the name of a constraint never changes, and a table
that only has default names can still be read by older versions of vsql:

.. code-block:: sql

  CREATE TABLE "PUBLIC"."FOO" (
    "ID" INTEGER CONSTRAINT "ID_NOT_NULL" NOT NULL,
    CONSTRAINT "FOO_PK" PRIMARY KEY ("ID"),
    CHECK (ID > 0)
  )

``ALTER TABLE ... ADD CONSTRAINT`` and ``DROP CONSTRAINT`` replace the
definition. The rows are only rewritten when the ``PRIMARY KEY`` is added or
dropped, because it changes the row ID of every row.

Index Object
------------

An Index Object (has the ``N`` prefix, followed by the table ID and then the
index ID, each as a u64) contains the definition of an index (see
:doc:`create-index`), as a ``CREATE INDEX`` (or ``CREATE UNIQUE INDEX``)
statement:

.. code-block:: sql

  CREATE INDEX "FOO_BAR" ON "PUBLIC"."FOO" ("BAR", "BAZ" DESC)

The index is always in the schema of the table. The table is found by the table
ID in the key, rather than the name in the statement. The index ID is issued
from the *Index ID* in the `Header`_.

The indexes of a table are expired with the table. Every transaction that
changes a row keeps the entries of every index of the table up to date, so the
entries must never miss a row that another transaction can't see yet:
``CREATE INDEX`` waits for the other transactions with changes to the table to
finish, and while an index is created or dropped (and not committed) other
transactions can't change the rows of the table (they get a ``40001`` error).

A ``UNIQUE`` constraint has its own index, and a ``FOREIGN KEY`` uses one (see
:doc:`create-index`). These are stored like any other index. A table from
version 1 gets them the first time they're needed, when another transaction
can't have changes to the table (otherwise it's a ``40001`` error).

Index Entry Object
------------------

Each row of the table has an Index Entry Object (has the ``X`` prefix) in each
index of the table. The key is the index ID as a u64, followed by the value of
each column of the index, in order, and then the row ID (the same as the end of
the key of the `Row Object`_). The value is empty.

Each value is a byte that's ``00`` for ``NULL`` (so that it sorts before any
other value), or ``01`` followed by the value encoded like a `Primary Key`_.
Every byte of a ``DESC`` column (including the first) is flipped, so that it
sorts the other way. Like a ``PRIMARY KEY``, the encoding of each value is
self-delimiting, so the entries are in order of the values of the columns, then
the row ID. Two rows with the same values have different entries.

The entries follow the versions of the row, so that each transaction finds the
version of the row that it can see:

- A row that's inserted adds an entry, and a row that's deleted expires its
  entries.

- A row that's updated expires its old entry and adds a new one only in the
  indexes that have a column whose value changed. Otherwise, the entry is the
  same for both versions of the row.

- A row that's moved (because its ``PRIMARY KEY`` changed) is deleted and
  inserted, so its entries have the new row ID.

Snapshot Object
---------------

A ``REPEATABLE READ`` transaction has a snapshot of which transactions had
committed when it started (see :doc:`mvcc`). The snapshot is published as a
Snapshot Object (has the ``P`` prefix), so that other connections don't remove
versions of rows that it can still see when they commit. The key is the
transaction ID of the transaction as a u64. The object is created by that
transaction, and removed when it commits or rolls back (or by recovery, if
the process stopped).

.. list-table::
  :header-rows: 1

  * - Part
    - Format
    - Description

  * - *Transaction ID*
    - u64 (8 bytes)
    - The ID of the transaction itself. Every transaction with a lower ID had
      committed (or rolled back) when the snapshot was taken, except for the
      *Active Transactions*.

  * - *Active Transactions*
    - u64 (8 bytes) each
    - The other transactions that were active when the snapshot was taken.
      There can be none.

Retained Version Object
-----------------------

When a transaction commits, it removes the versions of objects that it expired.
A version that a snapshot (see `Snapshot Object`_) can still see is kept
instead, and gets a Retained Version Object (has the ``G`` prefix). The key is
the ID of the transaction that expired the version as a u64, followed by the
key of the version. The value is the TID of the version as a u64.

When a ``REPEATABLE READ`` transaction ends, every version that no snapshot can
see anymore is removed, with its Retained Version Object.

Write-Ahead Log
---------------

The write-ahead log makes each statement that changes the database atomic and
durable. Even if the process stops (or the power fails) part way through, the
database contains either all or none of the changes made by the statement.

While a statement is running, the pages it changes are only kept in memory.
When it finishes (still holding the exclusive lock on the database file):

1. The changed pages and the new `Header`_ are added to the end of the log,
   which is synced to the disk (with ``fsync``). This is the point where the
   statement is committed.

2. The pages and header are copied into the database file and the file is
   truncated to the number of pages. The database file is **not** synced,
   because the log has everything that hasn't reached the disk. If this fails,
   the statement still succeeds (it has been committed), and the log is copied
   again before the file is next read.

3. The *State* in the log header is changed to *Checkpointed*, and the *Tail* is
   moved to the end of the statement. This doesn't need to be synced, see below.

A statement in an explicit transaction (after ``START TRANSACTION``) doesn't need
to survive the power failing, because the transaction would be rolled back
anyway. So the log isn't synced in step 1 if every page that the statement
changes is either:

- in a frame of the log that the connection has already synced, or
- a page that was added to the file since the connection last synced the log.

If the power fails, copying the log puts each of those pages back (or truncates
the file to remove them), so the database file is the same as it was after the
last statement that was synced. Any other statement (including the ``COMMIT``)
syncs the log, which also syncs the statements before it.

A new log is started (with a new *Salt*) when the statement wouldn't fit in the
4 MiB limit, unless the log is empty. The database file is synced first, because
the statements in the log are about to be lost. Then the new log header is
synced before any frames are written, otherwise frames from the new log could
replace some of the old ones while the old header is still on the disk, which
would look like a log containing only the oldest statements. A statement larger
than 4 MiB gets a log of its own.

The whole log is copied into the database file, the file is synced and the log
is emptied (with a *Tail* of 0) in these two cases:

- Before a connection reads or changes the database file, if the *State* isn't
  *Checkpointed*. This is when a process stopped during a statement. The file
  has been kept up to date otherwise, even if it hasn't reached the disk.

- When the first connection to the database file is opened, if the *Tail* is past
  the log header. This is because the power may have failed since the last
  connection, in which case any part of the changes that weren't synced may be
  missing from the database file, even if the log header says *Checkpointed*.

Reading the log stops at the first frame that isn't valid, so a statement without
a valid *Commit* frame is ignored, because it didn't change the database file.
Copying statements that are already in the database file doesn't change it,
because the log has every change since the file was last synced.

The log belongs to its database file while it has statements. When moving or
copying a database file, also move or copy the log. A database file that's
replaced with an older copy (such as a backup) must have the log deleted,
otherwise the log will be copied over it.

This is about the order that a statement is made permanent. Transactions (which
may contain many statements) are still made atomic with MVCC (see :doc:`mvcc`),
and a transaction that was left behind by a process that stopped is rolled back
by the next connection.

A statement (such as a ``COMMIT``) that changes more than one database file
(catalog) uses the log of each file. The pages are added to every log first,
and only then is the *Commit* frame added to each log in turn, so failing to
write the pages of any file leaves all of them unchanged. Each log is still
recovered on its own, so if adding a *Commit* frame fails (or the process stops)
after another file has been committed, that file keeps the changes and the rest
don't.

On Linux and Windows, syncing a file waits for the drive to write it to
permanent storage. On macOS, ``fsync`` only hands the data to the drive, which
may keep it in its cache for a while and write it in a different order. So, on
macOS by default:

- A statement that has been committed is never lost if the process stops (or
  crashes), because the operating system still has the changes.

- A statement that has been committed may be lost if the power fails or the
  operating system stops, and the database file may even be left corrupt,
  because the steps above may reach the disk in a different order.

The ``full_fsync`` connection option (``vsql bench -full-fsync``) syncs with
``fcntl(F_FULLFSYNC)`` instead, which also waits for the drive to write its
cache. It's off by default because it's much slower: ``vsql bench`` on a file
runs 7 to 15 times fewer TPC-B transactions per second on a Mac. It's accepted
on other systems, but doesn't change anything.

The log starts with a 32 byte header:

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Format
    - Description

  * - 0
    - *Magic*
    - 8 bytes
    - Always ``76 73 71 6c 77 61 6c 0a`` (``vsqlwal\n``).

  * - 8
    - *Version*
    - u16 (2 bytes)
    - The version of the log format, currently 2.

  * - 10
    - *State*
    - u8 (1 byte)
    - 0 (*Committed*) when a statement is being written, and 1 (*Checkpointed*)
      once it has been copied into the database file.

  * - 11
    - *Reserved*
    - 1 byte
    - Always 0.

  * - 12
    - *Page Size*
    - u32 (4 bytes)
    - The page size of the database.

  * - 16
    - *Salt*
    - u32 (4 bytes)
    - A random number that is the start of the chain of checksums. Each log
      uses a new salt, so that frames left over from a previous log are never
      valid.

  * - 20
    - *Tail*
    - u32 (4 bytes)
    - The position to write the next statement. 0 means the log is empty, and the
      next statement starts a new one. It's only used to add to the log. The log
      is always read from the start when it's recovered.

  * - 24
    - *Tail Checksum*
    - u32 (4 bytes)
    - The checksum of the frame before *Tail*, or the *Salt* if there isn't one.

  * - 28
    - *Checksum*
    - u32 (4 bytes)
    - The CRC-32 of the first 28 bytes, with the *State*, *Tail* and *Tail
      Checksum* as 0.

Followed by frames, each with a 16 byte header and then its data:

.. list-table::
  :header-rows: 1

  * - Offset
    - Part
    - Format
    - Description

  * - 0
    - *Kind*
    - u8 (1 byte)
    - 1 for a *Page* frame, or 2 for a *Commit* frame.

  * - 1
    - *Reserved*
    - 3 bytes
    - Always 0.

  * - 4
    - *Number*
    - u32 (4 bytes)
    - For a *Page* frame, the page number. For a *Commit* frame, the total
      number of pages in the database.

  * - 8
    - *Length*
    - u32 (4 bytes)
    - The length of the data. A *Page* frame contains a whole page. A *Commit*
      frame contains the whole `Header`_.

  * - 12
    - *Checksum*
    - u32 (4 bytes)
    - The CRC-32 of the previous checksum (the *Salt* for the first frame),
      the first 12 bytes of this frame and its data.

Frames are read until one is incomplete or has the wrong checksum, which is
where a process stopped while writing the log. Only the pages up to the last
*Commit* frame are used.

Notes
-----

.. [1] See ``default_connection_options()`` in
   https://github.com/elliotchance/vsql/blob/main/vsql/connection.v.

.. [2] This is used for transaction visibility. See :doc:`mvcc`.
