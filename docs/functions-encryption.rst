Encryption Functions
====================

.. contents::
   :local:
   :depth: 1

Encryption functions encrypt a value with a key, so that it can only be read
by someone who has the key. Only authenticated encryption is supported: data
that's decrypted with the wrong key, or that was changed after it was
encrypted, is a ``22V01`` error rather than garbage.

``ENCRYPT`` and ``DECRYPT`` work with binary strings (see :doc:`binary`), so
the encrypted data can be stored in a ``BINARY VARYING`` or ``BLOB`` column,
which is the smallest way to keep it. ``ENCRYPT_AES`` and ``DECRYPT_AES`` are
for text: the encrypted data is base64, which is the usual way to send it
somewhere as text, such as in JSON.

The encrypted data is a 12 octet nonce, then the ciphertext (the same length
as the value), then a 16 octet authentication tag, so it's 28 octets longer
than the value. It's the same layout that most other libraries use, so data
can be encrypted by vsql and decrypted by an application, or the other way
around.

.. note::

   The nonce of each encryption comes from the operating system's
   cryptographically secure random number generator, so the same value is
   encrypted differently each time, and a nonce is never reused by mistake.
   That's also why ``ENCRYPT`` and ``ENCRYPT_AES`` can't be in a ``CHECK``
   constraint.

   The key is a binary string of exactly the length of the method (16 or 32
   octets). It should be random, such as from ``openssl rand -hex 32``, and
   not a password. vsql doesn't store or manage keys. Pass the key as a
   parameter rather than writing it in the SQL, so that it isn't kept in the
   text of a statement, such as in a log.

   A value is encrypted all at once, so a large object is read into memory.

DECRYPT
^^^^^^^

.. code-block:: sql

   DECRYPT(BINARY VARYING, BINARY VARYING, CHARACTER VARYING) BINARY VARYING(10485760)
   DECRYPT(BINARY LARGE OBJECT, BINARY VARYING, CHARACTER VARYING) BINARY LARGE OBJECT

Decrypts the data of ``ENCRYPT`` with the key in the second argument and the
method in the third argument, the same ones that it was encrypted with. The
result is a binary string, even if a character string was encrypted, so it
can be compared to the octets of the original value, or decrypted as text
with ``DECRYPT_AES`` (for ``AES_256_GCM``).

A wrong key, a different method, or data that was changed (or that's too
short to have a nonce and tag) is a ``22V01`` error. A key that isn't the
length of the method, or a method that doesn't exist, is a ``22023`` error.

``DECRYPT`` is a vsql extension flagged by ``V409-02`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES DECRYPT(ENCRYPT(X'CAFE', X'000102030405060708090A0B0C0D0E0F', 'AES_128_GCM'),
    X'000102030405060708090A0B0C0D0E0F', 'AES_128_GCM');
  -- COL1: CAFE

  VALUES DECRYPT(ENCRYPT(X'CAFE', X'000102030405060708090A0B0C0D0E0F', 'AES_128_GCM'),
    X'FF0102030405060708090A0B0C0D0E0F', 'AES_128_GCM');
  -- error 22V01: decryption failed: wrong key or corrupt data

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``pgp_sym_decrypt_bytea`` (pgcrypto), which uses its own
    format, or ``decrypt``, which isn't authenticated.
  - MySQL: ``AES_DECRYPT``, which isn't authenticated, and returns ``NULL``
    for the wrong key.
  - SQL Server: ``DECRYPTBYKEY`` or ``DECRYPTBYPASSPHRASE``.
  - Oracle: ``DBMS_CRYPTO.DECRYPT``.
  - SQLite: none built in.

DECRYPT_AES
^^^^^^^^^^^

.. code-block:: sql

   DECRYPT_AES(CHARACTER VARYING, BINARY VARYING) CHARACTER VARYING
   DECRYPT_AES(CHARACTER LARGE OBJECT, BINARY VARYING) CHARACTER LARGE OBJECT

Decrypts the base64 text of ``ENCRYPT_AES`` with a 32 octet key, and returns
the original text. It's the same as ``DECRYPT(BASE64_TO_BINARY(text), key,
'AES_256_GCM')``, as text.

Text that isn't base64 is a ``22018`` error, and a value that isn't UTF-8
(because a binary string was encrypted) is a ``22021`` error. Otherwise, the
errors are the same as ``DECRYPT``.

``DECRYPT_AES`` is a vsql extension flagged by ``V409-04`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES DECRYPT_AES(ENCRYPT_AES('hello', X'000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F'),
    X'000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F');
  -- COL1: hello

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``pgp_sym_decrypt(dearmor(text), key)`` (pgcrypto).
  - MySQL: ``AES_DECRYPT(FROM_BASE64(text), key)``.
  - SQL Server, Oracle and SQLite: none built in.

