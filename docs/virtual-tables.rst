Virtual Tables
==============

Virtual tables allow you to register tables that have their rows provided at the
time of a ``SELECT``:

.. code-block:: text

   db.register_virtual_table(
     'CREATE TABLE foo ( "num" INT, word VARCHAR (32) )',
     fn (mut t vsql.VirtualTable) ! {
       t.next_values([
         vsql.new_double_precision_value(1)
         vsql.new_varchar_value("hi", 0)
       ])
   
       t.next_values([
         vsql.new_double_precision_value(2)
         vsql.new_varchar_value("there", 0)
       ])
   
       t.done()
     }
   ) !
   
   result := db.query('SELECT * FROM foo') !
   for row in result {
     num := row.get_f64('num') !
     word := row.get_string('WORD') !
     println('$num $word')
   }

The callback for the virtual table will be called repeatedly until ``t.done()``
is invoked, even if zero rows are provided in an iteration. All data will be
thrown away between subsequent ``SELECT`` operations.
