module vsql

// ISO/IEC 9075-2:2016(E), 4.26, SQL-schemas
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.2.8, Catalogs and schemas
// ISO/IEC 9075-1:2003(E), 4.2.8.2, SQL-schemas
// ISO/IEC 9075-1:2003(E), 4.6, SQL-schema objects
// ISO/IEC 9075-1:2003(E), 4.6.1, General SQL-schema object information

// Represents a schema.
pub struct Schema {
	// The tid is the transaction ID that created this table.
	tid u64
pub:
	// The name of the schema is case-sensitive.
	name string
	// A virtual schema, such as INFORMATION_SCHEMA, only has virtual tables.
	// It is not persisted to disk.
	is_virtual bool
}

// bytes is how the schema is stored in the file: its CREATE SCHEMA statement.
fn (s Schema) bytes() []u8 {
	return 'CREATE SCHEMA ${delimit_identifier(s.name)}'.bytes()
}

fn new_schema_from_bytes(data []u8, tid u64) !Schema {
	stmt := parse_definition(data)!
	if stmt is SchemaDefinition {
		return Schema{
			tid:  tid
			name: stmt.schema_name.schema_name
		}
	}

	return sqlstate_xx001('not a schema definition: ${data.bytestr()}')
}

// Returns the CREATE SCHEMA statement for this schema, including the ';'.
fn (s Schema) str() string {
	return 'CREATE SCHEMA ${delimit_identifier(s.name)};'
}
