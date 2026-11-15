module vsql

// ISO/IEC 9075-11:2006, 5.51, SEQUENCES view
//
// The SEQUENCES view has a row for each sequence (CREATE SEQUENCE), ordered by
// schema and name (Description, 1 of ISO/IEC 9075-11:2006, 6.42, SEQUENCES
// base table). The sequence of an identity column is internal, so it's in
// the COLUMNS view instead.
//
// The data type is described the same way as the data type of a column (see
// data_type_descriptor), and the maximum value, minimum value and increment are
// text (Description, 2 and 3). A sequence without a MAXVALUE or MINVALUE has
// the implicit one (see Sequence.min and Sequence.max). CYCLE_OPTION is YES
// for a CYCLE (Description, 4).
//
// The view only has the sequences that the current user has the USAGE
// privilege on. There are no privileges (#732), so it has every sequence.
fn (mut catalog CatalogConnection) register_sequences_view() ! {
	mut c := &catalog
	id := information_schema_sql_identifier
	cd := information_schema_character_data
	cn := information_schema_cardinal_number
	catalog.add_information_schema_table('CREATE TABLE SEQUENCES (
		SEQUENCE_CATALOG ${id} NOT NULL,
		SEQUENCE_SCHEMA ${id} NOT NULL,
		SEQUENCE_NAME ${id} NOT NULL,
		DATA_TYPE ${cd} NOT NULL,
		NUMERIC_PRECISION ${cn},
		NUMERIC_PRECISION_RADIX ${cn},
		NUMERIC_SCALE ${cn},
		MAXIMUM_VALUE ${cd} NOT NULL,
		MINIMUM_VALUE ${cd} NOT NULL,
		INCREMENT ${cd} NOT NULL,
		CYCLE_OPTION ${information_schema_yes_or_no} NOT NULL
	)',
		fn [mut c] (mut t VirtualTable) ! {
			mut sequences := c.storage.sequences()!
			sequences.sort_with_compare(fn (a &Sequence, b &Sequence) int {
				if a.name.schema_name != b.name.schema_name {
					return if a.name.schema_name < b.name.schema_name { -1 } else { 1 }
				}

				return if a.name.entity_name < b.name.entity_name { -1 } else { 1 }
			})
			for sequence in sequences {
				data_type := data_type_descriptor(c.catalog_name, sequence.typ)
				t.next_values([
					new_varchar_value(c.catalog_name), // SEQUENCE_CATALOG
					new_varchar_value(sequence.name.schema_name), // SEQUENCE_SCHEMA
					new_varchar_value(sequence.name.entity_name), // SEQUENCE_NAME
					data_type[0], // DATA_TYPE
					data_type[3], // NUMERIC_PRECISION
					data_type[4], // NUMERIC_PRECISION_RADIX
					data_type[5], // NUMERIC_SCALE
					new_varchar_value('${sequence.max()}'), // MAXIMUM_VALUE
					new_varchar_value('${sequence.min()}'), // MINIMUM_VALUE
					new_varchar_value('${sequence.increment_by}'), // INCREMENT
					yes_or_no(sequence.cycle), // CYCLE_OPTION
				])
			}
			t.done()
		})!
}
