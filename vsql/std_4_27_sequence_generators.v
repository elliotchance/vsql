module vsql

// ISO/IEC 9075-2:2016(E), 4.27, Sequence generators

// A SEQUENCE definition.
pub struct Sequence {
mut:
	// The tid is the transaction ID that created this table.
	tid u64
	// exhausted is true when current_value is the last value that can be
	// returned, because adding increment_by would go past the range of a BIGINT.
	// See next.
	exhausted bool
	// unused is true when current_value plus increment_by (the current base
	// value) hasn't been returned by NEXT VALUE FOR yet, which is a new sequence
	// or one that has been restarted. Otherwise current_value is the last value
	// that was returned. ALTER SEQUENCE needs to know which, see
	// AlterSequenceGeneratorStatement.
	unused bool
pub mut:
	// name contains the other parts such as the schema.
	name Identifier
	// start_value is the START WITH value. If START WITH isn't given, it's the
	// MINVALUE (or MAXVALUE for a descending sequence), otherwise 1. It's used
	// by "ALTER SEQUENCE ... RESTART".
	start_value i64
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
//   CREATE SEQUENCE "PUBLIC"."foo" START WITH 12 MINVALUE 10;
pub fn (s Sequence) str() string {
	mut parts := ['CREATE SEQUENCE ${s.name.storage_sql()} START WITH ${s.start_value}']

	if s.increment_by != 1 {
		parts << 'INCREMENT BY ${s.increment_by}'
	}

	if s.has_min_value {
		parts << 'MINVALUE ${s.min_value}'
	}

	if s.has_max_value {
		parts << 'MAXVALUE ${s.max_value}'
	}

	if s.cycle {
		parts << 'CYCLE'
	}

	return parts.join(' ') + ';'
}

fn (s Sequence) copy() Sequence {
	return Sequence{
		...s
	}
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

// check is used by CREATE SEQUENCE and ALTER SEQUENCE (9.30 and 9.31 Syntax
// Rules).
fn (s Sequence) check() ! {
	if s.increment_by == 0 {
		return sqlstate_42601('INCREMENT BY must not be 0')
	}

	if s.has_min_value && s.has_max_value && s.min_value >= s.max_value {
		return sqlstate_42601('MAXVALUE (${s.max_value}) must be greater than MINVALUE (${s.min_value})')
	}
}

// check_in_range is used for the START WITH and RESTART WITH values.
fn (s Sequence) check_in_range(name string, value i64) ! {
	if s.has_min_value && value < s.min_value {
		return sqlstate_42601('${name} (${value}) must not be less than MINVALUE (${s.min_value})')
	}

	if s.has_max_value && value > s.max_value {
		return sqlstate_42601('${name} (${value}) must not be greater than MAXVALUE (${s.max_value})')
	}
}

// next_value returns the value that "NEXT VALUE FOR" will return next, or none
// if the sequence has gone past its limit. In that case "NEXT VALUE FOR" will
// either start again (CYCLE) or raise an error.
pub fn (s Sequence) next_value() ?i64 {
	// A new sequence stores START WITH minus INCREMENT BY as the current_value,
	// which can wrap around (for example, START WITH -9223372036854775808). So
	// when adding increment_by goes past the range of a BIGINT, it's only the
	// limit of the sequence if the previous value was the last one (exhausted).
	// Otherwise, the wrapped value is the START WITH.
	next_value, overflow := add_i64(s.current_value, s.increment_by)
	if (overflow && s.exhausted) || (s.has_max_value && next_value > s.max_value)
		|| (s.has_min_value && next_value < s.min_value) {
		return none
	}

	return next_value
}

fn (s Sequence) next() !Sequence {
	next_value := s.next_value() or {
		if !s.cycle {
			return sqlstate_2200h(s.name.str())
		}

		s.reset()
	}

	_, exhausted := add_i64(next_value, s.increment_by)

	return Sequence{
		...s
		current_value: next_value
		exhausted:     exhausted
		unused:        false
	}
}

// add_i64 returns a + b, and true if the result went past the range of an i64
// (in which case the result wraps around).
fn add_i64(a i64, b i64) (i64, bool) {
	overflow := (b > 0 && a > max_i64 - b) || (b < 0 && a < min_i64 - b)

	return i64(u64(a) + u64(b)), overflow
}

// definition_bytes is how the sequence is stored in the file: its CREATE
// SEQUENCE statement, with each option on its own line, like:
//
//   CREATE SEQUENCE "PUBLIC"."SEQ1"
//     START WITH 10
//     INCREMENT BY 5
//     MINVALUE 10
//
// The current value is stored separately, see value_bytes.
fn (s Sequence) definition_bytes() []u8 {
	mut parts := ['CREATE SEQUENCE ${s.name.storage_sql()}', 'START WITH ${s.start_value}',
		'INCREMENT BY ${s.increment_by}']

	if s.has_min_value {
		parts << 'MINVALUE ${s.min_value}'
	}

	if s.has_max_value {
		parts << 'MAXVALUE ${s.max_value}'
	}

	if s.cycle {
		parts << 'CYCLE'
	}

	return parts.join('\n  ').bytes()
}

fn (s Sequence) value_bytes() []u8 {
	mut b := new_empty_bytes()

	b.write_i64(s.current_value)

	// These are only written when they're needed, so that a sequence that has
	// been used and hasn't reached its limit is stored the same as before they
	// existed. Only unused is new, so a version of vsql before it reads an unused
	// sequence as a used one, which only differs for ALTER SEQUENCE.
	if s.exhausted || s.unused {
		b.write_bool(s.exhausted)
	}
	if s.unused {
		b.write_bool(true)
	}

	return b.bytes()
}

fn new_sequence_from_bytes(definition_data []u8, value_data []u8, tid u64) !Sequence {
	stmt := parse_definition(definition_data)!
	if stmt is SequenceGeneratorDefinition {
		mut sequence := stmt.sequence(Identifier{
			schema_name: stmt.name.schema_name
			entity_name: stmt.name.entity_name
		})
		sequence.tid = tid

		mut b := new_bytes(value_data)
		sequence.current_value = b.read_i64()
		sequence.unused = false
		if b.has_more() {
			sequence.exhausted = b.read_bool()
		}
		if b.has_more() {
			sequence.unused = b.read_bool()
		}

		return sequence
	}

	return sqlstate_xx001('not a sequence definition: ${definition_data.bytestr()}')
}
