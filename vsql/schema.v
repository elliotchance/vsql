// schema.v contains the structure of a schema.

module vsql

struct Schema {
	name string
	// The tid is the transaction ID that created this table.
	tid int
}

fn (s Schema) bytes() []u8 {
	mut b := new_empty_bytes()
	b.write_string1(s.name)

	return b.bytes()
}

fn new_schema_from_bytes(data []u8, tid int) Schema {
	mut b := new_bytes(data)

	schema_name := b.read_string1()

	return Schema{schema_name, tid}
}
