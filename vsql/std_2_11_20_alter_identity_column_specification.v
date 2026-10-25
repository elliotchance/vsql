module vsql

// ISO/IEC 9075-2:2016(E), 11.20, <alter identity column specification>
//
// Change the options specified for an identity column.

// The only option is RESTART (with or without a value). SET followed by a
// <basic sequence generator option>, such as "SET INCREMENT BY 2", isn't
// supported yet.
struct AlterIdentityColumnSpecification {
	options []SequenceGeneratorOption
}

// execute returns the column and its sequence with the new current value
// (General Rule 1). RESTART doesn't change the definition of the column.
fn (s AlterIdentityColumnSpecification) execute(mut conn Connection, table Table, column Column) !(Column, Sequence) {
	check_sequence_options(s.options)!
	mut catalog := conn.catalog_for(table.name)
	sequence := alter_sequence(mut conn, map[string]Value{}, catalog.storage.identity_sequence(table)!,
		s.options)!

	return column, sequence
}
