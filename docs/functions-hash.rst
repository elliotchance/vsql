Hash Functions
==============

.. contents::
   :local:
   :depth: 1

Hash functions return a fixed-length digest of a value, so two values that are
equal have the same digest, but the value can't be worked out from it. They're
used to compare values without storing them, check that a value hasn't
changed, or interoperate with a system that stores digests.

``HASH`` returns the digest as a binary string. ``MD5``, ``SHA1``, ``SHA256``
and ``SHA512`` return it as lower case hexadecimal digits, which is how it's
usually written, so ``MD5(x)`` is the same as
``LOWER(BINARY_TO_HEX(HASH(x, 'MD5')))``.

Each function accepts a binary string (see :doc:`binary`) or a character
string, which is hashed as its UTF-8 octets. The padding of a ``CHARACTER(n)``
or ``BINARY(n)`` is hashed too, so ``MD5(CAST('abc' AS CHAR(5)))`` is the
digest of ``'abc  '``. They always return the same result for the same value,
so they can be in a ``CHECK`` constraint. A large object that's stored outside of its row is
read and hashed a few chunks at a time, so all of it is never in memory at
once.

.. note::

   ``MD5`` and ``SHA1`` are broken: two different values with the same digest
   can be made on purpose. They're fine for a checksum, or to match a system
   that uses them, but use ``SHA256`` or a newer method where that matters.
   None of the methods are suitable for storing passwords, which needs a slow
   hash with a salt.

HASH
^^^^

.. code-block:: sql

   HASH(BINARY VARYING, CHARACTER VARYING) BINARY VARYING(64)
   HASH(BINARY LARGE OBJECT, CHARACTER VARYING) BINARY VARYING(64)
   HASH(CHARACTER VARYING, CHARACTER VARYING) BINARY VARYING(64)
   HASH(CHARACTER LARGE OBJECT, CHARACTER VARYING) BINARY VARYING(64)

The digest of the first argument with the method in the second argument (in
upper or lower case). A method that isn't one of these is a ``22023`` error:

.. list-table::
   :header-rows: 1

   * - Method
     - Digest length (octets)

   * - ``MD5``
     - 16
   * - ``SHA1``
     - 20
   * - ``SHA224``
     - 28
   * - ``SHA256``
     - 32
   * - ``SHA384``
     - 48
   * - ``SHA512``
     - 64
   * - ``SHA3_224``
     - 28
   * - ``SHA3_256``
     - 32
   * - ``SHA3_384``
     - 48
   * - ``SHA3_512``
     - 64
   * - ``BLAKE2B_256``
     - 32
   * - ``BLAKE2B_512``
     - 64
   * - ``BLAKE2S_256``
     - 32
   * - ``BLAKE3``
     - 32
   * - ``RIPEMD160``
     - 20

``HASH`` is a vsql extension flagged by ``V408-01`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES HASH(X'CAFE', 'SHA256');
  -- COL1: 03346F0E7990DE2423A3BCA5335BF92CDC0BD14BEF2206B87C63F18A1E996C52

  VALUES HASH('abc', 'sha1');
  -- COL1: A9993E364706816ABA3E25717850C26C9CD0D89D

  VALUES HASH('abc', 'SHA-256');
  -- error 22023: invalid parameter value: HASH: SHA-256 is not a hash method

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``DIGEST(value, 'sha256')`` (pgcrypto), or ``SHA256``.
  - MySQL: ``UNHEX(SHA2(value, 256))``.
  - SQL Server: ``HASHBYTES('SHA2_256', value)``.
  - Oracle: ``STANDARD_HASH(value, 'SHA256')``.
  - SQLite: none built in.

MD5
^^^

.. code-block:: sql

   MD5(BINARY VARYING) CHARACTER(32)
   MD5(BINARY LARGE OBJECT) CHARACTER(32)
   MD5(CHARACTER VARYING) CHARACTER(32)
   MD5(CHARACTER LARGE OBJECT) CHARACTER(32)

The MD5 digest, as 32 lower case hexadecimal digits.

``MD5`` is a vsql extension flagged by ``V408-02`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES MD5('abc');
  -- COL1: 900150983cd24fb0d6963f7d28e17f72

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL and MySQL: ``MD5``.
  - SQL Server: ``LOWER(CONVERT(CHAR(32), HASHBYTES('MD5', value), 2))``.
  - Oracle: ``LOWER(STANDARD_HASH(value, 'MD5'))``.
  - SQLite: none built in.

SHA1
^^^^

.. code-block:: sql

   SHA1(BINARY VARYING) CHARACTER(40)
   SHA1(BINARY LARGE OBJECT) CHARACTER(40)
   SHA1(CHARACTER VARYING) CHARACTER(40)
   SHA1(CHARACTER LARGE OBJECT) CHARACTER(40)

The SHA-1 digest, as 40 lower case hexadecimal digits.

``SHA1`` is a vsql extension flagged by ``V408-03`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES SHA1('abc');
  -- COL1: a9993e364706816aba3e25717850c26c9cd0d89d

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL: ``SHA1``.
  - PostgreSQL: ``ENCODE(DIGEST(value, 'sha1'), 'hex')`` (pgcrypto).
  - SQL Server: ``LOWER(CONVERT(CHAR(40), HASHBYTES('SHA1', value), 2))``.
  - Oracle: ``LOWER(STANDARD_HASH(value, 'SHA1'))``.
  - SQLite: none built in.

SHA256
^^^^^^

.. code-block:: sql

   SHA256(BINARY VARYING) CHARACTER(64)
   SHA256(BINARY LARGE OBJECT) CHARACTER(64)
   SHA256(CHARACTER VARYING) CHARACTER(64)
   SHA256(CHARACTER LARGE OBJECT) CHARACTER(64)

The SHA-256 digest, as 64 lower case hexadecimal digits.

``SHA256`` is a vsql extension flagged by ``V408-04`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES SHA256('abc');
  -- COL1: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL: ``SHA2(value, 256)``.
  - PostgreSQL: ``ENCODE(SHA256(value), 'hex')``.
  - SQL Server: ``LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', value), 2))``.
  - Oracle: ``LOWER(STANDARD_HASH(value, 'SHA256'))``.
  - SQLite: none built in.

SHA512
^^^^^^

.. code-block:: sql

   SHA512(BINARY VARYING) CHARACTER(128)
   SHA512(BINARY LARGE OBJECT) CHARACTER(128)
   SHA512(CHARACTER VARYING) CHARACTER(128)
   SHA512(CHARACTER LARGE OBJECT) CHARACTER(128)

The SHA-512 digest, as 128 lower case hexadecimal digits.

``SHA512`` is a vsql extension flagged by ``V408-05`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES SHA512('abc');
  -- COL1: ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL: ``SHA2(value, 512)``.
  - PostgreSQL: ``ENCODE(SHA512(value), 'hex')``.
  - SQL Server: ``LOWER(CONVERT(CHAR(128), HASHBYTES('SHA2_512', value), 2))``.
  - Oracle: ``LOWER(STANDARD_HASH(value, 'SHA512'))``.
  - SQLite: none built in.
