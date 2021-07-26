vsql
====

vsql is an single-file SQL database written in pure [V](https://vlang.io) with
no dependencies.

- [Installation](#installation)
- [Usage](#usage)
- [SQL Commands](#sql-commands)
  - [CREATE TABLE](#create-table)
  - [DELETE](#delete)
  - [DROP TABLE](#drop-table)
  - [INSERT](#insert)
  - [SELECT](#select)
  - [UPDATE](#update)
- [Appendix](#appendix)
  - [Data Types](#data-types)
  - [Keywords](#keywords)
  - [SQLSTATE (Errors)](#sqlstate-errors)
- [Testing](#testing)

Installation
------------

```bash
v install elliotchance.vsql
```

Usage
-----

```v
import elliotchance.vsql.vsql

fn example() ? {
    mut db := vsql.open('/tmp/test.vsql') ?

    // All SQL commands use query():
    db.query('CREATE TABLE foo (a FLOAT)') ?
    db.query('INSERT INTO foo (a) VALUES (1.23)') ?
    db.query('INSERT INTO foo (a) VALUES (4.56)') ?

    // Iterate through a result:
    result := db.query('SELECT * FROM foo') ?
    for row in result {
        println(row.get_f64('a'))
    }

    // See SQLSTATE (Errors) below for more examples.
}
```

Outputs:

```
1.23
4.56
I knew 'bar' did not exist!
```

You can also work with database files through the CLI (ctrl+c to exit).

You will need to build the CLI tool first:

```
v install elliotchance.vsql
v ~/.vmodules/elliotchance/vsql/vsql-cli.v
```

Then usage is:

```
$ ./vsql-cli test.vsql
vsql> select * from foo
a: 1234 
1 row (1 ms)

vsql> select * from bar
0 rows (0 ms)
```

# SQL Commands

## CREATE TABLE

```
CREATE TABLE <table_name> ( <column> , ... )

column := <column_name> <column_type> [ NULL | NOT NULL ]
```

1. `column_name` must start with a letter, but can be followed by any letter,
underscore (`_`) or digit for a maximum length of 128 characters.
2. `column_type` must be one of the [Data Types](#data-types).

Example:

```sql
CREATE TABLE products (
    title CHARACTER VARYING(100),
    price FLOAT
)
```

## DELETE

```
DROP FROM <table_name>
[ WHERE <expr> ]
```

If `WHERE` is not provided, all records will be deleted.

## DROP TABLE

```
DROP TABLE <table_name>
```

## INSERT

```
INSERT INTO <table_name> ( <col> , ... )
VALUES ( <value> , ... )
```

The number of `col`s and `value`s must match.

Example:

```sql
INSERT INTO products (title, price) VALUES ('Instant Pot', 144.89)
```

## SELECT

```
SELECT <field> , ...
[ FROM <table_name> ]
[ WHERE <expr> ]
```

Examples:

```sql
SELECT * FROM products
```

## UPDATE

```
UPDATE <table_name>
SET <col> = <value> , ...
[ WHERE <expr> ]
```

If `WHERE` is not provided, all records will be updated.

The result (eg. `UPDATE 8`) contains the number of records actually updated.
That is, more than this number of records may have matched, but only those that
were changed will increment this counter.

Appendix
--------

### Data Types

**Important:** All data types are currently reduced to several basic internal
types described below, which is simpler for not but has some consequences:

1. Types that might take less space in other databases (ie. `SMALLINT` vs
`BIGINT`) will always be stored in a `f64` (8 bytes).
2. Since all numbers are stored at 64-bit floating, some precision of large
integers will not be maintained.
3. Any types that contain a numerical precision or maximum string length will be
ignored. An error will not be returned if the value stored breaches this
requirement.
4. The definition of a "character" isn't yet well defined or enforced. That is,
characters can be any unicode point, but that may change the future.
6. The intent is to have all of the above fixed in future version, so please
choose the correct type for your values now to avoid stricter requirments in the
future.

There are some types that are not supported yet:

1. `<character large object type>`: `CHARACTER LARGE OBJECT`,
`CHAR LARGE OBJECT` and `CLOB`.
2. `<national character string type>`: `NATIONAL CHARACTER`, `NATIONAL CHAR`,
`NCHAR`, `NATIONAL CHARACTER VARYING`, `NATIONAL CHAR VARYING` and
`NCHAR VARYING`.
3. `<national character large object type>`: `NATIONAL CHARACTER LARGE OBJECT`,
`NCHAR LARGE OBJECT` and `NCLOB`.
4. `<binary string type>` - `BINARY`, `BINARY VARYING` and `VARBINARY`.
5. `<binary large object string type>`: `BINARY LARGE OBJECT` and `BLOB`.
6. `<exact numeric type>` (some): `NUMERIC`, `DECIMAL` and `DEC`.
7. `<decimal floating-point type>`: `DECFLOAT`.
8. `<datetime type>`: `DATE`, `TIME` and `TIMESTAMP`.
9. `<interval type>`: `INTERVAL`.
10. `<row type>`: `ROW`.
11. `<reference type>`: `REF`.
12. `<array type>`: `ARRAY`.
13. `<multiset type>`: `MULTISET`.

| Type                   | Internal | Notes |
| ---------------------- | -------- | ----- |
| `BIGINT`               | f64      | Integer |
| `BOOLEAN`              | f64      | `TRUE` or `FALSE` |
| `CHAR VARYING(n)`      | string   | Alias for `CHARACTER VARYING(n)` |
| `CHAR(n)`              | string   | Alias for `CHARACTER(n)` |
| `CHARACTER VARYING(n)` | string   | Strings that can contain up to *n* characters |
| `CHARACTER(n)`         | string   | Fixed width characters |
| `CHARACTER`            | string   | Single character |
| `CHAR`                 | string   | Alias for `CHARACTER` |
| `DOUBLE PRECISION`     | f64      | 64bit floating-point value |
| `FLOAT(n)`             | f64      | 64bit floating-point value |
| `FLOAT`                | f64      | 64bit floating-point value |
| `INTEGER`              | f64      | Integer |
| `INT`                  | f64      | Alias for `INTEGER`. |
| `REAL`                 | f64      | 32bit floating-point value |
| `SMALLINT`             | f64      | Integer |
| `VARCHAR(n)`           | string   | Alias for `CHARACTER VARYING(n)` |

### Keywords

Names of entities (such as tables and columns) cannot be a
[reserved word](https://github.com/elliotchance/vsql/blob/main/vsql/keywords.v).

### SQLSTATE (Errors)

The error returned from `query()` will always one of the `SQLState` struct
types. Each type describes the error situation, but may also contain specific
fields appropriate for that error. See
[sqlstate.v](https://github.com/elliotchance/vsql/blob/main/vsql/sqlstate.v) for
struct definitions.

You can match on these to inspect the error further:

```v
db.query('SELECT * FROM bar') or {
    match err {
        vsql.SQLState42P01 { // 42P01 = table not found
            println("I knew '$err.table_name' did not exist!")
        }
        else { panic(err) }
    }
}
```

The `err.code` contains the integer representation of the SQLSTATE:

```v
db.query('SELECT * FROM bar') or {
    sqlstate := vsql.sqlstate_from_int(err.code)
    println('$sqlstate: $err.msg')
    // 42P01: no such table: BAR

    if err.code == vsql.sqlstate_to_int('42P01') {
        println('table does not exist')
    }
}
```

Or handling errors by class (first two letters):

```v
db.query('SELECT * FROM bar') or {
    if err.code >= vsql.sqlstate_to_int('42000') &&
       err.code <= vsql.sqlstate_to_int('42ZZZ') {
        println('Class 42 — Syntax Error or Access Rule Violation')
    }
}
```

| SQLSTATE   | Reason |
| ---------- | ------ |
| `23502`    | violates non-null constraint |
| `42601`    | syntax error |
| `42703`    | column does not exist |
| `42804`    | data type mismatch |
| `42P01`    | table does not exist |
| `42P07`    | table already exists |

Testing
-------

All tests are in the `tests/` directory and each file contains individual tests
separated by an empty line:

```sql
SELECT 1
SELECT * FROM foo
-- COL1: 1
-- error 42P01: no such table: FOO

SELECT 2
SELECT 3
-- COL1: 2
-- COL1: 3
```

This is two tests where each test is given an a brand new database. All SQL statements are executed and each of the results collected and compared to the
comment immediately below.

Errors will be in the form of `error SQLSTATE: message`.
