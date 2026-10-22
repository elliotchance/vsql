Limitations
===========

These limits come from the design of vsql and the :doc:`file-format`. Some of
them (such as the maximum file size) are theoretical and have not been tested.

.. list-table::
  :header-rows: 1

  * - Description
    - Limit

  * - The maximum page size (when creating a new file)
    - 65535 bytes (64 KB)

  * - The maximum number of pages in a file
    - 2147483647 (~2.1 billion)

  * - The maximum number of transactions over the life of a file
    - 18446744073709551615 (~18 quintillion)

  * - The maximum number of transactions that are active at the same time
      (across all connections and processes)
    - 256

  * - The maximum file size (using the default page size)
    - 8 TB

  * - The maximum file size (using the maximum page size)
    - 128 TB

  * - The maximum size of a row
    - 2147483647 bytes (~2 GB)

  * - The maximum length of a name (such as a table or column)
    - 128 characters

  * - The types that can be used in a ``PRIMARY KEY``
    - ``SMALLINT``, ``INTEGER`` and ``BIGINT``

  * - The number of uncommitted versions of a row
    - 1 (another transaction that changes the same row gets a ``40001``
      serialization failure)
