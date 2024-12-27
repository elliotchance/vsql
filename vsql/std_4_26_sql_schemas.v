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

fn (s Schema) bytes() []u8 {
	mut b := new_empty_bytes()
	b.write_string1(s.name)

	return b.bytes()
}

fn new_schema_from_bytes(data []u8, tid int) Schema {
	mut b := new_bytes(data)

	schema_name := b.read_string1()

	return Schema{tid, schema_name}
}

// Returns the CREATE SCHEMA statement for this schema, including the ';'.
fn (s Schema) str() string {
	return 'CREATE SCHEMA ${s.name};'
}
