Language: Node.js
=================

`vsql-node <https://github.com/elliotchance/vsql-node>`_ is a Node.js driver.
It's built on libvsql (see :doc:`language-c`), which is compiled into the
package, so there's nothing else to install.

The API is synchronous, like ``node:sqlite`` and better-sqlite3: each call runs
vsql on the calling thread, and returns when it's finished. The database is the
path of the file (it's created if it doesn't exist), or ``:memory:`` for a
database that only exists for the life of the connection. Each row is an object
keyed by the column names, which vsql uppercases unless they're quoted. The
repository's README describes the whole API and the JavaScript type of each SQL
type.

.. contents::

Requirements
------------

Node 22 or later. The addon is prebuilt for macOS (ARM64 and x86-64), Linux
(ARM64 and x86-64, with glibc 2.29 or later) and Windows (x86-64), so npm
doesn't need to compile anything. Otherwise (such as with musl, on Alpine),
it's compiled when it's installed, which needs Python and a C compiler.

Example
-------

Create a project and install the package from npm:

.. code-block:: sh

   mkdir example && cd example
   npm init -y
   npm install vsql-node

Save this as ``main.js``:

.. code-block:: js

   const vsql = require('vsql-node');

   const db = vsql.connect(':memory:');
   db.run('CREATE TABLE products (id INTEGER, name VARCHAR(50))');

   const insert = db.prepare('INSERT INTO products (id, name) VALUES (?, ?)');
   insert.run([1, 'Bolt']);
   insert.run([2, 'Nut']);
   insert.close();

   for (const row of db.all('SELECT id, name FROM products ORDER BY id')) {
     console.log(row.ID, row.NAME);
   }

   db.close();

Then run it:

.. code-block:: sh

   node main.js

Which prints:

.. code-block:: text

   1 Bolt
   2 Nut
