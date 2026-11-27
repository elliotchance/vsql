Language: V
===========

vsql is written in V, so a V program uses it directly as the ``vsql`` module,
with no other library or SDK. It can run SQL statements, or use V's built-in ORM
(see `ORM`_). This page explains the whole API, and every function and type is
listed in the reference at the end.

.. contents::

Requirements
------------

The V compiler (see `vlang.io <https://vlang.io>`_). vsql is built and tested
with the latest V, and older versions of V may not be able to compile it, so
update V first with ``v up``. macOS, Linux and Windows are supported.

Install/Update
--------------

Install or update to the latest with:

.. code-block:: sh

   v install elliotchance.vsql

Example
-------

Save this as ``main.v``:

.. code-block:: v

   import elliotchance.vsql.vsql

   fn main() {
   	mut db := vsql.open(':memory:')!
   	defer {
   		db.close()
   	}

   	db.query('CREATE TABLE products (id INTEGER, name VARCHAR(50))')!

   	mut insert := db.prepare('INSERT INTO products (id, name) VALUES (?, ?)')!
   	for i, name in ['Bolt', 'Nut'] {
   		insert.query({
   			'?1': vsql.new_integer_value(i + 1)
   			'?2': vsql.new_varchar_value(name)
   		})!
   	}

   	result := db.query('SELECT id, name FROM products ORDER BY id')!
   	for row in result {
   		println('${row.get_int('ID')!} ${row.get_string('NAME')!}')
   	}
   }

Then run it:

.. code-block:: sh

   v run main.v

Which prints:

.. code-block:: text

   1 Bolt
   2 Nut

More examples are in the
`examples directory <https://github.com/elliotchance/vsql/tree/main/examples>`_.

Using the API
-------------

The examples in the rest of this page use a ``shop.vsql`` file that's created by
the first one. Each example is a function that returns ``!``, so ``!`` passes any
error back to the caller.

Opening a Connection
^^^^^^^^^^^^^^^^^^^^

``vsql.open(path)`` opens a database file, and creates it if it doesn't exist.
The special path ``:memory:`` is a database that's only kept in memory, see
:doc:`in-memory-database`. ``vsql.open_database(path, options)`` is the same,
but with ``ConnectionOptions``, which should always start from
``vsql.default_connection_options()``:

.. code-block:: v

   import time
   import elliotchance.vsql.vsql

   fn open_example() ! {
   	mut options := vsql.default_connection_options()
   	options.cache_size = 10000
   	options.lock_timeout = 30 * time.second
   	options.isolation_level = .read_committed

   	mut db := vsql.open_database('shop.vsql', options)!
   	defer {
   		db.close()
   	}

   	result := db.query('CREATE TABLE products (id INTEGER PRIMARY KEY, name VARCHAR(50), price NUMERIC(5, 2), in_stock BOOLEAN)')!
   	println(result.msg)
   }

Outputs:

.. code-block:: text

   CREATE TABLE 1

``close()`` releases the files (and their locks) that the connection has open.
The last connection to a file also removes its write-ahead log, see
:doc:`file-format`. A connection must not be used after it's closed.

The options are:

.. list-table::
  :header-rows: 1

  * - Option
    - Default
    - Description

  * - ``page_size``
    - ``4096``
    - The size of each page in bytes, which must be more than 16 and at most
      65535. It's only used for a new file or a ``:memory:`` database, since a
      file always uses the page size it was created with.

  * - ``cache_size``
    - ``2000``
    - The number of pages of a file that are kept in memory (8 MiB with the
      default ``page_size``), so that a page that's used again doesn't need to
      be read from the file again. ``0`` doesn't keep any. The pages are kept
      for the next statement, unless another connection changed the file in
      between.

  * - ``lock_timeout``
    - 5 seconds
    - How long a ``SERIALIZABLE`` transaction (including a statement that changes
      the database outside of a transaction) waits for another connection's
      ``SERIALIZABLE`` transaction to finish, before it fails with ``40001``
      (serialization failure). See :doc:`transactions`.

  * - ``create_index_timeout``
    - 60 seconds
    - How long :doc:`create-index` waits for other transactions that have changed
      the table to finish, before it fails with ``55P03`` (lock not available).

  * - ``isolation_level``
    - ``.serializable``
    - The isolation level of a transaction that doesn't set one with
      :doc:`start-transaction` or :doc:`set-transaction` (including a statement
      outside of a transaction). It can be ``.read_uncommitted``,
      ``.read_committed``, ``.repeatable_read`` or ``.serializable``, see
      :doc:`transactions`.

  * - ``full_fsync``
    - ``false``
    - Only makes a difference on macOS, where a sync (``fsync``) hands the
      changes to the drive, but the drive may keep them in its cache for a
      while. If the power fails, committed statements can be lost, and the file
      can even be left corrupt. ``full_fsync`` uses ``F_FULLFSYNC``, which also
      waits for the drive to write its cache, but is much slower. On Linux and
      Windows it's accepted but does nothing.

  * - ``mutex``
    - A new ``sync.RwMutex``
    - Connections to the same file in the same process must share it, see
      `Threads`_.

