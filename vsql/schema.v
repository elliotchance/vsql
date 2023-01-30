// schema.v contains the structure of a schema.

module vsql

// Represents a schema.
//
// snippet: v.Schema
pub struct Schema {
	// The tid is the transaction ID that created this table.
	tid int
pub:
	// The name of the schema is case-sensitive.
	//
	// snippet: v.Schema.name
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
//
// snippet: v.Schema.str
fn (s Schema) str() string {
	return 'CREATE SCHEMA ${s.name};'
}
