ORM
===

V provides an ORM with a simplified DSL influenced by both SQL and V to make it
easier and safer when dealing with common SQL database interactions. Since it's
part of the language there is nothing you need to install, however, you will
still need a database to interact with. These docs cover using V's ORM with
vsql.

You can find the
`official docs for the ORM here <https://modules.vlang.io/orm.html>`_.

.. contents::

Opening A Database
------------------

To open a database file, you have to use the ``open_orm`` function:

.. code-block:: text

  db := vsql.open_orm('test.vsql')

If the file does not exist it will be created. The connection is designed to
work with V's ORM. It is safe to use the underlying vsql connection as well:

.. code-block:: text

  db.connection().query('insert into ...')

Struct Definition
-----------------

Use a regular ``struct`` to define a row in a table:

.. code-block:: text

  struct Product {
    id           int
    product_name string
    price        f64
  }

The table name is derived from the name of the struct, ``Product`` in this case.
Each field has an assumed SQL type based on the V type, see *Types* below for
more information. The types and behaviors can also be customized with
*Attributes*.

Attributes
^^^^^^^^^^

Attributes can be used to customize SQL types and other behaviors:

.. code-block:: text

  @[table: 'products']
  struct Product {
    id           int    @[primary]
    product_name string
    price        string @[sql_type: 'NUMERIC(5,2)']
  }

.. list-table::
  :header-rows: 1

  * - Attribute Example
    - Description

  * -
      .. code-block:: text
        
        @[default: '123']

    - DEFAULT values are not supported in vsql. This will return an error.

  * -
      .. code-block:: text
        
        @[primary]

    - Defined the fields for the ``PRIMARY KEY``. Composite PRIMARY KEYs are not
      supported at this time.

  * -
      .. code-block:: text
        
        @[sql: serial]

    - Is a short-hand to declare this field as both the PRIMARY KEY and have an
      auto-incrementing value. This only works with integer types.

  * -
      .. code-block:: text
        
        @[sql: i8]

    - Using a type name for ``sql`` (notice that is not a string) will cause it
      to resolve a different SQL type from the V type, but based on the same
      rules. For example ``quantity int`` would use an ``INTEGER``, but
      ``quantity int @[sql: i8]`` would use a ``SMALLINT`` which is helpful if
      you would like in the struct types to be different from the underlying SQL
      types. You can fully customize the type with ``sql_type``.

  * -
      .. code-block:: text
        
        @[sql: 'custom_name']

    - Override the SQL field name. SQL expects that any non-quoted name is to be
      converted to uppercase. This means that the exact column name will be
      ``CUSTOM_NAME``. It is safe to use a reserved word (such as
      ``@[sql: 'where']``), it will be automatically quoted.

  * -
      .. code-block:: text
        
        @[sql: '\"custom_name\"']

    - Override the SQL field name as case sensitive, and prevent it from
      becoming ``CUSTOM_NAME``.

  * -
      .. code-block:: text
        
        @[sql_type: 'NUMERIC(5,2)']

    - Override the SQL type. Notice that this should not include any
      ``NOT NULL`` clause as that will be appended if needed based on if the
      field is optional.

  * -
      .. code-block:: text
        
        @[table: 'table_name']

    - Override the table name. This can only be attached to the struct and will
      be ignored on fields.

  * -
      .. code-block:: text
        
        @[unique]

    - UNIQUE indexes are not supported in vsql. This will return an error.

Types
^^^^^

When ``sql_type`` is not used, the SQL type is derived from field type.
Although, this can be overridden by using a type in the ``sql`` attribute, the
same behavior applies.

.. list-table::
  :header-rows: 1

  * - V type
    - SQL type

  * - ``bool``
    - ``BOOLEAN``

  * - ``i8``
    - ``SMALLINT``

  * - ``u8``
    - ``SMALLINT``

  * - ``i16``
    - ``SMALLINT``

  * - ``u16``
    - ``INTEGER``

  * - ``int``
    - ``INTEGER``

  * - ``i64``
    - ``BIGINT``

  * - ``u32``
    - ``BIGINT``

  * - ``u64``
    - ``NUMERIC(20)``

  * - ``f32``
    - ``REAL``

  * - ``f64``
    - ``DOUBLE PRECISION``

  * - ``string``
    - ``VARCHAR(2048)``. This length is chosen based on
      `orm.string_max_len <https://modules.vlang.io/orm.html#Constants>`_.

  * - ``time.Time``
    - ``TIMESTAMP WITH TIME ZONE``

  * - ``enum``
    - Enums are not currently supported. This will return an error.

