Limitations
===========

These have not been tested, but are based on fundamental design choices:

.. list-table::
  :header-rows: 1

  * - Description
    - Limit

  * - The maximum page size (when creating a new file)
    - 65536 bytes (64 KB)

  * - The maximum number of pages in a file
    - 2147483647 (~2.1 billion)

  * - The maximum file size (using the default page size)
    - 8 PB

  * - The maximum file size (using the maximum page size)
    - 128 PB

  * - The maximum object size (using the default page size)
    - 8 TB

  * - The maximum object size (using the maximum page size)
    - 128 TB