Running Statements
^^^^^^^^^^^^^^^^^^

``query()`` runs one SQL statement and returns a ``Result``. A statement that
isn't inside a :doc:`start-transaction` runs in a transaction of its own, which
is committed when the statement finishes.

A ``Result`` has:

- ``columns``, the ``Column`` of each value in a row (even if there are no
  rows).
- ``msg``, the status of a statement that doesn't return rows, such as
  ``CREATE TABLE 1``, ``INSERT 3`` or ``DELETE 1``. It's empty for a query.
- ``elapsed_parse`` and ``elapsed_exec``, how long it took to parse and to run
  the statement.

The rows of a ``Result`` are read by iterating over it with ``for``.

Reading Rows
^^^^^^^^^^^^

A value of a row is read by the name of its column, which is in upper case
unless it was quoted (see
:doc:`identifiers`):

.. code-block:: v

   fn rows_example() ! {
   	mut db := vsql.open('shop.vsql')!
   	defer {
   		db.close()
   	}

   	db.query("INSERT INTO products VALUES (1, 'Bagel', 1.25, TRUE)")!
   	db.query("INSERT INTO products VALUES (2, 'Muffin', NULL, FALSE)")!

   	result := db.query('SELECT * FROM products ORDER BY id')!
   	for column in result.columns {
   		println(column)
   	}

   	for row in result {
   		id := row.get_int('ID')!
   		name := row.get_string('NAME')!
   		price := if row.get_null('PRICE')! { 'unknown' } else { row.get_string('PRICE')! }
   		in_stock := row.get_bool('IN_STOCK')! == .is_true
   		println('${id} ${name} ${price} ${in_stock}')
   	}
   }

Outputs:

.. code-block:: text

   "shop".PUBLIC.PRODUCTS.ID INTEGER NOT NULL
   "shop".PUBLIC.PRODUCTS.NAME CHARACTER VARYING(50)
   "shop".PUBLIC.PRODUCTS.PRICE NUMERIC(5, 2)
   "shop".PUBLIC.PRODUCTS.IN_STOCK BOOLEAN
   1 Bagel 1.25 true
   2 Muffin unknown false

.. list-table::
  :header-rows: 1

  * - Function
    - Description

  * - ``get_string(name)``
    - Any value as a string. ``NULL`` is
      ``NULL`` (or ``UNKNOWN`` for a ``BOOLEAN``), so use ``get_null`` to tell
      them apart.

  * - ``get_int(name)``
    - A ``SMALLINT``, ``INTEGER`` or ``BIGINT`` as an ``int``.

  * - ``get_f64(name)``
    - A ``REAL`` or ``DOUBLE PRECISION`` as an ``f64``.

  * - ``get_bool(name)``
    - A ``BOOLEAN`` as a ``vsql.Boolean``, which is ``.is_true`` or
      ``.is_false``.

  * - ``get_null(name)``
    - ``true`` if the value is ``NULL``. The other functions return ``0`` (or
      an empty string) for ``NULL``.

  * - ``get_lob(name)``
    - A reader for a string, see `Large Objects`_.

  * - ``get(name)``
    - The ``Value`` itself.

  * - ``get_column(column)``
    - The ``Value`` of a ``Column`` of the result, see below.

Each of them returns an error if there's no column with that name, or if the
value isn't of a type that the function can read (other than ``get_string``,
``get_null``, ``get`` and ``get_column``, which work for any type):

