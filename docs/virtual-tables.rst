Virtual Tables
==============

Virtual tables allow you to register tables that have their rows provided at the
time of a ``SELECT``:

.. code-block:: text

   db.register_virtual_table(
     'CREATE TABLE foo ( "num" INT, word VARCHAR (32) )',
     fn (mut t vsql.VirtualTable) ! {
       t.next_values([
         vsql.new_integer_value(1)
         vsql.new_varchar_value('hi')
       ])
   
       t.next_values([
         vsql.new_integer_value(2)
         vsql.new_varchar_value('there')
       ])
   
       t.done()
     }
   ) !
   
   result := db.query('SELECT * FROM foo') !
   for row in result {
     num := row.get_int('num') !
     word := row.get_string('WORD') !
     println('$num $word')
   }

The callback for the virtual table will be called repeatedly until ``t.done()``
is invoked, even if zero rows are provided in an iteration. All data will be
thrown away between subsequent ``SELECT`` operations.

Each row must have a value for each column. The values are converted to the
types of the columns, like an ``INSERT``, so a value that can't be (such as a
string that's too long) is an error when the table is read.

A virtual table can't have the same name as a table (or another virtual table),
and a table can't be created with the name of a virtual table. Both are an error
``42P07``.
