.. |br| raw:: html

   <br>

.. |v.Boolean| replace::
   Possible values for a BOOLEAN.

.. |v.Boolean.str| replace::
   Returns ``TRUE``, ``FALSE`` or ``UNKNOWN``.

.. |v.Column| replace::
   A column definition.

.. |v.Column.current_value| replace::
   current_value is the current value before it is incremented by
   "NEXT VALUE FOR".

.. |v.Column.cycle| replace::
   cycle allows the sequence to repeat once MAXVALUE is reached. By default it
   is not enabled.

.. |v.Column.has_max_value| replace::
   has_max_value is true when a MAXVALUE is set.

.. |v.Column.has_min_value| replace::
   has_min_value is true when a MINVALUE is set.

.. |v.Column.increment_by| replace::
   increment_by is added for each next value and defaults to 1.

.. |v.Column.max_value| replace::
   max_value is the largest inclusive value allowed for the sequence. The
   MAXVALUE is optional.

.. |v.Column.min_value| replace::
   min_value is the smallest inclusive value allowed for the sequence. The
   MINVALUE is optional.

.. |v.Column.name| replace::
   name resolves to the actual canonical location. If you only need the column
   name itself, you can use name.sub_entity_name.

.. |v.Column.not_null| replace::
   not_null will be true if ``NOT NULL`` was specified on the column.

.. |v.Column.str| replace::
   str returns the column definition like:
   |br| |br|
   "foo" INT
   BAR DOUBLE PRECISION NOT NULL

.. |v.Column.typ| replace::
   typ of the column contains more specifics like size and precision.

.. |v.Connection| replace::
   A Connection allows querying and other introspection for a database file. Use
   open() or open_database() to create a Connection.

.. |v.Connection.prepare| replace::
   prepare returns a precompiled statement that can be executed multiple times
   with different provided parameters.

.. |v.Connection.query| replace::
   query executes a statement. If there is a result set it will be returned.

.. |v.Connection.register_function| replace::
   register_function will register a function that can be used in SQL
   expressions.

.. |v.Connection.register_virtual_table| replace::
   register_virtual_table will register a function that can provide data at
   runtime to a virtual table.

.. |v.Connection.schema_tables| replace::
   schema_tables returns tables for the provided schema. If the schema does not
   exist and empty list will be returned.

.. |v.Connection.schemas| replace::
   schemas returns the schemas in this catalog (database).

.. |v.ConnectionOptions| replace::
   ConnectionOptions can modify the behavior of a connection when it is opened.
   You should not create the ConnectionOptions instance manually. Instead, use
   default_connection_options() as a starting point and modify the attributes.

.. |v.ConnectionOptions.mutex| replace::
   In short, vsql (with default options) when dealing with concurrent
   read/write access to single file provides the following protections:
   |br| |br|
   - Fine: Multiple processes open() the same file.
   |br| |br|
   - Fine: Multiple goroutines sharing an open() on the same file.
   |br| |br|
   - Bad: Multiple goroutines open() the same file.
   |br| |br|
   The mutex option will protect against the third Bad case if you
   provide the same mutex instance to all open() calls:
   |br| |br|
   mutex := sync.new_rwmutex() // only create one of these
   |br| |br|
   mut options := default_connection_options()
   options.mutex = mutex
   |br| |br|
   Since locking all database isn't ideal. You could provide a consistent
   RwMutex that belongs to each file - such as from a map.

.. |v.ConnectionOptions.now| replace::
   now allows you to override the wall clock that is used. The Time must be
   in UTC with a separate offset for the current local timezone (in positive
   or negative minutes).

.. |v.ConnectionOptions.page_size| replace::
   Warning: This only works for :memory: databases. Configuring it for
   file-based databases will either be ignored or causes crashes.

.. |v.ConnectionOptions.query_cache| replace::
   query_cache contains the precompiled prepared statements that can be
   reused. This makes execution much faster as parsing the SQL is extremely
   expensive.
   |br| |br|
   By default each connection will be given its own query cache. However,
   you can safely share a single cache over multiple connections and you are
   encouraged to do so.

.. |v.Identifier| replace::
   Identifier is used to describe a object within a schema (such as a table
   name) or a property of an object (like a column name of a table). You should
   not instantiate this directly, instead use the appropriate new_*_identifier()
   function.
   |br| |br|
   If you need the fully qualified (canonical) form of an identified you can use
   Connection.resolve_schema_identifier().

