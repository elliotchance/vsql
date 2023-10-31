module vsql

// ISO/IEC 9075-2:2016(E), 4.27, Sequence generators

// A SEQUENCE definition.
pub struct Sequence {
mut:
	// The tid is the transaction ID that created this table.
	tid int
pub mut:
	// name contains the other parts such as the schema.
	name Identifier
	// current_value is the current value before it is incremented by
	// "NEXT VALUE FOR".
	current_value i64
	// increment_by is added for each next value and defaults to 1.
	increment_by i64
	// cycle allows the sequence to repeat once MAXVALUE is reached. By default it
	// is not enabled.
	cycle bool
	// has_min_value is true when a MINVALUE is set.
	has_min_value bool
	// min_value is the smallest inclusive value allowed for the sequence. The
	// MINVALUE is optional.
	min_value i64
	// has_max_value is true when a MAXVALUE is set.
	has_max_value bool
	// max_value is the largest inclusive value allowed for the sequence. The
	// MAXVALUE is optional.
	max_value i64
}

// str returns the CREATE SEQUENCE definition (including the ';') like:
//
//   CREATE SEQUENCE "foo" START WITH 12 NO MINVALUE NO MAXVALUE;
pub fn (s Sequence) str() string {
	mut parts := ['CREATE SEQUENCE ${s.name} START WITH ${s.current_value}']

	if s.increment_by != 1 {
		parts << 'INCREMENT BY ${s.increment_by}'
	}

	if s.has_min_value {
		parts << 'MINVALUE ${s.min_value}'
	}

	if s.has_max_value {
		parts << 'MAXVALUE ${s.max_value}'
	}

	return parts.join(' ') + ';'
}

fn (s Sequence) copy() Sequence {
	return Sequence{s.tid, s.name, s.current_value, s.increment_by, s.cycle, s.has_min_value, s.min_value, s.has_max_value, s.max_value}
}

fn (s Sequence) reset() i64 {
	if s.increment_by > 0 && s.has_min_value {
		return s.min_value
	}

	if s.increment_by < 0 && s.has_max_value {
		return s.max_value
	}

	return 1
}

fn (s Sequence) next() !Sequence {
	mut next_value := s.current_value + s.increment_by
	if s.has_max_value && next_value > s.max_value {
		if !s.cycle {
			return sqlstate_2200h(s.name.str())
		}

		next_value = s.reset()
	}

	if s.has_min_value && next_value < s.min_value {
		if !s.cycle {
			return sqlstate_2200h(s.name.str())
		}

		next_value = s.reset()
	}

	return Sequence{s.tid, s.name, next_value, s.increment_by, s.cycle, s.has_min_value, s.min_value, s.has_max_value, s.max_value}
}

fn (s Sequence) definition_bytes() []u8 {
	mut b := new_empty_bytes()

	b.write_string1(s.name.storage_id())
	b.write_i64(s.increment_by)
	b.write_bool(s.cycle)
	b.write_optional_i64(s.has_min_value, s.min_value)
	b.write_optional_i64(s.has_max_value, s.max_value)

	return b.bytes()
}

fn (s Sequence) value_bytes() []u8 {
	mut b := new_empty_bytes()

	b.write_i64(s.current_value)

	return b.bytes()
}

fn new_sequence_from_bytes(definition_data []u8, value_data []u8, tid int) Sequence {
	mut b1 := new_bytes(definition_data)
	sequence_name := b1.read_identifier()
	increment_by := b1.read_i64()
	cycle := b1.read_bool()
	has_min_value, min_value := b1.read_optional_i64()
	has_max_value, max_value := b1.read_optional_i64()

	mut b2 := new_bytes(value_data)
	current_value := b2.read_i64()

	return Sequence{tid, sequence_name, current_value, increment_by, cycle, has_min_value, min_value, has_max_value, max_value}
}
