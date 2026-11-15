-- # One row, with the name of the catalog (5.2, Description, 1). CATALOG_NAME
-- # is its short name view (5.77).
SELECT * FROM information_schema.information_schema_catalog_name;
SELECT * FROM information_schema.catalog_name;
-- CATALOG_NAME: :memory:
-- CATALOG_NAME: :memory:

-- # Each catalog has its own name.
/* create_catalog FOO */
SELECT * FROM foo.information_schema.information_schema_catalog_name;
-- CATALOG_NAME: FOO

-- # It's read-only, like the views.
INSERT INTO information_schema.information_schema_catalog_name (catalog_name) VALUES ('x');
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