All types will be ``NOT NULL`` unless the field is optional. See *NULLs*.

NULLs
^^^^^

All fields are ``NOT NULL`` unless the field is optional:

.. code-block:: text

  struct Product {
    product_name string // NOT NULL
    price        ?f64   // Allows NULL
  }

The ORM syntax uses V ``none`` keyword when dealing with NULLs:

.. code-block:: text

  product := Product{'Ham Sandwhich', none}
  sql db {
    insert product into Product
  }

  sql db {
    select from Product where price is none
  }

It's important to make the distinction between V requiring the field be set and
the NOT NULL constraint. For example:

.. code-block:: text

  product := Product{}
  sql db {
    insert product into Product
  }

Will not return an error because ``product_name`` is an empty string and not
``NULL``.

Creating Tables
---------------

You can create a table directly from the struct definition:

.. code-block:: text

  sql db {
    create table Product
  }!

The table name, column names and types will be extracted from the fields and
attributes.

Dropping Tables
---------------

To delete (drop) a table:

.. code-block:: text

	sql db {
		drop table Product
	}!

Manipulating Data
-----------------

Inserting
^^^^^^^^^

Insert data by passing an struct:

.. code-block:: text

  product := Product{1, 'Ice Cream', '5.99', 17}
  sql db {
    insert product into Product
  }!

Note: If a field is ``@[sql: serial]`` it will *always* be given the next value
from the sequence, even if the value for this field is provided.

Updating
^^^^^^^^

.. code-block:: text

  sql db {
    update Product set quantity = 16 where product_name == 'Ice Cream'
  }!

See *Expressions* for ``where``.

Deleting
^^^^^^^^

.. code-block:: text

  sql db {
    delete from Product where product_name == 'Ice Cream'
  }!

See *Expressions* for ``where``.

Last ID
^^^^^^^

Is not supported yet. Calling ``last_id()`` will always return ``0``.

Fetching Data
-------------

Retrieve all rows in a table by omitting the ``where`` clause:

.. code-block:: text

	rows := sql db {
		select from Product
	}!

  for row in rows {
    println(row)
  }

Or supply a ``where`` that may return zero or more rows:

.. code-block:: text

	rows := sql db {
		select from Product where price > 5
	}!

See *Expressions* for ``where``.

Expressions
-----------

The expressions syntax is designed to be as close to V syntax as possible:

.. code-block:: text

  products := sql db {
    select from Product where price < 3.47
  }!

Where ``price < 3.47`` is the expression.

The type of the right-hand side must be compatible with the field. So
``price < '3'`` (while ``'3'`` is still numeric) would result in a compiler
error.

.. list-table::
  :header-rows: 1

  * - Expression
    - SQL
    - Description

  * -
      .. code-block:: sql

        field == value

    -
      .. code-block:: sql
        
        field = value

    - Equal.

  * -
      .. code-block:: sql

        field != value

    -
      .. code-block:: sql
        
        field <> value

    - Not equal.

  * -
      .. code-block:: sql

        field > value

    -
      .. code-block:: sql
        
        field > value

    - Greater than.

  * -
      .. code-block:: sql

        field >= value

    -
      .. code-block:: sql
        
        field >= value

    - Greater than or equal.

  * -
      .. code-block:: sql

        field < value

    -
      .. code-block:: sql
        
        field < value

    - Less than.

  * -
      .. code-block:: sql

        field <= value

    -
      .. code-block:: sql
        
        field <= value

    - Less than or equal.

  * -
      .. code-block:: sql

        field like 'value'

    -
      .. code-block:: sql
        
        field LIKE 'value'

    - Basic regular expressions. These are case-sensitive.

  * -
      .. code-block:: sql

        field is none

    -
      .. code-block:: sql
        
        field IS NULL

    - Check for NULL. This is not the same as an empty value.

  * -
      .. code-block:: sql

        field !is none

    -
      .. code-block:: sql
        
        field IS NOT NULL

    - Check for NOT NULL. This is not the same as a non-empty value.