.. code-block:: v

   fn value_example() ! {
   	mut db := vsql.open('shop.vsql')!
   	defer {
   		db.close()
   	}

   	result := db.query('SELECT price, name FROM products WHERE id = 1')!
   	for row in result {
   		price := row.get('PRICE')!
   		println('${price.typ} ${price.is_null} ${price}')

   		row.get_int('NAME') or { println(err) }
   		row.get_string('name') or { println(err) }
   	}
   }

Outputs:

.. code-block:: text

   NUMERIC(5, 2) false 1.25
   cannot use get_int('NAME') when type is CHARACTER VARYING(50)
   no such column name, did you mean NAME?

A ``Value`` has its data type (``typ``), whether it's ``NULL`` (``is_null``),
and functions for its value, such as ``int_value()``, ``f64_value()``,
``string_value()``, ``bool_value()``, ``time_value()`` and
``numeric_value()``. ``str()`` is the same as ``get_string``. The ``new_*``
functions (such as ``vsql.new_integer_value(42)``) make a ``Value``, which is
what a prepared statement and a custom function (see :doc:`custom-functions`)
are given.

When a query has more than one column with the same name, use ``get_column``
with each of the ``columns`` of the result, since the name alone only finds one
of them:

.. code-block:: v

   fn same_name_example() ! {
   	mut db := vsql.open('shop.vsql')!
   	defer {
   		db.close()
   	}

   	result := db.query('SELECT a.name, b.name FROM products a JOIN products b ON a.id = b.id + 1')!
   	for row in result {
   		for column in result.columns {
   			println(row.get_column(column)!)
   		}
   	}
   }

Outputs:

.. code-block:: text

   Muffin
   Bagel

Large Objects
~~~~~~~~~~~~~

A long ``CHARACTER LARGE OBJECT`` or ``BINARY LARGE OBJECT`` is stored outside
of its row, and isn't read with the row (see :doc:`text` and :doc:`binary`).
``get_string`` reads all of it, but ``get_lob`` returns a ``Lob`` that only reads
the part that's asked for. ``len()`` is its length in octets, and
``read_at(offset, mut buf)`` reads the octets from ``offset`` into ``buf``, and
returns how many were read, which is less than ``buf.len`` at the end (and ``0``
after the end):

.. code-block:: v

   fn lob_example() ! {
   	mut db := vsql.open(':memory:')!
   	defer {
   		db.close()
   	}

   	db.query('CREATE TABLE documents (id INTEGER, body CLOB)')!
   	db.query("INSERT INTO documents VALUES (1, REPEAT('abcdefghij', 10000))")!

   	result := db.query('SELECT body FROM documents WHERE id = 1')!
   	for row in result {
   		lob := row.get_lob('BODY')!
   		println(lob.len())

   		mut buf := []u8{len: 4096}
   		mut offset := i64(0)
   		for {
   			n := lob.read_at(offset, mut buf)!
   			if n == 0 {
   				break
   			}
   			// Use buf[..n] here.
   			offset += n
   		}
   		println(offset)
   	}
   }

Outputs:

.. code-block:: text

   100000
   100000

Any character or binary string can be read with ``get_lob``, and a ``NULL`` has
a length of ``0``. A value that's stored outside of its row can be read until
the row is changed by another transaction that commits, or the connection is
closed.

Prepared Statements
^^^^^^^^^^^^^^^^^^^

``prepare()`` parses and checks a statement once, so it can be run many times
with a value for each dynamic parameter (``?``), named ``?1``, ``?2``, etc. See
:doc:`prepared-statements` for how the data type of each parameter is
determined. ``dynamic_parameter_count()`` and ``dynamic_parameter_type()`` (by
its position, starting at 1) describe the parameters, and the value that's given
is cast to that type:

.. code-block:: v

   fn prepare_example() ! {
   	mut db := vsql.open('shop.vsql')!
   	defer {
   		db.close()
   	}

   	mut stmt := db.prepare('SELECT name FROM products WHERE price < ?')!
   	println(stmt.dynamic_parameter_count())
   	if typ := stmt.dynamic_parameter_type(1) {
   		println(typ)
   	}

   	result := stmt.query({
   		'?1': vsql.new_varchar_value('2.00')
   	})!
   	for row in result {
   		println(row.get_string('NAME')!)
   	}
   }

