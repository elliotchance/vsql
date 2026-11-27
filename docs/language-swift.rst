Language: Swift
===============

`vsql-swift <https://github.com/elliotchance/vsql-swift>`_ is a Swift package
(the ``VSQL`` library). It's built on libvsql (see :doc:`language-c`), which is
compiled into the package, so there's nothing else to install.

``Connection(path:)`` creates the database file if it doesn't exist, and
``Connection()`` is a database that only exists in memory for the life of the
connection. Each ``?`` is an argument, a row is a collection of values that can
be read by position or name, and a row can be decoded as any ``Decodable``. The
repository's README describes queries, transactions and the Swift type of each
SQL type.

.. contents::

Requirements
------------

Swift 6.0 or later, on macOS 13 or later (ARM64 and x86-64), Linux (ARM64 and
x86-64) or Windows (x86-64). iOS and the other Apple platforms aren't supported
yet. The first build compiles libvsql, which takes about 15 seconds.

Example
-------

Create a package:

.. code-block:: sh

   mkdir -p example/Sources/example && cd example

Save this as ``Package.swift``, which adds vsql-swift (from its git
repository) as a dependency:

.. code-block:: swift

   // swift-tools-version:6.0

   import PackageDescription

   let package = Package(
       name: "example",
       platforms: [.macOS(.v13)],
       dependencies: [
           .package(url: "https://github.com/elliotchance/vsql-swift", from: "1.0.0"),
       ],
       targets: [
           .executableTarget(
               name: "example",
               dependencies: [.product(name: "VSQL", package: "vsql-swift")]
           ),
       ]
   )

Save this as ``Sources/example/main.swift``:

.. code-block:: swift

   import VSQL

   let db = try Connection()
   try db.execute("CREATE TABLE products (id INTEGER, name VARCHAR(50))")
   try db.execute("INSERT INTO products (id, name) VALUES (?, ?)", 1, "Bolt")
   try db.execute("INSERT INTO products (id, name) VALUES (?, ?)", 2, "Nut")

   for row in try db.query("SELECT id, name FROM products ORDER BY id") {
       let id: Int = try row.get(0)
       let name: String = try row.get("name")
       print(id, name)
   }

Then run it:

.. code-block:: sh

   swift run

Which prints (after the build):

.. code-block:: text

   1 Bolt
   2 Nut
