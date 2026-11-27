Language: Python
================

`vsql-python <https://github.com/elliotchance/vsql-python>`_ is a
`DB-API 2.0 (PEP 249) <https://peps.python.org/pep-0249/>`_ driver. It's built
on libvsql (see :doc:`language-c`), which is compiled into the package, so
there's nothing else to install.

The database is the path of the file (it's created if it doesn't exist), or
``:memory:`` for a database that only exists for the life of the connection.
As PEP 249 requires, autocommit is off, so changes are saved by
``conn.commit()``. The repository's README describes transactions, parameters
and the Python type of each SQL type.

.. contents::

Requirements
------------

Python 3.9 or later. Wheels are built for macOS (ARM64 and x86-64), Linux
(ARM64 and x86-64) and Windows (x86-64), so pip doesn't need to compile
anything. Otherwise, building from the source distribution needs a C compiler.

Example
-------

Create a virtual environment and install the package from PyPI:

.. code-block:: sh

   mkdir example && cd example
   python3 -m venv .venv
   . .venv/bin/activate
   pip install vsql-python

Save this as ``main.py``:

.. code-block:: python

   import vsql

   with vsql.connect(":memory:") as conn:
       cur = conn.cursor()
       cur.execute("CREATE TABLE products (id INTEGER, name VARCHAR(50))")
       cur.executemany(
           "INSERT INTO products (id, name) VALUES (?, ?)",
           [(1, "Bolt"), (2, "Nut")],
       )
       conn.commit()

       cur.execute("SELECT id, name FROM products ORDER BY id")
       for id, name in cur.fetchall():
           print(id, name)

Then run it:

.. code-block:: sh

   python main.py

Which prints:

.. code-block:: text

   1 Bolt
   2 Nut