ENCRYPT
^^^^^^^

.. code-block:: sql

   ENCRYPT(BINARY VARYING, BINARY VARYING, CHARACTER VARYING) BINARY VARYING(10485760)
   ENCRYPT(CHARACTER VARYING, BINARY VARYING, CHARACTER VARYING) BINARY VARYING(10485760)
   ENCRYPT(BINARY LARGE OBJECT, BINARY VARYING, CHARACTER VARYING) BINARY LARGE OBJECT
   ENCRYPT(CHARACTER LARGE OBJECT, BINARY VARYING, CHARACTER VARYING) BINARY LARGE OBJECT

Encrypts the first argument (a character string is encrypted as its UTF-8
octets) with the key in the second argument and the method in the third
argument (in upper or lower case):

.. list-table::
   :header-rows: 1

   * - Method
     - Key length (octets)

   * - ``AES_128_GCM``
     - 16
   * - ``AES_256_GCM``
     - 32
   * - ``CHACHA20_POLY1305``
     - 32

A key that isn't the length of the method, or a method that doesn't exist, is
a ``22023`` error. A result that's longer than 10485760 octets (the longest
``BINARY VARYING``) is a ``22001`` error.

``ENCRYPT`` is a vsql extension flagged by ``V409-01`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES OCTET_LENGTH(ENCRYPT(X'CAFE', X'000102030405060708090A0B0C0D0E0F', 'AES_128_GCM'));
  -- COL1: 30

  CREATE TABLE secrets (id INT, data VARBINARY(1000));
  INSERT INTO secrets VALUES (1, ENCRYPT('my secret', :key, 'AES_256_GCM'));

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``pgp_sym_encrypt_bytea`` (pgcrypto), which uses its own
    format, or ``encrypt``, which isn't authenticated.
  - MySQL: ``AES_ENCRYPT``, which isn't authenticated (it uses ECB mode by
    default).
  - SQL Server: ``ENCRYPTBYKEY`` or ``ENCRYPTBYPASSPHRASE``.
  - Oracle: ``DBMS_CRYPTO.ENCRYPT``.
  - SQLite: none built in.

ENCRYPT_AES
^^^^^^^^^^^

.. code-block:: sql

   ENCRYPT_AES(CHARACTER VARYING, BINARY VARYING) CHARACTER VARYING
   ENCRYPT_AES(CHARACTER LARGE OBJECT, BINARY VARYING) CHARACTER LARGE OBJECT

Encrypts text with ``AES_256_GCM`` and a 32 octet key, and returns the
encrypted data as base64. It's the same as ``BINARY_TO_BASE64(ENCRYPT(text,
key, 'AES_256_GCM'))``. ``DECRYPT_AES`` decrypts it.

A key that isn't 32 octets is a ``22023`` error. A result that's longer than
10485760 characters (the longest ``CHARACTER VARYING``) is a ``22001`` error.

``ENCRYPT_AES`` is a vsql extension flagged by ``V409-03`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES CHAR_LENGTH(ENCRYPT_AES('hello', X'000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F'));
  -- COL1: 44

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``armor(pgp_sym_encrypt(text, key))`` (pgcrypto).
  - MySQL: ``TO_BASE64(AES_ENCRYPT(text, key))``.
  - SQL Server, Oracle and SQLite: none built in.
