vdb
===

vdb is an single-file SQL database written in pure [V](https://vlang.io) with no
dependencies.

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
- [Testing](#testing)

Installation
------------

```bash
v install elliotchance.vdb
```

Usage
-----

```v
import elliotchance.vdb.vdb

fn example() ? {
    mut db := vdb.open('/tmp/test.vdb') ?

    // All SQL commands use query():
    db.query('CREATE TABLE foo (a FLOAT)') ?
    db.query('INSERT INTO foo (a) VALUES (1.23)') ?
    db.query('INSERT INTO foo (a) VALUES (4.56)') ?

    // Iterate through a result:
    result1 := db.query('SELECT * FROM foo') ?
    for row in result1 {
        println(row.get_f64('a'))
    }

    // Handling specific errors:
    db.query('SELECT * FROM bar') or {
        match err {
            vdb.SQLState42P01 { // 42P01 = table not found
                println("I knew '$err.table_name' did not exist!")
            }
            else { panic(err) }
        }
    }
}
```

Outputs:

```
1.23
4.56
I knew 'bar' did not exist!
```

# SQL Commands

## CREATE TABLE

```
CREATE TABLE <table_name> ( <column> , ... )

column := <column_name> <column_type>
```

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

- `CHARACTER VARYING(n)` for strings that can contain up to *n* characters.
- `FLOAT` for a 64bit floating-point value.

Testing
-------

All tests are in the `tests/` directory and each file contains individual tests
separated by an empty line:

```sql
SELECT 1
-- col1: 1

SELECT 2
SELECT 3
-- col2: 2
-- col1: 3
```

This is two tests where each test is given an a brand new database. All SQL statements are executed and each of the results collected and compared to the
comment immediately below.