.. |v.PreparedStmt| replace::
   A prepared statement is compiled and validated, but not executed. It can then
   be executed with a set of host parameters to be substituted into the
   statement. Each invocation requires all host parameters to be passed in.

.. |v.PreparedStmt.query| replace::
   Execute the prepared statement.

.. |v.QueryCache| replace::
   A QueryCache improves the performance of parsing by caching previously cached
   statements. By default, a new QueryCache is created for each Connection.
   However, you can share a single QueryCache safely amung multiple connections
   for even better performance. See ConnectionOptions.

.. |v.Result| replace::
   A Result contains zero or more rows returned from a query.
   |br| |br|
   See next() for an example on iterating rows in a Result.

.. |v.Result.columns| replace::
   The columns provided for each row (even if there are zero rows.)

.. |v.Result.elapsed_exec| replace::
   The time is took to execute the query.

.. |v.Result.elapsed_parse| replace::
   The time it took to parse/compile the query before running it.

.. |v.Result.next| replace::
   next provides the iteration for V, use it like:
   |br| |br|
   for row in result { }

.. |v.Row| replace::
   Represents a single row which may contain one or more columns.

.. |v.Row.get| replace::
   get returns the underlying Value. It will return an error if the column does
   not exist.

.. |v.Row.get_bool| replace::
   get_bool only works on a BOOLEAN value. If the column permits NULL values it
   will be represented as UNKNOWN.
   |br| |br|
   An error is returned if the type is not a BOOLEAN or the column name does not
   exist.

.. |v.Row.get_f64| replace::
   get_f64 will only work for columns that are numerical (DOUBLE PRECISION,
   FLOAT, REAL, etc). If the value is NULL, 0 will be returned. See get_null().

.. |v.Row.get_int| replace::
   get_int will only work for columns that are integers (SMALLINT, INTEGER or
   BIGINT). If the value is NULL, 0 will be returned. See get_null().

.. |v.Row.get_null| replace::
   get_null will return true if the column name is NULL. An error will be
   returned if the column does not exist.

.. |v.Row.get_string| replace::
   get_string is the most flexible getter and will try to coerce the value
   (including non-strings like numbers, booleans, NULL, etc) into some kind of
   string.
   |br| |br|
   An error is only returned if the column does not exist.

.. |v.SQLState| replace::
   SQLState is a compatible V error. It contains a human-readable message and'
   the SQLSTATE code.

.. |v.SQLState.code| replace::
   Is the integer representation of the SQLSTATE. Convert to a string with
   sqlstate_from_int.

.. |v.SQLState.msg| replace::
   Provides the human-readable message.

.. |v.SQLType| replace::
   Represents the fundamental SQL type.

.. |v.SQLType.str| replace::
   The SQL representation, such as ``TIME WITHOUT TIME ZONE``.

.. |v.Schema| replace::
   Represents a schema.

.. |v.Schema.name| replace::
   The name of the schema is case-sensitive.

.. |v.Schema.str| replace::
   Returns the CREATE SCHEMA statement for this schema, including the ';'.

.. |v.Sequence| replace::
   A SEQUENCE definition.

.. |v.Sequence.name| replace::
   name contains the other parts such as the schema.

.. |v.Sequence.str| replace::
   str returns the CREATE SEQUENCE definition (including the ';') like:
   |br| |br|
   CREATE SEQUENCE "foo" START WITH 12 NO MINVALUE NO MAXVALUE;

.. |v.Table| replace::
   Represents the structure of a table.

.. |v.Table.column| replace::
   Find a column by name, or return a SQLSTATE 42703 error.

.. |v.Table.column_names| replace::
   Convenience method for returning the ordered list of column names.

.. |v.Table.columns| replace::
   The column definitions for the table.

.. |v.Table.is_virtual| replace::
   When the table is virtual it is not persisted to disk.

.. |v.Table.name| replace::
   The name of the table including the schema.

.. |v.Table.primary_key| replace::
   If the table has a PRIMARY KEY defined the column (or columns) will be
   defined here in order.

.. |v.Table.str| replace::
   Returns the CREATE TABLE statement, including the ';'.

.. |v.Time| replace::
   Time is the internal way that time is represented and provides other
   conversions such as to/from storage and to/from V's native time.Time.

.. |v.Time.str| replace::
   Returns the Time formatted based on its type.

.. |v.Time.t| replace::
   Internal V time represenation.

.. |v.Time.time_zone| replace::
   Number of minutes from 00:00 (positive or negative)

