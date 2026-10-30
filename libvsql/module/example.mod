-- example.mod is an SQL-client module. "vsql module example.mod" compiles it
-- into example.h and example.c, which example_main.c uses.
MODULE example
LANGUAGE C
SCHEMA "PUBLIC"

PROCEDURE open_database (SQLSTATE, :file CHARACTER VARYING(100));
  CONNECT TO :file AS 'example';

PROCEDURE create_items (SQLSTATE);
  CREATE TABLE items (id INTEGER, name CHARACTER VARYING(20), price DOUBLE PRECISION);

PROCEDURE add_item (SQLSTATE, :id INTEGER, :name CHARACTER VARYING(20),
                    :price DOUBLE PRECISION, :price_indicator SMALLINT);
  INSERT INTO items (id, name, price) VALUES (:id, :name, :price INDICATOR :price_indicator);

PROCEDURE change_prices (SQLSTATE, :factor DOUBLE PRECISION);
  UPDATE items SET price = price * :factor;

PROCEDURE get_item (SQLSTATE, :id INTEGER, :name CHARACTER VARYING(20),
                    :price DOUBLE PRECISION, :price_indicator SMALLINT);
  SELECT name, price INTO :name, :price INDICATOR :price_indicator
  FROM items WHERE id = :id;

PROCEDURE commit_work (SQLSTATE);
  COMMIT;

PROCEDURE close_database (SQLSTATE);
  DISCONNECT ALL;
