File Format
===========

.. contents::

Overview
--------

.. image:: img/file-format-layout.png

vsql stores the entire database (also known as the catalog) in a single file.
The default extension is ``.vsql``, although that is not required.

A second file, with the same name followed by ``.session``, is created next to
the database file. It is always empty and is only used for locking (see
:doc:`mvcc`). It can be deleted whenever there are no open connections to the
database.

A third file, with the same name followed by ``.wal``, is the `Write-Ahead
Log`_. It must not be deleted, because it may contain the only copy of a
statement that was committed when the process stopped.

The file must include a *Header*, followed by zero or more pages. That is, when
the database file is initially created it will only have a *Header* and zero
pages.

Every page must be the same size, but this is configurable. The page size cannot
be changed after the file is created (the page size is stored in the *Header*).

A page can be one of two types: leaf and non-leaf, and they may appear in any
order in the file. They may also be reordered or removed as the file expands and
contracts.

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
    - *Reserved*
    - 2000 bytes
    - Zero in this version of the file format. See `Compatibility`_.

Compatibility
-------------

The version of the file format that vsql reads and writes is 1. Before v1.0.0,
any change to the file format increases this version, and vsql will refuse to
open a file that uses an older version. You will need to recreate it.

From v1.0.0 the aim is that every version of vsql can open a file created by
an older version, and that most features don't need to change the file format
at all. The *Read Version* and *Write Version* in the `Header`_ work the same
way as the read and write versions of SQLite:

- If the *Read Version* is newer than the version of the file format that vsql
  supports, the file is refused. Some part of the file can't be understood.

- If the *Write Version* is newer, the file can be read but not changed. Any
  statement that changes the file returns a ``25006`` error. The file uses a
  feature that this version of vsql doesn't know how to keep correct, such as
  an index that wouldn't be updated when a row is inserted.

A new file has both set to the current version. A feature that needs a newer
version only raises them the first time it's used, so a file that never uses
the feature can still be read and changed by older versions of vsql.

These rules keep changes compatible:

1. The *Magic*, *Read Version* and *Write Version* never move, so that every
   version of vsql can check them.

2. New header fields go in the *Reserved* space, which is zero until a field is
   added. vsql writes the reserved space back exactly as it read it, so a field
   added by a newer version isn't lost when an older version changes the file.

3. Schema objects, such as tables, are stored as SQL (see `Schema Objects`_).
   Most features that add to a definition, such as ``DEFAULT`` or ``CHECK``,
   only need the SQL to be extended, rather than a new layout. An older version
   can't parse the new syntax, so using such a feature raises the *Read
   Version*.

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

.. image:: img/file-format-leaf-page.png

The *Page Header* has a *Kind* of ``0``.

The *Data* will contain zero or more objects. Although, zero objects is valid if
that were the case the page should be removed as part of the garbage collection.

Each `Object`_ may be variable length and can be any number of bytes so long as
the *Object* size is equal to or less than the (page size - 16). For objects that
cannot fit into a page, they are stored in as a `Blob Object`_ and referenced
from the *Object*.

Objects within a page are kept sorted by key and unused space is always located
after the used data. You should not assume that the unused portion is zeroed.

Non-leaf Page
-------------

.. image:: img/file-format-non-leaf-page.png

A non-leaf page share a lot of similarities with a `Leaf Page`_. However, the
Objects are pointers to Leaf pages. That is the *Value* within the *Object* is a
i32 that references the `Leaf Page`_ number.

Objects within a non-leaf page are ordered based on the objects *Key*. This is
important for scanning (such as range queries) to improve performance as the
*Key* itself is the first *Key* in the referenced `Leaf Page`_. Here is an
example of how a `Non-leaf Page`_ references a `Leaf Page`_:

.. image:: img/file-format-non-leaf-reference.png

It's also important to note that as the B-tree gets larger, there may be
multiple non-leaf pages that need to be traversed this way. The process will
always end with a leaf page. A parent of a non-leaf (which must also be a
non-leaf) uses the *Key* that points to the first *Key* in the child page.

Object
------

An Object may be any length, but this example uses an object of 230 bytes:

.. image:: img/file-format-object.png

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

Every object contains 23 bytes of metadata:

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

  * - *Ref*
    - u8 (1 byte)
    - When ``true``, the *Value* will be 5 bytes containing. See `Blob Object`_.

  * - *Key Len*
    - i16 (2 bytes)
    - The number of bytes in the proceeding *Key*.

Using this metadata we can say that the length of *Value* will be: (*Length* -
23 - *Key Length*).

Blob Object
-----------

When an object is added to the B-tree that is larger than half a page, it must
be split into *blob* (B) and *fragment* (F) objects. Half a page, rather than a
whole page, because two versions of the same key (such as the row before and
after an ``UPDATE`` that hasn't been committed yet) must always fit into the same
page, and that includes their blob and fragment objects.

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

Other types can't be used in a ``PRIMARY KEY`` yet. The encoding of any type
added later must also keep the order of the values, and must be self-delimiting
(the length can be worked out from the bytes themselves), so that the values of
each column in a ``PRIMARY KEY`` with more than one column can be put one after
another and still be in order.

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
    START WITH 10
    INCREMENT BY 5
    MINVALUE 10

The ``START WITH`` is the value that ``ALTER SEQUENCE ... RESTART`` goes back
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

Write-Ahead Log
---------------

The write-ahead log makes each statement that changes the database atomic and
durable. Even if the process stops (or the power fails) part way through, the
database contains either all or none of the changes made by the statement.

While a statement is running, the pages it changes are only kept in memory.
When it finishes (still holding the exclusive lock on the database file):

1. The changed pages and the new `Header`_ are written to the log, which is
   synced to the disk (with ``fsync``). This is the point where the statement is
   committed.

2. The pages and header are copied into the database file, the file is
   truncated to the number of pages, and it is synced to the disk. If this
   fails, the statement still succeeds (it has been committed), and the log is
   copied again before the file is next read.

3. The *State* in the log header is changed to *Checkpointed*. This doesn't
   need to be synced, because copying the log into the database file again
   doesn't change it.

Before a connection reads or changes the database file, it checks the *State*.
If the log hasn't been checkpointed, and ends with a valid *Commit* frame, the
pages and header in it are copied into the database file (step 2) first. A log
without a valid *Commit* frame is ignored, because the statement didn't change
the database file.

This is about the order that a statement is made permanent. Transactions (which
may contain many statements) are still made atomic with MVCC (see :doc:`mvcc`),
and a transaction that was left behind by a process that stopped is rolled back
by the next connection.

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
    - The version of the log format, currently 1.

  * - 10
    - *State*
    - u8 (1 byte)
    - 0 (*Committed*) when the log is written, and 1 (*Checkpointed*) once it
      has been copied into the database file.

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
    - *Reserved*
    - 8 bytes
    - Always 0.

  * - 28
    - *Checksum*
    - u32 (4 bytes)
    - The CRC-32 of the first 28 bytes, with the *State* as 0.

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
