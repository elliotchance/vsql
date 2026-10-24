// table.v is the definition of a table (columns names and types).

module vsql

// A column definition.
struct Column {
pub:
	// name resolves to the actual canonical location. If you only need the column
	// name itself, you can use name.sub_entity_name.
	name Identifier
	// typ of the column contains more specifics like size and precision.
	typ Type
	// not_null will be true if ``NOT NULL`` was specified on the column.
	not_null bool
	// default_value is the ``DEFAULT`` of the column, if there is one. A column
	// without a default has a default of ``NULL``.
	default_value ?DefaultOption
}

// str returns the column definition like:
//
//   "foo" INT
//   BAR DOUBLE PRECISION NOT NULL
//
// The DEFAULT isn't included, it's only part of the table definition (see
// Table.bytes).
pub fn (c Column) str() string {
	// A column with the same name as another column in a result has a
	// custom_id (see new_expr_operation), which isn't part of its name.
	name := if c.name.custom_id != '' && c.name.sub_entity_name != '' {
		Identifier{
			...c.name
			custom_id: ''
		}.str()
	} else {
		c.name.str()
	}
	mut f := '${name} ${c.typ}'
	if c.not_null {
		f += ' NOT NULL'
	}

	return f
}

type Columns = []Column

fn (c Columns) str() string {
	mut s := []string{}
	for col in c {
		s << col.str()
	}

	return s.join(', ')
}

// Represents the structure of a table.
pub struct Table {
mut:
	// The tid is the transaction ID that created this table.
	tid u64
	// The id is unique for each table in the file and never reused. Rows are
	// keyed by it, see row_key_prefix.
	id u64
	// The CHECK constraints of the table, in the order they were defined. A
	// CHECK on a column is the same as a CHECK on the table.
	check_constraints []CheckConstraintDefinition
	// The columns of each UNIQUE constraint of the table (other than the
	// PRIMARY KEY), in the order they were defined. A UNIQUE on a column is the
	// same as a UNIQUE on the table.
	unique_constraints [][]string
	// The FOREIGN KEY constraints of the table, in the order they were defined.
	// A REFERENCES on a column is the same as a FOREIGN KEY on the table.
	foreign_keys []ForeignKey
pub mut:
	// The name of the table including the schema.
	name Identifier
	// The column definitions for the table.
	columns Columns
	// If the table has a PRIMARY KEY defined the column (or columns) will be
	// defined here in order.
	primary_key []string
	// When the table is virtual it is not persisted to disk.
	is_virtual bool
}

// Convenience method for returning the ordered list of column names.
pub fn (t Table) column_names() []string {
	mut names := []string{}
	for col in t.columns {
		names << col.name.sub_entity_name
	}

	return names
}

// Find a column by name, or return a SQLSTATE 42703 error.
pub fn (t Table) column(name string) !Column {
	for col in t.columns {
		if name == col.name.sub_entity_name {
			return col
		}
	}

	return sqlstate_42703(name) // column does not exist
}

// bytes is how the table is stored in the file: its CREATE TABLE statement,
// with each column on its own line, like:
//
//   CREATE TABLE "PUBLIC"."FOO" (
//     "ID" INTEGER NOT NULL,
//     "BAR" CHARACTER VARYING(10) DEFAULT 'baz',
//     PRIMARY KEY ("ID"),
//     UNIQUE ("BAR"),
//     FOREIGN KEY ("BAR") REFERENCES "PUBLIC"."BAZ" ("NAME"),
//     CHECK ("ID" > 0)
//   )
fn (t Table) bytes() []u8 {
	mut elements := []string{}
	for col in t.columns {
		mut element := '${delimit_identifier(col.name.sub_entity_name)} ${col.typ}'
		if default_value := col.default_value {
			element += ' DEFAULT ${default_value}'
		}
		if col.not_null {
			element += ' NOT NULL'
		}
		elements << '  ${element}'
	}

	if t.primary_key.len > 0 {
		elements << '  PRIMARY KEY (${t.primary_key.map(delimit_identifier(it)).join(', ')})'
	}

	for columns in t.unique_constraints {
		elements << '  UNIQUE (${columns.map(delimit_identifier(it)).join(', ')})'
	}

	for key in t.foreign_keys {
		elements << '  ${key}'
	}

	for constraint in t.check_constraints {
		elements << '  ${constraint}'
	}

	return 'CREATE TABLE ${t.name.storage_sql()} (\n${elements.join(',\n')}\n)'.bytes()
}

// table_object_key is the key of the definition of a table.
fn table_object_key(table_id u64) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`T`)
	key.write_u64(table_id)

	return key.bytes()
}

// row_key_prefix is the start of the key of every row in a table. The rows of
// a table are in the range from row_key_prefix(id) to row_key_prefix(id + 1).
fn row_key_prefix(table_id u64) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`R`)
	key.write_u64(table_id)

	return key.bytes()
}

fn new_table_from_bytes(key []u8, data []u8, tid u64, catalog_name string) !Table {
	stmt := parse_definition(data)!
	if stmt is TableDefinition {
		mut table := stmt.table(Identifier{
			catalog_name: catalog_name
			schema_name:  stmt.table_name.schema_name
			entity_name:  stmt.table_name.entity_name
		}, tid)!

		mut buf := new_bytes(key[1..])
		table.id = buf.read_u64()

		return table
	}

	return sqlstate_xx001('not a table definition: ${data.bytestr()}')
}

// Returns the CREATE TABLE statement, including the ';'. It's the same as the
// definition that's stored in the file.
pub fn (t Table) str() string {
	return t.bytes().bytestr() + ';'
}

// A TableOperation requires that up to rows in the table be read. The number of
// rows read may be limited and/or an offset (rows to skip) provided.
struct TableOperation {
	table_name Identifier
	// table_is_subplan is true if the table_name should be executed from the
	// subplans instead of a real table.
	table_is_subplan bool
	table            Table
	params           map[string]Value
mut:
	conn     &Connection
	subplans map[string]Plan
}

fn (o TableOperation) str() string {
	return 'TABLE ${o.table_name} (${o.pretty_columns()})'
}

// We could just render `o.table.columns`. However, it makes the output extra
// verbose, so we only show the column names.
fn (o TableOperation) pretty_columns() Columns {
	mut cols := []Column{}
	for c in o.table.columns {
		cols << Column{Identifier{
			sub_entity_name: c.name.sub_entity_name
		}, c.typ, c.not_null, none}
	}

	return cols
}

fn (o TableOperation) columns() Columns {
	return o.table.columns
}

fn (mut o TableOperation) execute(_ []Row) ![]Row {
	mut rows := []Row{}

	if o.table_is_subplan {
		mut subplan := o.subplans[o.table_name.id()]

		// The columns may have been renamed by a derived column list, such as
		// "(SELECT a FROM t) AS x (b)". A row of a table (such as "t AS x (b)")
		// uses the fully qualified column name, but a subquery may not.
		mut names := map[string]string{}
		for i, column in subplan.columns() {
			names[column.name.sub_entity_name] = o.table.columns[i].name.sub_entity_name
			names[column.name.id()] = o.table.columns[i].name.sub_entity_name
		}

		for row in subplan.execute([]Row{})! {
			mut data := map[string]Value{}
			for k, v in row.data {
				data['${o.table_name}.${names[k] or { k }}'] = v
			}

			rows << new_row(data)
		}
	} else {
		mut catalog := o.conn.catalogs[o.table_name.catalog_name] or {
			return sqlstate_3d000(o.table_name.catalog_name)
		}
		rows = catalog.storage.read_rows(o.table_name)!
	}

	return rows
}
