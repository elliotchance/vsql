module vsql

// ISO/IEC 9075-2:2016(E), 11.20, <alter identity column specification>
//
// Change the options specified for an identity column.

// The options are RESTART and SET followed by a <basic sequence generator
// option>, such as "SET INCREMENT BY 2".
struct AlterIdentityColumnSpecification {
	options []SequenceGeneratorOption
}

// execute returns the column with its sequence changed by the options, like an
// ALTER SEQUENCE, and the sequence with its new current value. A MINVALUE or
// MAXVALUE that's removed (NO MINVALUE or NO MAXVALUE) is the default for the
// column again (see new_identity_sequence). There's no SET GENERATED (F386).
//
// ISO/IEC 9075-2:2016(E), 11.20, <alter identity column specification>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 11.20, <alter identity column specification>, General Rules, 1
fn (s AlterIdentityColumnSpecification) execute(mut conn Connection, table Table, column Column) !(Column, Sequence) {
	check_sequence_options(s.options)!
	identity := column.identity or { return error('not an identity column') }
	mut catalog := conn.catalog_for(table.name)
	mut sequence := alter_sequence(mut conn, map[string]Value{}, catalog.storage.identity_sequence(table)!,
		s.options)!
	min, max := identity_range(column.typ, sequence.increment_by)
	if !sequence.has_min_value {
		sequence.has_min_value = true
		sequence.min_value = min
	}
	if !sequence.has_max_value {
		sequence.has_max_value = true
		sequence.max_value = max
	}
	check_identity_sequence(column.typ, sequence)!

	return Column{
		...column
		identity: IdentityColumn{
			...identity
			options:  sequence.identity_options()
			sequence: sequence
		}
	}, sequence
}
