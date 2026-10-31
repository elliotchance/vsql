module vsql

// ISO/IEC 9075-2:2016(E), 4.27, Sequence generators
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.6.11, Sequence
// generators.

// A SEQUENCE definition, which is the sequence generator descriptor. The data
// type is always BIGINT (#399). The current base value is current_value plus
// increment_by when the sequence is unused, otherwise the next value after
// current_value.
//
// ISO/IEC 9075-2:2016(E), 9.30, Creation of a sequence generator, General Rules, 2
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
	// minimum value (or the maximum value for a descending sequence), which is 1
	// (or -1) without a MINVALUE (or MAXVALUE). It's used by "ALTER SEQUENCE ...
	// RESTART".
	start_value i64
	// current_value is the current value before it is incremented by
	// "NEXT VALUE FOR".
	current_value i64
	// increment_by is added for each next value and defaults to 1.
	increment_by i64
	// cycle allows the sequence to repeat once MAXVALUE is reached. By default it
	// is not enabled.
	cycle bool
	// has_min_value is true when a MINVALUE is set. Otherwise, the minimum
	// value is implicit, see min.
	has_min_value bool
	// min_value is the smallest inclusive value allowed for the sequence. The
	// MINVALUE is optional.
	min_value i64
	// has_max_value is true when a MAXVALUE is set. Otherwise, the maximum
	// value is implicit, see max.
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

// min is the minimum value of the sequence. Without a MINVALUE, it's
// implementation-defined. Like PostgreSQL (and identity columns, see
// identity_range), it's 1 for an ascending sequence, and the smallest BIGINT for
// a descending one.
//
// ISO/IEC 9075-2:2016(E), 9.30, Creation of a sequence generator, Syntax Rules, 8
// ISO/IEC 9075-2:2016(E), 9.31, Altering a sequence generator, Syntax Rules, 7.a.i
fn (s Sequence) min() i64 {
	if s.has_min_value {
		return s.min_value
	}

	if s.increment_by > 0 {
		return 1
	}

	return min_i64
}

// max is the maximum value of the sequence. Without a MAXVALUE, it's
// implementation-defined: the largest BIGINT for an ascending sequence, and -1
// for a descending one (see min).
//
// ISO/IEC 9075-2:2016(E), 9.30, Creation of a sequence generator, Syntax Rules, 7
// ISO/IEC 9075-2:2016(E), 9.31, Altering a sequence generator, Syntax Rules, 6.a.i
fn (s Sequence) max() i64 {
	if s.has_max_value {
		return s.max_value
	}

	if s.increment_by > 0 {
		return max_i64
	}

	return -1
}

// reset is the first value of a new cycle: the minimum value of an ascending
// sequence, or the maximum value of a descending one.
//
// ISO/IEC 9075-2:2016(E), 9.29, Generation of the next value of a sequence generator, General Rules, 3.b
fn (s Sequence) reset() i64 {
	if s.increment_by > 0 {
		return s.min()
	}

	return s.max()
}

// check is used by CREATE SEQUENCE and ALTER SEQUENCE.
//
// ISO/IEC 9075-2:2016(E), 9.30, Creation of a sequence generator, Syntax Rules, 5 and 11
// ISO/IEC 9075-2:2016(E), 9.31, Altering a sequence generator, Syntax Rules, 5.a.ii and 11
fn (s Sequence) check() ! {
	if s.increment_by == 0 {
		return sqlstate_42601('INCREMENT BY must not be 0')
	}

	if s.min() >= s.max() {
		return sqlstate_42601('MAXVALUE (${s.max()}) must be greater than MINVALUE (${s.min()})')
	}
}

// check_in_range is used for the START WITH and RESTART WITH values.
//
// ISO/IEC 9075-2:2016(E), 9.30, Creation of a sequence generator, Syntax Rules, 12
// ISO/IEC 9075-2:2016(E), 9.31, Altering a sequence generator, Syntax Rules, 12
fn (s Sequence) check_in_range(name string, value i64) ! {
	if value < s.min() {
		return sqlstate_42601('${name} (${value}) must not be less than MINVALUE (${s.min()})')
	}

	if value > s.max() {
		return sqlstate_42601('${name} (${value}) must not be greater than MAXVALUE (${s.max()})')
	}
}

// next_value returns the value that "NEXT VALUE FOR" will return next, or none
// if the sequence has gone past its limit. In that case "NEXT VALUE FOR" will
// either start again (CYCLE) or raise an error.
//
// ISO/IEC 9075-2:2016(E), 9.29, Generation of the next value of a sequence generator, General Rules, 3
pub fn (s Sequence) next_value() ?i64 {
	// A new sequence stores START WITH minus INCREMENT BY as the current_value,
	// which can wrap around (for example, START WITH -9223372036854775808). So
	// when adding increment_by goes past the range of a BIGINT, it's only the
	// limit of the sequence if the previous value was the last one (exhausted).
	// Otherwise, the wrapped value is the START WITH.
	next_value, overflow := add_i64(s.current_value, s.increment_by)
	if (overflow && s.exhausted) || next_value > s.max() || next_value < s.min() {
		return none
	}

	return next_value
}

// next is the sequence after NEXT VALUE FOR, which is current_value. Without
// CYCLE, it's 2200H (sequence generator limit exceeded) when there are no more
// values.
//
// ISO/IEC 9075-2:2016(E), 9.29, Generation of the next value of a sequence generator, General Rules, 1-5
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

		return sequence.with_value(value_data).with_old_implicit_limits()
	}

	return sqlstate_xx001('not a sequence definition: ${definition_data.bytestr()}')
}

// with_value returns the sequence with the current value that was stored by
// value_bytes.
fn (s Sequence) with_value(value_data []u8) Sequence {
	mut b := new_bytes(value_data)
	mut sequence := Sequence{
		...s
		current_value: b.read_i64()
		exhausted:     false
		unused:        false
	}
	if b.has_more() {
		sequence.exhausted = b.read_bool()
	}
	if b.has_more() {
		sequence.unused = b.read_bool()
	}

	return sequence
}

// with_old_implicit_limits keeps a sequence from a file created by an older
// version of vsql working. The implicit MINVALUE and MAXVALUE used to be the
// range of a BIGINT, and they aren't stored in the definition. So when the START
// WITH or the current value is outside of the implicit limit (see min and max),
// the sequence keeps the BIGINT limit instead.
fn (s Sequence) with_old_implicit_limits() Sequence {
	mut sequence := s.copy()
	mut values := [s.start_value]
	if !s.unused {
		values << s.current_value
	}
	for value in values {
		if !sequence.has_min_value && value < s.min() {
			sequence.has_min_value = true
			sequence.min_value = min_i64
		}
		if !sequence.has_max_value && value > s.max() {
			sequence.has_max_value = true
			sequence.max_value = max_i64
		}
	}

	return sequence
}

// identity_options are the options that define the sequence of an identity
// column (see IdentityColumn.str).
fn (s Sequence) identity_options() []SequenceGeneratorOption {
	mut options := [
		SequenceGeneratorOption(SequenceGeneratorStartWithOption{new_bigint_value(s.start_value)}),
		SequenceGeneratorIncrementByOption{new_bigint_value(s.increment_by)},
		SequenceGeneratorMinvalueOption{new_bigint_value(s.min_value)},
		SequenceGeneratorMaxvalueOption{new_bigint_value(s.max_value)},
	]
	if s.cycle {
		options << SequenceGeneratorCycleOption{true}
	}

	return options
}