Outputs:

.. code-block:: text

   1
   NUMERIC(5, 2)
   Bagel

Errors and Warnings
^^^^^^^^^^^^^^^^^^^

An error from vsql is an ``SQLState`` (see :doc:`errors-and-warnings` and
:doc:`sqlstate`). Its ``code()`` is
the SQLSTATE as an ``int``, which ``vsql.sqlstate_from_int`` turns back into the
five characters. Each SQLSTATE is also its own type, so it can be checked with
``is``. A warning doesn't stop the statement, so it's added to the connection's
``warnings`` instead. Only the most recent 100 are kept (or the ``DIAGNOSTICS
SIZE`` of the transaction), and they're never removed until
``clear_warnings()`` is called:

.. code-block:: v

   fn errors_example() ! {
   	mut db := vsql.open(':memory:')!
   	defer {
   		db.close()
   	}

   	db.query('SELECT * FROM missing') or {
   		println(vsql.sqlstate_from_int(err.code()))
   		println(err.msg())
   		if err is vsql.SQLState42P01 {
   			println('the table does not exist')
   		}
   	}

   	db.query("VALUES CAST('abcdef' AS VARCHAR(3))")!
   	for warning in db.warnings {
   		println('${vsql.sqlstate_from_int(warning.code())}: ${warning.msg()}')
   	}
   	db.clear_warnings()
   }

Outputs:

.. code-block:: text

   42P01
   no such table: ":memory:".PUBLIC.MISSING
   the table does not exist
   01004: string data, right truncation

Catalogs
^^^^^^^^

``catalog()`` is the current catalog (the database file, see
:doc:`set-catalog`). It can list its ``schemas()``, and the ``schema_tables()``,
``sequences()`` and ``indexes()`` of a schema:

.. code-block:: v

   fn catalog_example() ! {
   	mut db := vsql.open('shop.vsql')!
   	defer {
   		db.close()
   	}

   	mut catalog := db.catalog()
   	for schema in catalog.schemas()! {
   		println('${schema.name} ${schema.is_virtual}')
   	}
   	for table in catalog.schema_tables('PUBLIC')! {
   		println('${table.name} ${table.column_names()} ${table.primary_key}')
   	}
   }

Outputs:

.. code-block:: text

   PUBLIC false
   INFORMATION_SCHEMA true
   VSQL true
   "shop".PUBLIC.PRODUCTS ['ID', 'NAME', 'PRICE', 'IN_STOCK'] ['ID']

The same is in the :doc:`information-schema` views, which can be queried with
SQL.

``add_catalog(name, path, options)`` adds another database file to the
connection, as the catalog ``name``. The file must already exist (only
``vsql.open`` creates a new file), or be ``:memory:``. Every catalog is in the
same transaction. A table in another catalog is named with the catalog, which
must be quoted if it isn't in upper case, or the catalog can be selected with
:doc:`set-catalog`. ``current_catalog_name()`` is the current catalog:

.. code-block:: v

   fn add_catalog_example() ! {
   	mut archive := vsql.open('archive.vsql')!
   	archive.query('CREATE TABLE old_products (id INTEGER, name VARCHAR(50))')!
   	archive.close()

   	mut db := vsql.open('shop.vsql')!
   	defer {
   		db.close()
   	}

   	db.add_catalog('archive', 'archive.vsql', vsql.default_connection_options())!
   	println(db.current_catalog_name())

   	db.query('INSERT INTO "archive".public.old_products SELECT id, name FROM products')!

   	db.query("SET CATALOG 'archive'")!
   	result := db.query('SELECT COUNT(*) AS c FROM old_products')!
   	for row in result {
   		println(row.get_int('C')!)
   	}
   }

Outputs:

.. code-block:: text

   shop
   2

Adding a catalog with a name that's already used is an error ``42P04``.

Dumping a Database
^^^^^^^^^^^^^^^^^^

``dump(mut w, options)`` writes the schemas, sequences, tables and rows of the
current catalog as SQL to any ``io.Writer``, the same as ``vsql out`` (see
:doc:`cli`). Each option is the same as an option of ``vsql out``:

