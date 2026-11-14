SQL Compliance
==============

.. contents::

vsql aims to be SQL compliant by following the SQL standard (ISO/IEC 9075) in
both BNF syntax and mandatory features. The standard is split into parts, and
vsql follows three of them. Each has its own page:

.. list-table::
   :header-rows: 1

   * - Document
     - Defines
     - Mandatory features
     - Optional features

   * - :doc:`sql-compliance-9075-2`
     - The SQL language
     - 128 of 163
     - 96 of 408

   * - :doc:`sql-compliance-9075-3`
     - The C API
     - 0 of 1
     - None

   * - :doc:`sql-compliance-9075-11`
     - The tables that describe a database
     - 8 of 15
     - 1 of 24

The counts include subfeatures, and only count the ones that are fully
supported. Part 3 is the SQL:2003 working draft (2003-09) and Part 11 is the
SQL:2008 committee draft (2006-02).

.. toctree::
   :hidden:

   sql-compliance-9075-2.rst
   sql-compliance-9075-3.rst
   sql-compliance-9075-11.rst

Each part is pinned to one edition of the standard (see :doc:`standard-index`),
and each page only uses that edition: its feature IDs, feature names and table
numbers can be different in other editions. There are still many features to
be implemented before vsql can be considered fully compliant, as shown by the
mandatory features of each part.

Standard Index
--------------

The pages for each part are by feature. For the most detailed compliance notes, see
:doc:`standard-index`, which tracks every rule of every Subclause: whether it's
implemented, where, how it's tested, and the rules that don't apply or need a
closer look. A summary of it can be printed with:

.. code-block:: sh

  scripts/standard-index.py report      # each part
  scripts/standard-index.py report 2    # each clause of Part 2

For each part (or clause) it shows how many rules there are, how many of them
have been reviewed, and how many of the reviewed rules that apply to vsql are
implemented (a partially implemented rule counts as half). Then it lists the
rules that need attention: the ones that are missing (with their issue),
partially implemented, implemented without a test, deviate on purpose, or are
unclear. The rules that haven't been reviewed yet aren't counted as implemented
or missing, so the percentage implemented only describes what has been reviewed
so far.

See Also
--------

- `SQL compliance on Wikipedia <https://en.wikipedia.org/wiki/SQL_compliance>`_
