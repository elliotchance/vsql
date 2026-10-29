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
	// identity is set when the column is the identity column of the table (see
	// Table.identity_column).
	identity ?IdentityColumn
	// generated is set when the column is a generated column, whose value is
	// always the result of its generation expression.
	generated ?GenerationClause
	// unnamed is true when the column of a result has an implementation-dependent
	// name (such as COL1) because the query didn't name it. For example, an
	// expression without an AS clause, or a column of VALUES.
	unnamed bool
}

// is_generated_always is true if a value can't be assigned to the column, other
// than DEFAULT, because it's a generated column or an identity column that's
// GENERATED ALWAYS.
//
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules 10 and 11b
// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, Syntax Rule 5
fn (c Column) is_generated_always() bool {
	if identity := c.identity {
		return identity.always
	}

	return c.generated != none
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
	// The UNIQUE constraints of the table (other than the PRIMARY KEY), in the
	// order they were defined. A UNIQUE on a column is the same as a UNIQUE on
	// the table.
	unique_constraints []UniqueConstraint
	// The name of the PRIMARY KEY, if there is one.
	primary_key_name string
	// The names of the NOT NULL constraints, keyed by the column name.
	not_null_names map[string]string
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

// identity_column returns the identity column of the table, if it has one. A
// table can have at most one (ISO/IEC 9075-2:2016(E), 11.3, Syntax Rule 15).
fn (t Table) identity_column() ?Column {
	for col in t.columns {
		if _ := col.identity {
			return col
		}
	}

	return none
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
//     CONSTRAINT "POSITIVE_ID" CHECK ("ID" > 0)
//   )
//
// A constraint only has a CONSTRAINT clause when its name isn't the one that
// it would be given without one (see constraint_name_definition).
fn (t Table) bytes() []u8 {
	mut elements := []string{}
	for i, col in t.columns {
		mut element := '${delimit_identifier(col.name.sub_entity_name)} ${col.typ}'
		if default_value := col.default_value {
			element += ' DEFAULT ${default_value}'
		}
		if identity := col.identity {
			element += ' ${identity}'
		}
		if generated := col.generated {
			element += ' ${generated}'
		}
		if col.not_null {
			element += ' ${constraint_name_definition(t.not_null_names[col.name.sub_entity_name], constraint_name(t, 'NOT_NULL', i))}NOT NULL'
		}
		elements << '  ${element}'
	}

	if t.primary_key.len > 0 {
		elements << '  ${constraint_name_definition(t.primary_key_name, constraint_name(t, 'PRIMARY_KEY', 0))}PRIMARY KEY (${t.primary_key.map(delimit_identifier(it)).join(', ')})'
	}

	for i, constraint in t.unique_constraints {
		elements << '  ${constraint_name_definition(constraint.name, constraint_name(t, 'UNIQUE', i))}${constraint}'
	}

	for i, key in t.foreign_keys {
		elements << '  ${constraint_name_definition(key.name, constraint_name(t, 'FOREIGN_KEY', i))}${key}'
	}

	for i, constraint in t.check_constraints {
		elements << '  ${constraint_name_definition(constraint.name.entity_name, constraint_name(t, 'CHECK', i))}${constraint}'
	}

	return 'CREATE TABLE ${t.name.storage_sql()} (\n${elements.join(',\n')}\n)'.bytes()
}

// constraint_name_definition is the CONSTRAINT clause (followed by a space) of a
// constraint in the file. It's empty when the name is the default_name, which
// is the name that the constraint gets when it's read without one, so that a
// table that doesn't need any names can still be read by older versions of
// vsql.
fn constraint_name_definition(name string, default_name string) string {
	if name == default_name {
		return ''
	}

	return 'CONSTRAINT ${delimit_identifier(name)} '
}

// elements are the table elements of the definition of the table, with the
// names of its constraints, so that the table can be defined again with
// changes (such as by ALTER TABLE ADD COLUMN).
fn (t Table) elements() []TableElement {
	mut elements := []TableElement{}
	for column in t.columns {
		elements << column
		if column.not_null {
			elements << NotNullConstraint{
				name:   Identifier{
					entity_name: t.not_null_names[column.name.sub_entity_name]
				}
				column: column.name.sub_entity_name
			}
		}
	}
	if t.primary_key.len > 0 {
		elements << UniqueConstraintDefinition{
			name:           Identifier{
				entity_name: t.primary_key_name
			}
			columns:        t.primary_key.map(Identifier{
				sub_entity_name: it
			})
			is_primary_key: true
		}
	}
	for constraint in t.unique_constraints {
		elements << UniqueConstraintDefinition{
			name:            Identifier{
				entity_name: constraint.name
			}
			columns:         constraint.columns.map(Identifier{
				sub_entity_name: it
			})
			characteristics: constraint.characteristics
		}
	}
	for key in t.foreign_keys {
		elements << ReferentialConstraintDefinition{
			name:               Identifier{
				entity_name: key.name
			}
			columns:            key.columns.map(Identifier{
				sub_entity_name: it
			})
			referenced_table:   key.referenced_table
			referenced_columns: key.referenced_columns.map(Identifier{
				sub_entity_name: it
			})
			update_rule:        key.update_rule
			delete_rule:        key.delete_rule
			characteristics:    key.characteristics
		}
	}
	for constraint in t.check_constraints {
		elements << constraint
	}

	return elements
}

// constraint_names are the names of every constraint of the table: the NOT
// NULL constraints (in the order of the columns), the PRIMARY KEY, then each
// UNIQUE, FOREIGN KEY and CHECK. A constraint of a new definition that hasn't
// been named yet (see name_constraints) has an empty name.
fn (t Table) constraint_names() []string {
	mut names := []string{}
	for column in t.columns {
		if column.not_null {
			names << t.not_null_names[column.name.sub_entity_name]
		}
	}
	if t.primary_key.len > 0 {
		names << t.primary_key_name
	}
	for constraint in t.unique_constraints {
		names << constraint.name
	}
	for key in t.foreign_keys {
		names << key.name
	}
	for constraint in t.check_constraints {
		names << constraint.name.entity_name
	}

	return names
}

// name_constraints names each constraint of a new definition of the table that
// wasn't given a name. A constraint name must be unique in the schema (ISO/IEC
// 9075-2:2016(E), 11.6, Syntax Rule 4), so it's an error if a name is used by
// more than one constraint of the table, or is one of the other_names (the
// names of the constraints of the other tables in the schema).
//
// A constraint without a name gets an implementation-dependent name (Syntax
// Rule 3) like its default name (see constraint_name), with the first number
// that isn't already used, counting from 1 (or the position of the column for
// a NOT NULL). So a constraint can get the name of one that has been dropped.
fn (mut t Table) name_constraints(other_names []string) ! {
	mut used := map[string]bool{}
	for name in other_names {
		used[name] = true
	}
	for name in t.constraint_names() {
		if name == '' {
			continue
		}
		if name in used {
			return sqlstate_42710('constraint', name)
		}
		used[name] = true
	}

	t.fill_constraint_names(mut used, true)
}

// default_constraint_names names each constraint of a table that's read from
// the file, and was stored without a name, with its default name. A name is
// only stored when it isn't the default (see Table.bytes), so this is always
// the name that the constraint was given.
fn (mut t Table) default_constraint_names() {
	mut used := map[string]bool{}
	t.fill_constraint_names(mut used, false)
}

// fill_constraint_names gives each constraint that doesn't have a name its
// default name, or the first name that isn't used when is_new (see
// name_constraints).
fn (mut t Table) fill_constraint_names(mut used map[string]bool, is_new bool) {
	for i, column in t.columns {
		if column.not_null && t.not_null_names[column.name.sub_entity_name] == '' {
			t.not_null_names[column.name.sub_entity_name] = t.new_constraint_name(mut used,
				is_new, 'NOT_NULL', i)
		}
	}
	if t.primary_key.len > 0 && t.primary_key_name == '' {
		t.primary_key_name = t.new_constraint_name(mut used, is_new, 'PRIMARY_KEY', 0)
	}
	for i, constraint in t.unique_constraints {
		if constraint.name == '' {
			t.unique_constraints[i] = UniqueConstraint{
				...constraint
				name: t.new_constraint_name(mut used, is_new, 'UNIQUE', i)
			}
		}
	}
	for i, key in t.foreign_keys {
		if key.name == '' {
			t.foreign_keys[i] = ForeignKey{
				...key
				name: t.new_constraint_name(mut used, is_new, 'FOREIGN_KEY', i)
			}
		}
	}
	for i, constraint in t.check_constraints {
		if constraint.name.entity_name == '' {
			t.check_constraints[i] = CheckConstraintDefinition{
				...constraint
				name: Identifier{
					entity_name: t.new_constraint_name(mut used, is_new, 'CHECK', i)
				}
			}
		}
	}
}

// new_constraint_name is the name of the ith constraint of a kind (or the NOT
// NULL of the ith column) that doesn't have one: its default name, or when
// is_new, the first name that isn't used, counting from 1 (or the position of
// the column for a NOT NULL).
fn (t Table) new_constraint_name(mut used map[string]bool, is_new bool, kind string, i int) string {
	if !is_new {
		return constraint_name(t, kind, i)
	}

	mut n := if kind == 'NOT_NULL' { i } else { 0 }
	for constraint_name(t, kind, n) in used {
		n++
	}
	name := constraint_name(t, kind, n)
	used[name] = true

	return name
}

// constraint_name is the default name of a constraint that wasn't given one,
// such as T_CHECK_1 for the first CHECK of table T, T_UNIQUE_1 for its first
// UNIQUE, T_FOREIGN_KEY_1 for its first FOREIGN KEY, or T_NOT_NULL_2 for the
// NOT NULL of its second column. A PRIMARY KEY is T_PRIMARY_KEY (or
// T_PRIMARY_KEY_2 when that's already used, see name_constraints). The default
// name of the ith constraint (counting from 0) has the number i + 1.
fn constraint_name(table Table, kind string, i int) string {
	if kind == 'PRIMARY_KEY' && i == 0 {
		return '${table.name.entity_name}_PRIMARY_KEY'
	}

	return '${table.name.entity_name}_${kind}_${i + 1}'
}

// ConstraintKind is the kind of a constraint of a table.
enum ConstraintKind {
	not_null
	primary_key
	unique
	foreign_key
	check
}

// find_constraint returns the kind of the constraint of the table that has the
// name, and its position (the column of a NOT NULL, otherwise in the list of
// that kind), or an error if the table doesn't have it. The name can be
// qualified by the schema (and catalog) of the table.
fn (t Table) find_constraint(name Identifier) !(ConstraintKind, int) {
	if name.catalog_name in ['', t.name.catalog_name] && name.schema_name in ['', t.name.schema_name] {
		for i, column in t.columns {
			if column.not_null && t.not_null_names[column.name.sub_entity_name] == name.entity_name {
				return .not_null, i
			}
		}
		if t.primary_key.len > 0 && t.primary_key_name == name.entity_name {
			return .primary_key, 0
		}
		for i, constraint in t.unique_constraints {
			if constraint.name == name.entity_name {
				return .unique, i
			}
		}
		for i, key in t.foreign_keys {
			if key.name == name.entity_name {
				return .foreign_key, i
			}
		}
		for i, constraint in t.check_constraints {
			if constraint.name.entity_name == name.entity_name {
				return .check, i
			}
		}
	}

	return sqlstate_42704('constraint', '${name} on ${t.name}')
}

// constraint_characteristics are the characteristics of the constraint that
// find_constraint found. A NOT NULL or PRIMARY KEY is never deferrable.
fn (t Table) constraint_characteristics(kind ConstraintKind, i int) ConstraintCharacteristics {
	return match kind {
		.unique { t.unique_constraints[i].characteristics }
		.foreign_key { t.foreign_keys[i].characteristics }
		.check { t.check_constraints[i].characteristics }
		else { ConstraintCharacteristics{} }
	}
}

// table_object_key is the key of the definition of a table.
fn table_object_key(table_id u64) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`T`)
	key.write_u64(table_id)

	return key.bytes()
}

// identity_key is the key of the current value of the sequence of the identity
// column of a table (see Storage.add_identity).
fn identity_key(table_id u64) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`I`)
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
		table.default_constraint_names()

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
		cols << Column{
			name:     Identifier{
				sub_entity_name: c.name.sub_entity_name
			}
			typ:      c.typ
			not_null: c.not_null
		}
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

			// The id is kept for a cursor, see ExprOperation.execute.
			rows << Row{row.id, row.tid, data}
		}
	} else {
		mut catalog := o.conn.catalogs[o.table_name.catalog_name] or {
			return sqlstate_3d000(o.table_name.catalog_name)
		}
		rows = catalog.storage.read_rows(o.table_name)!
	}

	return rows
}
