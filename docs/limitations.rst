Limitations
===========

.. contents::

These limits come from the design of vsql and the :doc:`file-format`. Some of
them (such as the maximum file size) are theoretical and have not been tested.

File
----

.. list-table::
  :header-rows: 1

  * - Description
    - Limit

  * - The default page size (when creating a new file)
    - 4096 bytes

  * - The maximum page size (when creating a new file)
    - 65535 bytes (64 KB)

  * - The maximum number of pages in a file
    - 2147483647 (~2.1 billion)

  * - The maximum file size (using the default page size)
    - 8 TB

  * - The maximum file size (using the maximum page size)
    - 128 TB

  * - The maximum size of a row
    - 2147483647 bytes (~2 GB)

  * - The maximum length of a schema or sequence name in the file
    - Its key must fit in a page, which only matters for a small page size
      (otherwise a ``54000`` error)

Database
--------

.. list-table::
  :header-rows: 1

  * - Description
    - Limit

  * - The maximum number of transactions over the life of a file
    - 18446744073709551615 (~18 quintillion)

  * - The maximum number of transactions that are active at the same time
      (across all connections and processes)
    - 256

  * - The number of uncommitted versions of a row
    - 1 (another transaction that changes the same row gets a ``40001``
      serialization failure)

  * - The maximum length of a name (such as a table or column)
    - 128 characters

  * - The maximum number of columns in a table
    - 1600 (otherwise a ``54000`` error)

Types
-----

A declared type that's larger than its limit, such as ``VARCHAR(10485761)`` in
``CREATE TABLE`` or ``CAST``, is a ``42601`` error. A value that doesn't fit in
its type is a ``22001`` (for text) or ``22003`` (for numbers) error.

.. list-table::
  :header-rows: 1

  * - Description
    - Limit

  * - The maximum length of a ``CHARACTER(n)`` or ``CHARACTER VARYING(n)``
      (see :doc:`text`)
    - 10485760 characters

  * - The maximum precision of a ``NUMERIC(p)`` or ``DECIMAL(p)``, which is also
      the precision of a ``NUMERIC`` or ``DECIMAL`` without one (see
      :doc:`numbers`)
    - 1000 digits

  * - The maximum number of digits in a numeric literal (not including leading
      zeros)
    - 1000

  * - The maximum precision of a ``FLOAT(p)``
    - 53

  * - The range of a ``SMALLINT``
    - -32768 to 32767

  * - The range of an ``INTEGER``
    - -2147483648 to 2147483647

  * - The range of a ``BIGINT``
    - -9223372036854775808 to 9223372036854775807

  * - The range of a ``REAL``
    - -3.4e+38 to 3.4e+38

  * - The range of a ``DOUBLE PRECISION``
    - -1.7e+308 to +1.7e+308

  * - The range of a ``DATE`` or ``TIMESTAMP`` (see :doc:`dates-times`)
    - ``0001-01-01`` to ``9999-12-31``

  * - The maximum fractional seconds precision of a ``TIME`` or ``TIMESTAMP``
    - 6 (microseconds)

  * - The range of a time zone
    - ``-14:00`` to ``+14:00``