.. |v.Time.typ| replace::
   typ.size is the precision (0 to 6)

.. |v.Type| replace::
   Represents a fully-qualified SQL type.

.. |v.Type.not_null| replace::
   Is NOT NULL?

.. |v.Type.size| replace::
   The size specified for the type.

.. |v.Type.str| replace::
   The SQL representation, such as ``TIME(3) WITHOUT TIME ZONE``.

.. |v.Type.typ| replace::
   Base SQL type.

.. |v.Value| replace::
   A single value. It contains it's type information in ``typ``.

.. |v.Value.cmp| replace::
   cmp returns for the first argument:
   |br| |br|
   -1 if v < v2
   0 if v == v2
   1 if v > v2
   |br| |br|
   The SQL standard doesn't define if NULLs should be always ordered first or
   last. In vsql, NULLs are always considered to be less than any other non-null
   value. The second return value will be true if either value is NULL.
   |br| |br|
   Or an error if the values are different types (cannot be compared).

.. |v.Value.is_null| replace::
   Used by all types (including those that have NULL built in like BOOLEAN).

.. |v.Value.str| replace::
   The string representation of this value. Different types will have different
   formatting.

.. |v.Value.typ| replace::
   TODO(elliotchance): Make these non-mutable.
   The type of this Value.

.. |v.VirtualTableProviderFn| replace::
   A function than will provide rows to a virtual table.

.. |v.default_connection_options| replace::
   default_connection_options returns the sensible defaults used by open() and
   the correct base to provide your own option overrides. See ConnectionOptions.

.. |v.new_bigint_value| replace::
   new_bigint_value creates a ``BIGINT`` value.

.. |v.new_boolean_value| replace::
   new_boolean_value creates a ``TRUE`` or ``FALSE`` value. For ``UNKNOWN`` (the
   ``BOOLEAN`` equivilent of NULL) you will need to use ``new_unknown_value``.

.. |v.new_character_value| replace::
   new_character_value creates a ``CHARACTER`` value. The value will be padded
   with spaces up to the size specified.

.. |v.new_date_value| replace::
   new_date_value creates a ``DATE`` value.

.. |v.new_double_precision_value| replace::
   new_double_precision_value creates a ``DOUBLE PRECISION`` value.

.. |v.new_integer_value| replace::
   new_integer_value creates an ``INTEGER`` value.

.. |v.new_null_value| replace::
   new_null_value creates a NULL value of a specific type. In SQL, all NULL
   values need to have a type.

.. |v.new_query_cache| replace::
   Create a new query cache.

.. |v.new_real_value| replace::
   new_real_value creates a ``REAL`` value.

.. |v.new_smallint_value| replace::
   new_smallint_value creates a ``SMALLINT`` value.

.. |v.new_time_value| replace::
   new_time_value creates a ``TIME`` value.

.. |v.new_timestamp_value| replace::
   new_timestamp_value creates a ``TIMESTAMP`` value.

.. |v.new_unknown_value| replace::
   new_unknown_value returns an ``UNKNOWN`` value. This is the ``NULL``
   representation of ``BOOLEAN``.

.. |v.new_varchar_value| replace::
   new_varchar_value creates a ``CHARACTER VARYING`` value.

.. |v.open| replace::
   open is the convenience function for open_database() with default options.

.. |v.open_database| replace::
   open_database will open an existing database file or create a new file if the
   path does not exist.
   |br| |br|
   If the file does exist, open_database will assume that the file is a valid
   database file (not corrupt). Otherwise unexpected behavior or even a crash
   may occur.
   |br| |br|
   The special file name ":memory:" can be used to create an entirely in-memory
   database. This will be faster but all data will be lost when the connection
   is closed.
   |br| |br|
   open_database can be used concurrently for reading and writing to the same
   file and provides the following default protections:
   |br| |br|
   - Fine: Multiple processes open_database() the same file.
   |br| |br|
   - Fine: Multiple goroutines sharing an open_database() on the same file.
   |br| |br|
   - Bad: Multiple goroutines open_database() the same file.
   |br| |br|
   See ConnectionOptions and default_connection_options().

.. |v.sqlstate_from_int| replace::
   sqlstate_from_int performs the inverse operation of sqlstate_to_int.

.. |v.sqlstate_to_int| replace::
   sqlstate_to_int converts the 5 character SQLSTATE code (such as "42P01") into
   an integer representation. The returned value can be converted back to its
   respective string by using sqlstate_from_int().
   |br| |br|
   If code is invalid the result will be unexpected.

