V Client Library
================

.. include:: snippets.rst

.. contents::

Install/Update
--------------

Install or update to the latest with:

.. code-block:: sh

   v install elliotchance.vsql

Example
-------

.. code-block:: text

   import elliotchance.vsql.vsql

   fn example() ! {
     mut db := vsql.open('test.vsql') !

     // All SQL commands use query():
     db.query('CREATE TABLE foo (x DOUBLE PRECISION)') !
     db.query('INSERT INTO foo (x) VALUES (1.23)') !
     db.query('INSERT INTO foo (x) VALUES (4.56)') !

     // Iterate through a result:
     result := db.query('SELECT * FROM foo') !
     println(result.columns)

     for row in result {
         println(row.get_f64('X') !)
     }

     // See SQLSTATE (Errors) below for more examples.
   }

Outputs:

.. code-block:: text

   ['A']
   1.23
   4.56

V Module
--------

enum Boolean
^^^^^^^^^^^^

|v.Boolean|

See definition in
`value.v <https://github.com/elliotchance/vsql/blob/main/vsql/value.v>`_.

fn Boolean.str() string
***********************

|v.Boolean.str|

struct Column
^^^^^^^^^^^^^

|v.Column|

name string
***********

|v.Column.name|

not_null bool
*************

|v.Column.not_null|

typ Type
********

|v.Column.typ|

fn Column.str() string
**********************

|v.Column.str|

struct Connection
^^^^^^^^^^^^^^^^^

|v.Connection|

fn open(path string) !&Connection
*********************************

|v.open|

fn open_database(path string, options ConnectionOptions) !&Connection
*********************************************************************

|v.open_database|

fn Connection.prepare(sql string) !PreparedStmt
***********************************************

|v.Connection.prepare|

fn Connection.query(sql string) !Result
***************************************

|v.Connection.query|

fn Connection.register_function(prototype string, func fn ([]Value) !Value) !
*****************************************************************************

|v.Connection.register_function|

fn Connection.register_virtual_table(create_table string, data VirtualTableProviderFn) !
****************************************************************************************

|v.Connection.register_virtual_table|

fn Connection.schemas() ![]Schema
*********************************

|v.Connection.schemas|

fn Connection.schema_tables(schema string) ![]Table
***************************************************

|v.Connection.schema_tables|

struct ConnectionOptions
^^^^^^^^^^^^^^^^^^^^^^^^

|v.ConnectionOptions|

mutex &sync.RwMutex
*******************

|v.ConnectionOptions.mutex|

now fn () (time.Time, i16)
**************************

|v.ConnectionOptions.now|

page_size int
*************

|v.ConnectionOptions.page_size|

query_cache &QueryCache
***********************

|v.ConnectionOptions.query_cache|

fn default_connection_options() ConnectionOptions
*************************************************

|v.default_connection_options|

struct PreparedStmt
^^^^^^^^^^^^^^^^^^^

fn PreparedStmt.query(params map[string]Value) !Result
******************************************************

|v.PreparedStmt.query|

struct QueryCache
^^^^^^^^^^^^^^^^^

new_query_cache() &QueryCache
*****************************

|v.new_query_cache|

struct Result
^^^^^^^^^^^^^

|v.Result|

columns []Column
****************

|v.Result.columns|

elapsed_exec time.Duration
**************************

|v.Result.elapsed_exec|

elapsed_parse time.Duration
***************************

|v.Result.elapsed_parse|

fn Result.next() ?Row
*********************

|v.Result.next|

struct Row
^^^^^^^^^^

|v.Row|

get_null(name string) !bool
***************************

|v.Row.get_null|

get_f64(name string) !f64
*************************

|v.Row.get_f64|

get_int(name string) !int
*************************

|v.Row.get_int|

get_string(name string) !string
*******************************

|v.Row.get_string|

get_bool(name string) !Boolean
******************************

|v.Row.get_bool|

get(name string) !Value
***********************

|v.Row.get|

struct Schema
^^^^^^^^^^^^^

|v.Schema|

name string
***********

|v.Schema.name|

fn Schema.str() string
**********************

|v.Schema.str|

struct SQLState
^^^^^^^^^^^^^^^

|v.SQLState|

fn sqlstate_from_int(code int) string
*************************************

|v.sqlstate_from_int|

fn sqlstate_to_int(code string) int
***********************************

|v.sqlstate_to_int|

fn SQLState.code() int
**********************

|v.SQLState.code|

fn SQLState.msg() string
************************

|v.SQLState.msg|

enum SQLType
^^^^^^^^^^^^

|v.SQLType|

See definition in
`type.v <https://github.com/elliotchance/vsql/blob/main/vsql/type.v>`_.

fn SQLType.str() string
***********************

|v.SQLType.str|

struct Table
^^^^^^^^^^^^

|v.Table|

columns Columns
***************

|v.Table.columns|

is_virtual bool
***************

|v.Table.is_virtual|

name string
***********

|v.Table.name|

primary_key []string
********************

|v.Table.primary_key|

fn Table.column(name string) !Column
************************************

|v.Table.column|

fn Table.column_names() []string
********************************

|v.Table.column_names|

fn Table.str() string
*********************

|v.Table.str|

struct Time
^^^^^^^^^^^

|v.Time|

t time.Time
***********

|v.Time.t|

typ Type
********

|v.Time.typ|

time_zone i16
*************

|v.Time.time_zone|

fn Time.str() string
********************

|v.Time.str|

struct Type
^^^^^^^^^^^

|v.Type|

not_null bool
*************

|v.Type.not_null|

size int
********

|v.Type.size|

fn Type.str() string
********************

|v.Type.str|

typ SQLType
***********

|v.Type.typ|

struct Value
^^^^^^^^^^^^

|v.Value|

is_null bool
************

|v.Value.is_null|

typ Type
********

|v.Value.typ|

fn new_bigint_value(x i64) Value
********************************

|v.new_bigint_value|

fn new_boolean_value(b bool) Value
**********************************

|v.new_boolean_value|

fn new_character_value(x string, size int) Value
************************************************

|v.new_character_value|

fn new_date_value(ts string) !Value
***********************************

|v.new_date_value|

fn new_double_precision_value(x f64) Value
******************************************

|v.new_double_precision_value|

fn new_integer_value(x int) Value
*********************************

|v.new_integer_value|

fn new_null_value(typ SQLType) Value
************************************

|v.new_null_value|

fn new_real_value(x f32) Value
******************************

|v.new_real_value|

fn new_smallint_value(x i16) Value
**********************************

|v.new_smallint_value|

fn new_time_value(ts string) !Value
***********************************

|v.new_time_value|

fn new_timestamp_value(ts string) !Value
****************************************

|v.new_timestamp_value|

fn new_unknown_value() Value
****************************

|v.new_unknown_value|

fn new_varchar_value(x string, size int) Value
**********************************************

|v.new_varchar_value|

fn Value.cmp(v2 Value) !(int, bool)
***********************************

|v.Value.cmp|

fn Value.str() string
*********************

|v.Value.str|

type VirtualTableProviderFn
^^^^^^^^^^^^^^^^^^^^^^^^^^^

|v.VirtualTableProviderFn|
