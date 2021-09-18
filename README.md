vsql
====

vsql is a single-file SQL database written in pure [V](https://vlang.io) with
no dependencies.

- [Usage](#usage)
  - [V Module](#v-module)
  - [CLI](#cli)
  - [Server](#server)
  - [Custom Functions](#custom-functions)
  - [Virtual Tables](#virtual-tables)
  - [Prepared Statements](https://github.com/elliotchance/vsql/blob/main/docs/prepared-statements.rst)
  - [In Memory Databases](#in-memory-databases)
- [FAQ](https://github.com/elliotchance/vsql/blob/main/docs/faq.rst)
- SQL Commands
  - [CREATE TABLE](https://github.com/elliotchance/vsql/blob/main/docs/create-table.rst)
  - [DELETE](https://github.com/elliotchance/vsql/blob/main/docs/delete.rst)
  - [DROP TABLE](https://github.com/elliotchance/vsql/blob/main/docs/drop-table.rst)
  - [EXPLAIN](https://github.com/elliotchance/vsql/blob/main/docs/explain.rst)
  - [INSERT](https://github.com/elliotchance/vsql/blob/main/docs/insert.rst)
  - [SELECT](https://github.com/elliotchance/vsql/blob/main/docs/select.rst)
  - [UPDATE](https://github.com/elliotchance/vsql/blob/main/docs/update.rst)
- [Appendix](#appendix)
  - [Data Types](https://github.com/elliotchance/vsql/blob/main/docs/data-types.rst)
  - [File Format](https://github.com/elliotchance/vsql/blob/main/docs/file-format.rst)
  - [Functions](https://github.com/elliotchance/vsql/blob/main/docs/functions.rst)
  - [Keywords](https://github.com/elliotchance/vsql/blob/main/docs/keywords.rst)
  - [Operators](https://github.com/elliotchance/vsql/blob/main/docs/operators.rst)
  - [SQLSTATE (Errors)](https://github.com/elliotchance/vsql/blob/main/docs/sqlstate.rst)
- [Benchmark](https://github.com/elliotchance/vsql/blob/main/docs/benchmark.rst)
- [Development](https://github.com/elliotchance/vsql/blob/main/docs/development.rst)
- [Testing](https://github.com/elliotchance/vsql/blob/main/docs/testing.rst)

Usage
-----

### V Module

Install or update to the latest with:

```bash
v install elliotchance.vsql
```

```v
import elliotchance.vsql.vsql

fn example() ? {
    mut db := vsql.open('test.vsql') ?

    // All SQL commands use query():
    db.query('CREATE TABLE foo (x DOUBLE PRECISION)') ?
    db.query('INSERT INTO foo (x) VALUES (1.23)') ?
    db.query('INSERT INTO foo (x) VALUES (4.56)') ?

    // Iterate through a result:
    result := db.query('SELECT * FROM foo') ?
    println(result.columns)

    for row in result {
        println(row.get_f64('X') ?)
    }

    // See SQLSTATE (Errors) below for more examples.
}
```

Outputs:

```
['A']
1.23
4.56
```

You can find the documentation for a
[`Row` here](https://github.com/elliotchance/vsql/blob/main/vsql/row.v).

### CLI

You can also work with database files through the CLI (ctrl+c to exit):

```
$ vsql test.vsql
vsql> select * from foo
A: 1234 
1 row (1 ms)

vsql> select * from bar
0 rows (0 ms)
```

Binary releases can be downloaded from the
[Releases](https://github.com/elliotchance/vsql/releases) page (under Assets).

These binary releases do not require V to be installed. Or, you can compile from
source with:

```sh
v install elliotchance.vsql
v ~/.vmodules/elliotchance/vsql/cmd/vsql.v
```

### Server

vsql can be run as a server and any PostgreSQL-compatible driver can access it.
This is ideal if you want to use a more familar or feature rich database client.

See the
[list of supported clients here](https://github.com/elliotchance/vsql/blob/main/docs/supported-clients.rst).

Now run it with (if the file does not exist it will be created):

```sh
$ vsql server mydb.vsql
ready on 127.0.0.1:3210
```

vsql will ignore any authentication values (such as user, password, database,
etc). Simply connect using `127.0.0.1:3210`.

Binary releases can be downloaded from the
[Releases](https://github.com/elliotchance/vsql/releases) page (under Assets).

These binary releases do not require V to be installed. Or, you can compile from
source with:

```sh
v install elliotchance.vsql
v ~/.vmodules/elliotchance/vsql/cmd/vsql.v
```

### Custom Functions

You can create custom functions to use in expressions:

```v
// no_pennies will round to 0.05 denominations.
db.register_function('no_pennies(float) float', fn (a []vsql.Value) ?vsql.Value {
  amount := math.round(a[0].f64_value / 0.05) * 0.05
  return vsql.new_double_precision_value(amount)
}) ?

db.query('CREATE TABLE products (product_name VARCHAR(100), price FLOAT)') ?
db.query("INSERT INTO products (product_name, price) VALUES ('Ice Cream', 5.99)") ?
db.query("INSERT INTO products (product_name, price) VALUES ('Ham Sandwhich', 3.47)") ?
db.query("INSERT INTO products (product_name, price) VALUES ('Bagel', 1.25)") ?

result := db.query('SELECT product_name, no_pennies(price) as total FROM products') ?
for row in result {
  total := row.get_f64('TOTAL') ?
  println('${row.get_string('PRODUCT_NAME') ?} $${total:.2f}')
}
```

A function must return a value to match the return type. See the full list of
`Value` constructors in
[value.v](https://github.com/elliotchance/vsql/blob/main/vsql/value.v).

### Virtual Tables

Virtual tables allow you to register tables that have their rows provided at the
time of a `SELECT`:

```v
db.register_virtual_table(
  'CREATE TABLE foo ( "num" INT, word VARCHAR (32) )',
  fn (mut t vsql.VirtualTable) ? {
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
) ?

result := db.query('SELECT * FROM foo') ?
for row in result {
  num := row.get_f64('num') ?
  word := row.get_string('WORD') ?
  println('$num $word')
}
```

The callback for the virtual table will be called repeatedly until `t.done()` is
invoked, even if zero rows are provided in an iteration. All data will be thrown
away between subsequent `SELECT` operations.

### In Memory Databases

Opening a database with the special file name ":memory:" will use an entirely
in-memory database:

```v
mut db := vsql.open(':memory:') ?
```
