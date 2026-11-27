Build Functions
===============

.. contents::
   :local:
   :depth: 1

Build functions return how vsql was built. They're the same values as the
``BUILD`` items of ``SQL_IMPLEMENTATION_INFO`` (see :doc:`information-schema`),
the ``VSQL_BUILD`` variables of ``vsql version -v`` (see :doc:`cli`), and the
``build_*()`` functions of V, with the same names.

Each one takes no arguments (the parentheses are required) and returns a
``CHARACTER VARYING``. The value is fixed when vsql is compiled, but it changes
when vsql is upgraded, so they can't be in a ``CHECK`` constraint or a generated
column.

They're vsql extensions, flagged by ``V411`` (see :doc:`sql-flagging`).

BUILD_C_COMPILER
^^^^^^^^^^^^^^^^

.. code-block:: sql

   BUILD_C_COMPILER() CHARACTER VARYING

The C compiler that compiled vsql, such as ``clang``. It's the same as the ``BUILD C COMPILER`` item of ``SQL_IMPLEMENTATION_INFO``
and ``vsql.build_c_compiler()`` in V.

``BUILD_C_COMPILER`` is a vsql extension flagged by ``V411-06`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BUILD_C_COMPILER();
  -- COL1: clang

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: part of ``VERSION()``.
  - MySQL, SQLite, SQL Server and Oracle don't have one.

BUILD_COMMIT
^^^^^^^^^^^^

.. code-block:: sql

   BUILD_COMMIT() CHARACTER VARYING

The git commit of vsql that was released or built from (with ``make`` in a git
checkout), or ``NULL`` for any other build. It's the same as the ``BUILD COMMIT`` item of ``SQL_IMPLEMENTATION_INFO``
and ``vsql.build_commit()`` in V.

``BUILD_COMMIT`` is a vsql extension flagged by ``V411-02`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BUILD_COMMIT();
  -- COL1: 6b3d76f0a1c2e4d5b6a7f8091a2b3c4d5e6f7081

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - SQLite: ``SQLITE_SOURCE_ID()``, which also has the date.
  - PostgreSQL, MySQL, SQL Server and Oracle don't have one.

BUILD_DATE
^^^^^^^^^^

.. code-block:: sql

   BUILD_DATE() CHARACTER VARYING

The date (in UTC) that vsql was compiled, such as ``2026-11-12``, as
``YYYY-MM-DD``. Every build has one. For a release, it's the date of the
release. It can be cast to a ``DATE``. It's the same as the ``BUILD DATE`` item of ``SQL_IMPLEMENTATION_INFO``
and ``vsql.build_date()`` in V.

``BUILD_DATE`` is a vsql extension flagged by ``V411-03`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BUILD_DATE();
  -- COL1: 2026-11-12

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - SQLite: part of ``SQLITE_SOURCE_ID()``.
  - SQL Server: part of ``@@VERSION``.
  - PostgreSQL, MySQL and Oracle don't have one.

BUILD_V_COMMIT
^^^^^^^^^^^^^^

.. code-block:: sql

   BUILD_V_COMMIT() CHARACTER VARYING

The commit of the V compiler that compiled vsql, such as ``5634a1f``. It's the same as the ``BUILD V COMMIT`` item of ``SQL_IMPLEMENTATION_INFO``
and ``vsql.build_v_commit()`` in V.

``BUILD_V_COMMIT`` is a vsql extension flagged by ``V411-05`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BUILD_V_COMMIT();
  -- COL1: 5634a1f

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - The other databases aren't written in V.

BUILD_V_VERSION
^^^^^^^^^^^^^^^

.. code-block:: sql

   BUILD_V_VERSION() CHARACTER VARYING

The version of the V compiler that compiled vsql, such as ``0.5.2``. It's the same as the ``BUILD V VERSION`` item of ``SQL_IMPLEMENTATION_INFO``
and ``vsql.build_v_version()`` in V.

``BUILD_V_VERSION`` is a vsql extension flagged by ``V411-04`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BUILD_V_VERSION();
  -- COL1: 0.5.2

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - The other databases aren't written in V.

BUILD_VERSION
^^^^^^^^^^^^^

.. code-block:: sql

   BUILD_VERSION() CHARACTER VARYING

The release of vsql, such as ``v1.8.0``. A build with ``make`` in a git
checkout has the version from ``git describe``, such as ``v1.8.5-12-g1a2b3c4``
(12 commits after ``v1.8.5``), which ends in ``-dirty`` when there are changes
that aren't committed. It's ``NULL`` for any other build, such as one with
``v install``. It's the same as the ``BUILD VERSION`` item of ``SQL_IMPLEMENTATION_INFO``
and ``vsql.build_version()`` in V.

``BUILD_VERSION`` is a vsql extension flagged by ``V411-01`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BUILD_VERSION();
  -- COL1: v1.8.0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``VERSION()``, which also has the compiler. vsql has
    ``version()`` for PostgreSQL clients too (see :doc:`server`).
  - MySQL: ``VERSION()``.
  - SQLite: ``SQLITE_VERSION()``.
  - SQL Server: ``SERVERPROPERTY('ProductVersion')``.
  - Oracle: ``SELECT VERSION FROM PRODUCT_COMPONENT_VERSION``.