.. code-block:: v

   import os
   import strings

   fn dump_example() ! {
   	mut db := vsql.open('shop.vsql')!
   	defer {
   		db.close()
   	}

   	mut sb := strings.new_builder(1024)
   	db.dump(mut sb, include: ['public.products'], transaction: true)!
   	print(sb.str())

   	mut out := os.stdout()
   	db.dump(mut out, schema_only: true, compat: .sqlite3)!
   }

Outputs:

.. code-block:: text

   START TRANSACTION;

   CREATE TABLE "PUBLIC"."PRODUCTS" (
     "ID" INTEGER NOT NULL,
     "NAME" CHARACTER VARYING(50),
     "PRICE" NUMERIC(5, 2),
     "IN_STOCK" BOOLEAN,
     PRIMARY KEY ("ID")
   );

   INSERT INTO "PUBLIC"."PRODUCTS" ("ID", "NAME", "PRICE", "IN_STOCK") VALUES (1, 'Bagel', 1.25, TRUE);
   INSERT INTO "PUBLIC"."PRODUCTS" ("ID", "NAME", "PRICE", "IN_STOCK") VALUES (2, 'Muffin', NULL, FALSE);

   COMMIT;
   PRAGMA foreign_keys = OFF;

   CREATE TABLE "products" (
     "id" INTEGER NOT NULL,
     "name" CHARACTER VARYING(50),
     "price" NUMERIC(5, 2),
     "in_stock" BOOLEAN,
     PRIMARY KEY ("id")
   );

The ``DumpOptions`` are:

- ``include`` and ``exclude``: ``schema.name`` patterns (which can have the
  wildcards ``*`` and ``?``, ignoring case) of the objects to include or leave
  out. A pattern of ``include`` that doesn't match anything is an error.
- ``transaction``: puts ``START TRANSACTION`` and ``COMMIT`` around the output.
- ``data_only`` or ``schema_only``: only the rows (and the positions of the
  sequences), or only the definitions.
- ``no_schema``: leaves the schema out of every name.
- ``create_public_schema``: includes ``CREATE SCHEMA "PUBLIC"``.
- ``compat``: ``.vsql`` (the default), ``.sqlite3``, ``.mysql`` or
  ``.postgresql``, for the database that will load the output.

The output can be loaded into a new database by running each statement of
``vsql.split_statements(sql)``.

Threads
^^^^^^^

A connection must only be used by one thread at a time (other than
``cancel()``, see below). Each thread can open its own connection, but
connections to the same file in the same process must be given the same
``mutex``:

.. code-block:: v

   import sync

   fn threads_example() ! {
   	mut options := vsql.default_connection_options()
   	options.mutex = sync.new_rwmutex()

   	mut threads := []thread !{}
   	for i in 0 .. 4 {
   		threads << spawn fn (i int, options vsql.ConnectionOptions) ! {
   			mut db := vsql.open_database('shop.vsql', options)!
   			defer {
   				db.close()
   			}
   			db.query("INSERT INTO products VALUES (${i + 10}, 'Item ${i}', 2.50, TRUE)")!
   		}(i, options)
   	}
   	for t in threads {
   		t.wait()!
   	}
   }

Connections in different processes don't need anything, since they lock the
file itself. Each connection has its own transaction, see :doc:`transactions`.

Canceling a Statement
^^^^^^^^^^^^^^^^^^^^^

``cancel()`` asks the statement that's running on the connection to stop, and
is the only function that can be called from another thread while the
connection is in use. The statement fails soon after with ``57014`` (query
canceled), which leaves the database as it was before the statement, like any
other error. ``cancel()`` returns ``true`` if a statement was running. Nothing
happens if it isn't, so a statement that starts later isn't canceled:

.. code-block:: v

   fn cancel_example() ! {
   	mut db := vsql.open(':memory:')!
   	defer {
   		db.close()
   	}

   	db.query('CREATE TABLE n (x INTEGER)')!
   	for i in 0 .. 100 {
   		db.query('INSERT INTO n VALUES (${i})')!
   	}

   	t := spawn fn (db &vsql.Connection) {
   		time.sleep(100 * time.millisecond)
   		db.cancel()
   	}(db)

   	db.query('SELECT COUNT(*) FROM n a, n b, n c, n d') or {
   		println('${vsql.sqlstate_from_int(err.code())}: ${err.msg()}')
   	}
   	t.wait()
   }

