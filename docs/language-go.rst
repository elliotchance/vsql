Language: Go
============

`vsql-go <https://github.com/elliotchance/vsql-go>`_ is a driver for Go's
`database/sql <https://pkg.go.dev/database/sql>`_ package. It's built on
libvsql (see :doc:`language-c`), which is compiled into the package with cgo, so
there's nothing else to install.

The data source name is the path of the database file (it's created if it
doesn't exist), or ``:memory:`` for a database that only exists for the life of
the connection. The
`package documentation <https://pkg.go.dev/github.com/elliotchance/vsql-go/vsql>`_
describes transactions, parameters and the Go type of each SQL type.

.. contents::

Requirements
------------

cgo must be enabled (``CGO_ENABLED=1``, the default when building for the same
OS) with a C compiler. The first build compiles libvsql, which takes about 20
seconds, after that it's cached by Go. macOS, Linux and Windows (each on ARM64
and x86-64) are supported.

Example
-------

Create a module and add the package:

.. code-block:: sh

   mkdir example && cd example
   go mod init example
   go get github.com/elliotchance/vsql-go/vsql

Save this as ``main.go``:

.. code-block:: go

   package main

   import (
   	"database/sql"
   	"fmt"
   	"log"

   	_ "github.com/elliotchance/vsql-go/vsql"
   )

   func main() {
   	db, err := sql.Open("vsql", ":memory:")
   	if err != nil {
   		log.Fatal(err)
   	}
   	defer db.Close()

   	// Each connection to ":memory:" is a different database.
   	db.SetMaxOpenConns(1)

   	_, err = db.Exec("CREATE TABLE products (id INTEGER, name VARCHAR(50))")
   	if err != nil {
   		log.Fatal(err)
   	}

   	for id, name := range []string{"Bolt", "Nut"} {
   		_, err = db.Exec("INSERT INTO products (id, name) VALUES (?, ?)", id+1, name)
   		if err != nil {
   			log.Fatal(err)
   		}
   	}

   	rows, err := db.Query("SELECT id, name FROM products ORDER BY id")
   	if err != nil {
   		log.Fatal(err)
   	}
   	defer rows.Close()

   	for rows.Next() {
   		var id int
   		var name string
   		if err := rows.Scan(&id, &name); err != nil {
   			log.Fatal(err)
   		}
   		fmt.Println(id, name)
   	}
   	if err := rows.Err(); err != nil {
   		log.Fatal(err)
   	}
   }

Then run it:

.. code-block:: sh

   go run .

Which prints:

.. code-block:: text

   1 Bolt
   2 Nut
