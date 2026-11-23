module vsql

import crypto.rand
import time

// The functions that generate a UUID (RFC 9562) and convert one between its
// text and a BINARY(16) (V407-01 to V407-04). The SQL standard doesn't have a
// UUID type, so a UUID is the usual text: 32 lower case hexadecimal digits in
// groups of 8, 4, 4, 4 and 12 separated by dashes. The random bits come from
// the operating system's cryptographically secure generator (crypto.rand, not
// the rand that RANDOM() uses), so a UUID can't be predicted from the ones
// before it, see docs/functions.rst.

fn register_uuid_funcs(mut conn Connection) ! {
	uuid_text := Type{SQLType.is_varchar, 36, 0, false, false}
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	varbinary := Type{SQLType.is_varbinary, 0, 0, false, false}
	uuid_binary := Type{SQLType.is_binary, 16, 0, false, false}

	// The generators return a different value each time they're called, so
	// they're NOT DETERMINISTIC, like RANDOM().
	conn.register_func(Func{'GENERATE_UUID_V4', [], false, fn (_ FunctionContext, _ []Value) !Value {
		return new_varchar_value(uuid_str(uuid_octets(4, rand.bytes(16)!)))
	}, uuid_text, false, false, [vsql_generate_uuid_v4], [], false})!
	conn.register_func(Func{'GENERATE_UUID_V7', [], false, fn (ctx FunctionContext, _ []Value) !Value {
		return new_varchar_value(uuid_str(uuid_v7(ctx, rand.bytes(16)!)))
	}, uuid_text, false, false, [vsql_generate_uuid_v7], [], false})!
	conn.register_func(Func{'UUID_TO_BINARY', [varchar], false, fn (_ FunctionContext, args []Value) !Value {
		return new_binary_value(uuid_parse(args[0].string_value())!)
	}, uuid_binary, false, true, [vsql_uuid_to_binary], [], false})!
	conn.register_func(Func{'BINARY_TO_UUID', [varbinary], false, fn (_ FunctionContext, args []Value) !Value {
		octets := args[0].string_value().bytes()
		if octets.len != 16 {
			return sqlstate_22018()
		}

		return new_varchar_value(uuid_str(octets))
	}, uuid_text, false, true, [vsql_binary_to_uuid], [], false})!
}

// uuid_octets sets the version (the high 4 bits of octet 6) and the variant
// (the high 2 bits of octet 8 are 10) of the random octets.
//
// RFC 9562, 4.1 Variant Field and 4.2 Version Field
fn uuid_octets(version u8, random []u8) []u8 {
	mut octets := random.clone()
	octets[6] = (octets[6] & 0x0f) | (version << 4)
	octets[8] = (octets[8] & 0x3f) | 0x80
	return octets
}

// uuid_v7 starts with the Unix time in milliseconds (48 bits), followed by
// the version and 12 bits of the fraction of the millisecond, and the rest is
// random. The time of each UUID that a connection generates is at least one
// more (1/4096 of a millisecond) than the last, so they're in the order they
// were generated, even when the clock is coarse or goes backwards.
//
// RFC 9562, 5.7 UUID Version 7 and 6.2 Monotonicity and Counters, Method 3
fn uuid_v7(ctx FunctionContext, random []u8) []u8 {
	nanos := u64(time.now().unix_nano())
	now := (nanos / 1_000_000) << 12 | (nanos % 1_000_000) * 4096 / 1_000_000
	mut conn := unsafe { ctx.conn }
	timestamp := if now > conn.uuid_v7_timestamp { now } else { conn.uuid_v7_timestamp + 1 }
	conn.uuid_v7_timestamp = timestamp

	mut octets := uuid_octets(7, random)
	millis := timestamp >> 12
	for i in 0 .. 6 {
		octets[i] = u8(millis >> (40 - 8 * i))
	}
	octets[6] = 0x70 | u8(timestamp >> 8 & 0x0f)
	octets[7] = u8(timestamp)
	return octets
}

// uuid_str is the text of a UUID: lower case hexadecimal digits with dashes.
//
// RFC 9562, 4 UUID Format
fn uuid_str(octets []u8) string {
	digits := octets.hex()
	return '${digits[..8]}-${digits[8..12]}-${digits[12..16]}-${digits[16..20]}-${digits[20..]}'
}

// uuid_parse is the octets of the text of a UUID, with the digits in upper or
// lower case. Anything else is a 22018 error.
fn uuid_parse(text string) ![]u8 {
	if text.len != 36 || text[8] != `-` || text[13] != `-` || text[18] != `-`
		|| text[23] != `-` {
		return sqlstate_22018()
	}

	return unhex_digits(text[..8] + text[9..13] + text[14..18] + text[19..23] + text[24..])!.bytes()
}
