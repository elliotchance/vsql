module vsql

// ISO/IEC 9075-2:2016(E), 4.26, SQL-schemas

// Represents a schema.
pub struct Schema {
	// The tid is the transaction ID that created this table.
	tid int
pub:
	// The name of the schema is case-sensitive.
	name string
}

// bytes is how the schema is stored in the file: its CREATE SCHEMA statement.
fn (s Schema) bytes() []u8 {
	return 'CREATE SCHEMA ${delimit_identifier(s.name)}'.bytes()
}

fn new_schema_from_bytes(data []u8, tid int) !Schema {
	stmt := parse_definition(data)!
	if stmt is SchemaDefinition {
		return Schema{tid, stmt.schema_name.schema_name}
	}

	return error('not a schema definition: ${data.bytestr()}')
}

// Returns the CREATE SCHEMA statement for this schema, including the ';'.
fn (s Schema) str() string {
	return 'CREATE SCHEMA ${s.name};'
}