Outputs:

.. code-block:: text

   57014: query canceled

Running a Server
^^^^^^^^^^^^^^^^

``vsql.new_server(options)`` makes a PostgreSQL-compatible server (see
:doc:`server`) inside a V program. ``start()`` listens and serves clients until
``stop()`` is called (from another thread). ``listen()`` and ``serve()`` do the
same in two steps, so that ``address()`` and ``port()`` can be read in between,
which is useful when the port is ``0`` (the default), which uses any free port:

.. code-block:: v

   fn server_example() ! {
   	mut server := vsql.new_server(db_file: 'shop.vsql', port: 3299)
   	server.listen()!
   	println('listening on ${server.address()!}')

   	t := spawn fn (mut server vsql.Server) ! {
   		server.serve()!
   	}(mut server)

   	// Clients can connect until stop() is called.
   	time.sleep(100 * time.millisecond)
   	server.stop()!
   	t.wait()!
   }

Outputs:

.. code-block:: text

   listening on 127.0.0.1:3299

Each client is served in its own thread, with its own connection. ``stop()``
stops accepting clients, but doesn't disconnect the clients that are already
connected. The ``ServerOptions`` are:

- ``db_file``: the file that's opened for each client.
- ``host``: the address to listen on, ``127.0.0.1`` by default (only clients on
  the same machine). ``0.0.0.0`` or ``::`` accept clients from other machines.
- ``port``: the port to listen on, or ``0`` for any free port.
- ``connect``: a function that opens the connection for each client, instead of
  ``db_file``. It's given the database name that the client connected with
  (which may be empty), and the server closes the connection when the client
  disconnects.
- ``select_without_from``, ``ignore_pg_set``, ``rewrite_pg_syntax`` and
  ``lower_case_names``: the things ``vsql server`` does for PostgreSQL
  clients, see :doc:`server`. They're all off by default.
- ``verbose``: prints every message to and from the server.

``connect`` can configure each connection, such as with a custom function. The
connections must share a ``mutex`` (see `Threads`_), which the server does for
itself when it opens ``db_file``:

.. code-block:: v

   fn server_connect_example() ! {
   	mut options := vsql.default_connection_options()
   	options.mutex = sync.new_rwmutex()

   	mut server := vsql.new_server(
   		connect: fn [options] (database string) !&vsql.Connection {
   			mut db := vsql.open_database('shop.vsql', options)!
   			db.register_function('double(x INTEGER) INTEGER', fn (_ vsql.FunctionContext, args []vsql.Value) !vsql.Value {
   				return vsql.new_integer_value(int(args[0].int_value() * 2))
   			})!
   			return db
   		}
   	)
   	server.start()!
   }

ORM
---

The ``vorm`` module is a driver for V's built-in ORM (``sql db { ... }``).

ORM Example
^^^^^^^^^^^

.. code-block:: v

   import elliotchance.vsql.vorm

   struct Product {
   	id    int @[primary; sql: serial]
   	name  string
   	price f64
   }

   fn example() ! {
   	mut db := vorm.open('test.vsql')!

   	sql db {
   		create table Product
   	}!

   	product := Product{
   		name:  'Bagel'
   		price: 1.25
   	}
   	sql db {
   		insert product into Product
   	}!

   	cheap_products := sql db {
   		select from Product where price < 3.0 order by name
   	}!
   	println(cheap_products)
   }

``db.conn`` is the ``vsql.Connection``, so ORM statements can be mixed with SQL
in the same connection (and transaction) with ``db.conn.query()``. An existing
connection can also be used with ``vorm.new()``:

.. code-block:: v

   mut conn := vsql.open('test.vsql')!
   mut db := vorm.new(conn)

See also
`examples/orm.v <https://github.com/elliotchance/vsql/blob/main/examples/orm.v>`_.

Tables and Columns
^^^^^^^^^^^^^^^^^^

Table and column names are always quoted, so they keep the same case as the ORM
uses (the ORM uses the struct name in lower case, unless you use
``@[table: 'name']``). Names that are reserved words in SQL, such as ``order``,
can be used. When you query an ORM table with SQL, remember to quote the names:

.. code-block:: sql

   SELECT "name", "price" FROM "product" WHERE "id" = 1

