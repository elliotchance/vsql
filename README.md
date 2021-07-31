vsql
====

vsql is a single-file SQL database written in pure [V](https://vlang.io) with
no dependencies.

- [Usage](#usage)
  - [V Module](#v-module)
  - [CLI](#cli)
  - [Server](#server)]
  - [Custom Functions](#custom-functions)
- SQL Commands
  - [CREATE TABLE](https://github.com/elliotchance/vsql/blob/main/docs/create-table.rst)
  - [DELETE](https://github.com/elliotchance/vsql/blob/main/docs/delete.rst)
  - [DROP TABLE](https://github.com/elliotchance/vsql/blob/main/docs/drop-table.rst)
  - [INSERT](https://github.com/elliotchance/vsql/blob/main/docs/insert.rst)
  - [SELECT](https://github.com/elliotchance/vsql/blob/main/docs/select.rst)
  - [UPDATE](https://github.com/elliotchance/vsql/blob/main/docs/update.rst)
- [Appendix](#appendix)
  - [Data Types](https://github.com/elliotchance/vsql/blob/main/docs/data-types.rst)
  - [Functions](https://github.com/elliotchance/vsql/blob/main/docs/functions.rst)
  - [Keywords](https://github.com/elliotchance/vsql/blob/main/docs/keywords.rst)
  - [Operators](https://github.com/elliotchance/vsql/blob/main/docs/operators.rst)
  - [SQLSTATE (Errors)](https://github.com/elliotchance/vsql/blob/main/docs/sqlstate.rst)
- [Testing](#testing)

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
    db.query('CREATE TABLE foo (a DOUBLE PRECISION)') ?
    db.query('INSERT INTO foo (a) VALUES (1.23)') ?
    db.query('INSERT INTO foo (a) VALUES (4.56)') ?

    // Iterate through a result:
    result := db.query('SELECT * FROM foo') ?
    println(result.columns)

    for row in result {
        println(row.get_f64('A') ?)
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
$ ./vsql-cli test.vsql
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
v ~/.vmodules/elliotchance/vsql/vsql-cli.v
```

### Server

vsql can be run as a server and any PostgreSQL-compatible driver can access it.
This is ideal if you want to use a more familar or feature rich database client.

Now run it with (if the file does not exist it will be created):

```sh
$ ./vsql-server mydb.vsql
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
v ~/.vmodules/elliotchance/vsql/vsql-server.v
```

### Custom Functions

You can create custom functions to use in expressions:

```v
// no_pennies will round to 0.05 denominations.
db.register_function('no_pennies(float) float', fn (a []vsql.Value) ?vsql.Value {
    amount := math.round(a[0].f64_value / 0.05) * 0.05
    return vsql.new_double_precision_value(amount)
}) ?

db.query('CREATE TABLE products (name VARCHAR(100), price FLOAT)') ?
db.query("INSERT INTO products (name, price) VALUES ('Ice Cream', 5.99)") ?
db.query("INSERT INTO products (name, price) VALUES ('Ham Sandwhich', 3.47)") ?
db.query("INSERT INTO products (name, price) VALUES ('Bagel', 1.25)") ?

result := db.query('SELECT name, no_pennies(price) as total FROM products') ?
for row in result {
    total := row.get_f64('TOTAL') ?
    println('${row.get_string('NAME') ?} $${total:.2f}')
}
```

A function must return a value to match the return type. See the full list of
`Value` constructors in
[value.v](https://github.com/elliotchance/vsql/blob/main/vsql/value.v).

Testing
-------

All tests are in the `tests/` directory and each file contains individual tests
separated by an empty line:

```sql
SELECT 1;
SELECT *
FROM foo;
-- COL1: 1
-- error 42P01: no such table: FOO

SELECT 2;
SELECT 3;
-- COL1: 2
-- COL1: 3
```

This describes two tests where each test is given an a brand new database (ie.
no tables are carried between tests).

- All SQL statements are executed and each of the results collected and compared
to the comment immediately below.
- Errors will be in the form of `error SQLSTATE: message`.
- A statement can span multiple lines but must me terminated by a `;`.
