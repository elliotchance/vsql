✌️ vsql
======

[![Release](https://img.shields.io/github/v/release/elliotchance/vsql)](https://github.com/elliotchance/vsql/releases)
[![Docs](https://readthedocs.org/projects/vsql/badge/?version=latest)](https://vsql.readthedocs.io/)

**vsql is a small SQL database that follows the SQL standard.** It keeps a whole
database in a single file (or in memory), and you can use it from a terminal,
from any PostgreSQL client, or embedded in your own [V](https://vlang.io)
program. It's written in pure V with no dependencies.

```text
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
```

Why vsql?
---------

- **Standard SQL.** vsql follows the SQL:2016 standard rather than any one
  database's dialect, so what you learn here works elsewhere. Errors use the
  standard SQLSTATE codes, and the
  [compliance table](https://vsql.readthedocs.io/en/latest/sql-compliance.html)
  shows what's supported so far.
- **One file, no setup.** A database is a single file you can copy around, like
  SQLite. Use `:memory:` for a database that only lives in memory.
- **Real transactions.** `START TRANSACTION`, `COMMIT` and `ROLLBACK` work
  across connections and processes using
  [MVCC](https://vsql.readthedocs.io/en/latest/mvcc.html), and a write-ahead log
  keeps the file safe if the process or the power stops.
- **Talks to PostgreSQL clients.** `vsql server` speaks the PostgreSQL wire
  protocol, so you can connect with `psql` or a GUI such as TablePlus.
- **Made for V.** Embed it in a V program as a library, use it with V's
  built-in ORM, add your own SQL functions, or expose your data as virtual
  tables.

Try It
------

### 1. Download

Download `vsql` for macOS, Linux or Windows from the
[latest release](https://github.com/elliotchance/vsql/releases/latest) and
unzip it. Nothing else needs to be installed.

Or, with Docker:

```sh
docker run -it --mount type=bind,source="$(pwd)",target=/db elliotchance/vsql cli /db/shop.vsql
```

### 2. Run some SQL

```sh
vsql cli shop.vsql
```

This creates `shop.vsql` if it doesn't exist. Type `exit` to leave. You can also
load a file of SQL statements with `vsql in shop.vsql < schema.sql`, and dump a
database as SQL with `vsql out shop.vsql`.

### 3. Connect with a PostgreSQL client

```sh
vsql server shop.vsql
```

Then, in another terminal:

```sh
psql -h 127.0.0.1 -p 3210
```

The server ignores the user name, password and database name. See the
[list of tested clients](https://vsql.readthedocs.io/en/latest/postgresql-clients.html).

Use It From V
-------------

```sh
v install elliotchance.vsql
```

```v
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
```

There's also a driver for V's ORM:

```v
import elliotchance.vsql.vorm

struct Product {
	id    int @[primary; sql: serial]
	name  string
	price f64
}

fn main() {
	mut db := vorm.open('shop.vsql')!
	sql db {
		create table Product
	}!
}
```

See the [V docs](https://vsql.readthedocs.io/en/latest/language-v.html) (for
the client library and the ORM), and the
[examples](https://github.com/elliotchance/vsql/tree/main/examples).

Good to Know
------------

- **It follows the standard closely.** Unquoted names are upper case
  (`products` is `PRODUCTS`), there's no `LIMIT` (use
  `FETCH FIRST 10 ROWS ONLY`) and no `NOW()` (use `CURRENT_TIMESTAMP`). Use
  `VALUES 1 + 2` to try an expression, since a `SELECT` needs a `FROM`. The
  [FAQ](https://vsql.readthedocs.io/en/latest/faq.html) has more.
- **Not everything is there yet.** For example, `DISTINCT`, `HAVING`, `IN`,
  `CASE`, subqueries in `WHERE`, `UNIQUE` and `FOREIGN KEY` constraints, and
  column defaults aren't supported yet. The
  [compliance table](https://vsql.readthedocs.io/en/latest/sql-compliance.html)
  has the full list.

Documentation
-------------

The full documentation is at [vsql.readthedocs.io](https://vsql.readthedocs.io/):

- [Installing & updating](https://vsql.readthedocs.io/en/latest/install.html)
- [CLI](https://vsql.readthedocs.io/en/latest/cli.html) and
  [server](https://vsql.readthedocs.io/en/latest/server.html)
- [SQL reference](https://vsql.readthedocs.io/en/latest/sql-reference.html),
  [functions](https://vsql.readthedocs.io/en/latest/functions.html) and
  [SQLSTATE errors](https://vsql.readthedocs.io/en/latest/sqlstate.html)
- [Transactions](https://vsql.readthedocs.io/en/latest/transactions.html) and
  [how the file format works](https://vsql.readthedocs.io/en/latest/file-format.html)

Contributing
------------

Bug reports, ideas and pull requests are all welcome. Start with the
[contributing guide](https://vsql.readthedocs.io/en/latest/contributing.html)
and [how the tests work](https://vsql.readthedocs.io/en/latest/testing.html).
vsql is MIT licensed.