The V types are stored as:

.. list-table::
  :header-rows: 1

  * - V Type
    - SQL Type

  * - ``bool``
    - ``BOOLEAN``

  * - ``i8``, ``i16``, ``u8``
    - ``SMALLINT``

  * - ``int``, ``u16``, enums
    - ``INTEGER``

  * - ``i64``, ``u32``
    - ``BIGINT``

  * - ``u64``
    - ``NUMERIC(20)`` (since it can be larger than a ``BIGINT``)

  * - ``f32``
    - ``REAL``

  * - ``f64``
    - ``DOUBLE PRECISION``

  * - ``string``
    - ``CHARACTER VARYING(2048)``

  * - ``time.Time``
    - ``TIMESTAMP(6) WITHOUT TIME ZONE``

Fields that are not options are ``NOT NULL``. Values are converted to the type
of the column, so the V type of a field can be different to its SQL type, such
as a ``string`` that is stored as ``NUMERIC(5,2)``.

Attributes
^^^^^^^^^^

.. list-table::
  :header-rows: 1

  * - Attribute
    - Description

  * - ``@[table: 'name']``
    - On the struct, sets the table name.

  * - ``@[sql: 'name']``
    - Sets the column name.

  * - ``@[sql: i8]``
    - Uses the SQL type of a different V type (``SMALLINT`` in this case).

  * - ``@[sql_type: 'NUMERIC(5,2)']``
    - Sets the SQL type. Don't include ``NOT NULL``, it's added for fields that
      are not options.

  * - ``@[primary]``
    - Makes the field the ``PRIMARY KEY``.

  * - ``@[sql: serial]``
    - See `Serial Fields`_.

  * - ``@[unique]``
    - Adds a ``UNIQUE`` constraint for the field.

  * - ``@[unique: 'group']``
    - Adds one ``UNIQUE`` constraint for all of the fields in the group.

  * - ``@[unique_key: 'a, b']``
    - On the struct, adds a ``UNIQUE`` constraint for the fields.

  * - ``@[references]``
    - Adds a ``REFERENCES`` constraint. A field named ``parent_id`` references
      the ``id`` of the ``parent`` table. Use ``@[references: 'table']`` or
      ``@[references: 'table(field)']`` to name the table or field. The
      referenced table must be created first.

  * - ``@[default: 7]``
    - Sets the column default. The value is SQL, so it must be a literal,
      ``NULL``, or one of the values that vsql allows for a default, such as
      ``CURRENT_TIMESTAMP``. Put a string in backticks (``@[default:
      '`none`']``).

  * - ``@[skip]`` or ``@[sql: '-']``
    - The field is not stored.

Serial Fields
^^^^^^^^^^^^^

Each ``@[sql: serial]`` field gets a sequence called ``"<table>_<field>_seq"``
when the table is created. A row that is inserted with the field set to zero is
given the next value of the sequence. The sequence is dropped with the table.
The field isn't an identity column (see :ref:`create-table:Identity Columns`),
because the ORM gets the next value itself, so that it knows the value of each
row it inserts.

Where
^^^^^

A ``where`` can use ``==``, ``!=``, ``<``, ``<=``, ``>``, ``>=``, ``like``,
``ilike``, ``in``, ``!in``, ``is none`` and ``!is none``, combined with ``&&``,
``||`` and parentheses:

.. code-block:: v

   products := sql db {
   	select from Product where (price < 3.0 || name like 'Ice%') && id != 1
   }!

   ids := [1, 3]
   others := sql db {
   	select from Product where name ilike 'ice%' && id !in ids
   }!

``ilike`` is ``ILIKE``, which isn't standard SQL (see :ref:`expressions:ILIKE`).

Transactions
^^^^^^^^^^^^

``orm_begin()``, ``orm_commit()`` and ``orm_rollback()`` use ``START
TRANSACTION``, ``COMMIT`` and ``ROLLBACK``. ``orm_savepoint()``,
``orm_rollback_to()`` and ``orm_release_savepoint()`` use :doc:`savepoint`, which
is how nested transactions work.

Limitations
^^^^^^^^^^^

Indexes (``@[index]``) and comments (``@[comment]``) are ignored.

.. include:: v-client-library-docs.rst
