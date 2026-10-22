Quick Start
===========

.. contents::

Run Some SQL
------------

Download ``vsql`` for macOS, Linux or Windows from the
`latest release <https://github.com/elliotchance/vsql/releases/latest>`_ and
unzip it (or see :doc:`install` for other ways to get it). Then open a
database, which creates the file if it doesn't exist:

.. code-block:: text

   $ vsql cli shop.vsql
   vsql> CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
   CREATE TABLE 1 (0 ms)

   vsql> INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);
   INSERT 2 (1 ms)

   vsql> SELECT * FROM products ORDER BY name;
   NAME   | PRICE
   -------+------
   Bagel  |  2.25
   Coffee |  4.50
   2 rows (1 ms)

   vsql> exit

Use ``:memory:`` instead of a file name for a database that only lives in
memory. See :doc:`cli` for the other commands, such as loading a file of SQL
with ``vsql in``.

A few things that might surprise you if you're used to another database, since
vsql follows the SQL standard:

- Names that aren't quoted are upper case, so ``products`` is ``PRODUCTS``.
- There's no ``LIMIT``. Use ``FETCH FIRST 10 ROWS ONLY``.
- A ``SELECT`` needs a ``FROM``. Use ``VALUES`` to try an expression, such as
  ``VALUES 1 + 2``.

See the :doc:`faq` for more.

Connect With a PostgreSQL Client
--------------------------------

Start the server:

.. code-block:: text

   $ vsql server shop.vsql
   ready on 127.0.0.1:3210

Then connect with any of the :doc:`postgresql-clients`, such as ``psql``:

.. code-block:: text

   $ psql -h 127.0.0.1 -p 3210 -c 'SELECT * FROM products'
     NAME  | PRICE
   --------+-------
    Coffee | 4.50
    Bagel  | 2.25
   (2 rows)

The server ignores the user name, password and database name. See
:doc:`server`.

Use It From V
-------------

Install the module:

.. code-block:: sh

   v install elliotchance.vsql

Then open a database and run SQL:

.. code-block:: text

   import elliotchance.vsql.vsql

   fn main() {
   	mut db := vsql.open('shop.vsql')!

   	db.query('CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2))')!
   	db.query("INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25)")!

   	mut stmt := db.prepare('SELECT name, price FROM products WHERE price < :max_price ORDER BY name')!
   	for row in stmt.query({
   		'max_price': vsql.new_numeric_value('3.00')
   	})! {
   		println('${row.get_string('NAME')!} costs ${row.get_string('PRICE')!}')
   	}
   }

This prints ``Bagel costs 2.25``. See :doc:`v-client-library`, or
:doc:`v-orm` to use V's built-in ORM.
