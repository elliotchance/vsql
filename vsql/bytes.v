// bytes.v contains a byte stream that can be read from and written to.
//
// The buffer will always use big-endian to make sure data remains compatiable
// across platforms and the byte order is ideal for sorting.

module vsql

import runtime

// BytesWriter allows a buffer to be written to. All values are appended to the
// end.
interface BytesWriter {
mut:
	write_bool(data bool)
	write_f32(data f32)
	write_f64(data f64)
	write_i16(data i16)
	write_i32(data int)
	write_i64(data i64)
	write_optional_i64(is_set bool, data i64)
	// write_string1 is safe to use for short strings (less then 128 bytes).
	write_string1(s string)
	// write_string4 is safe to use for long strings (up to 2GB).
	write_string4(s string)
	write_identifier(identifier Identifier)
	write_u8(data u8)
	// write_u8s does not undergo any endian conversion so it's important not to
	// use this to write the binary representations of ints, etc. It should only
	// be used for writing and reading raw binary data.
	write_u8s(data []u8)
	write_u16(data u16)
	write_u64(data u64)
}

// BytesReader allows a buffer to be read, but also allows the position to be
// moved around.
//
// BytesReader does not return errors because it's expect the caller knows when
// the buffer ends. Trying to read beyond the end of the buffer will result in a
// panic.
interface BytesReader {
mut:
	read_bool() bool
	read_f32() f32
	read_f64() f64
	read_i16() i16
	read_i32() int
	read_i64() i64
	read_optional_i64() (bool, i64)
	// read_string1 is the opposite of write_string1. It allows for strings up
	// to 128 bytes (number of characters may be less).
	read_string1() string
	// read_string4 is the opposite of write_string4. It allows for strings up
	// to 2GB (number of characters may be less).
	read_string4() string
	read_identifier() Identifier
	read_u8() u8
	// read_u8s does not undergo any endian conversion so it's important not to
	// use this to write the binary representations of ints, etc. It should only
	// be used for writing and reading raw ordered binary data.
	read_u8s(len int) []u8
	read_u16() u16
	read_u64() u64
	// bytes returns the entire buffer. It does not move the current position.
	bytes() []u8
	// has_more can be used by the reader to see if we're at the end.
	has_more() bool
	// pos and set_pos to intereact with the position (affects futures reads and
	// writes)
	pos() int
	set_pos(pos int)
}

// BytesReaderWriter can be read and written at any point. These interfaces
// exist to wrap around different implementations that need to exist for little
// and big-endian systems.
interface BytesReaderWriter {
	BytesReader
	BytesWriter
}

// BytesLittleEndian is used on little-endian architectures. You will not
// interact with this instance directly, use BytesReaderWriter instead.
//
// Little-endian is more efficient from a CPU point of view, but it's not ideal
// for storing data in a way that is ordered. So we reverse the order of bytes
// (convert to big-endian)
struct BytesLittleEndian {
mut:
	bytes BytesBigEndian
}

fn (mut b BytesLittleEndian) set_pos(pos int) {
	b.bytes.set_pos(pos)
}

fn (mut b BytesLittleEndian) pos() int {
	return b.bytes.pos()
}

fn (mut b BytesLittleEndian) bytes() []u8 {
	// There is no endian conversion required because that was done as the
	// original data was written.
	return b.bytes.data
}

fn (mut b BytesLittleEndian) write_u8(d u8) {
	// There is endian conversion need for a single byte.
	b.bytes.write_u8(d)
}

fn (mut b BytesLittleEndian) write_bool(d bool) {
	// There is endian conversion need for a single byte.
	b.bytes.write_bool(d)
}

fn (mut b BytesLittleEndian) read_bool() bool {
	// There is endian conversion need for a single byte.
	return b.bytes.read_bool()
}

fn (mut b BytesLittleEndian) read_u8() u8 {
	// There is endian conversion need for a single byte.
	return b.bytes.read_u8()
}

fn (mut b BytesLittleEndian) write_u8s(data []u8) {
	// As documented on the interface, u8s does not undergo any endian
	// conversion.
	b.bytes.write_u8s(data)
}

fn (mut b BytesLittleEndian) read_u8s(len int) []u8 {
	// As documented on the interface, u8s does not undergo any endian
	// conversion.
	return b.bytes.read_u8s(len)
}

fn (mut b BytesLittleEndian) write_i32(data int) {
	b.write_u8s(Bytes4{
		int_value: data
	}.bytes_reversed())
}

fn (mut b BytesLittleEndian) read_i32() int {
	// This needs to be converted from big-endian (that's the reverse order).
	bytes := b.read_u8s(4)
	return unsafe {
		Bytes4{
			bytes: [bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.int_value
	}
}

fn (mut b BytesLittleEndian) write_i16(data i16) {
	b.write_u8s(Bytes2{ i16_value: data }.bytes_reversed())
}

fn (mut b BytesLittleEndian) read_i16() i16 {
	// This needs to be converted from big-endian (that's the reverse order).
	bytes := b.read_u8s(2)
	return unsafe {
		Bytes2{
			bytes: [bytes[1], bytes[0]]!
		}.i16_value
	}
}

fn (mut b BytesLittleEndian) write_u16(data u16) {
	b.write_u8s(Bytes2{ u16_value: data }.bytes_reversed())
}

fn (mut b BytesLittleEndian) read_u16() u16 {
	// This needs to be converted from big-endian (that's the reverse order).
	bytes := b.read_u8s(2)
	return unsafe {
		Bytes2{
			bytes: [bytes[1], bytes[0]]!
		}.u16_value
	}
}

fn (mut b BytesLittleEndian) write_i64(data i64) {
	b.write_u8s(Bytes8{
		i64_value: data
	}.bytes_reversed())
}

fn (mut b BytesLittleEndian) write_optional_i64(is_set bool, data i64) {
	b.write_bool(is_set)
	if is_set {
		b.write_i64(data)
	}
}

fn (mut b BytesLittleEndian) write_u64(data u64) {
	b.write_u8s(Bytes8{
		u64_value: data
	}.bytes_reversed())
}

fn (mut b BytesLittleEndian) read_i64() i64 {
	// This needs to be converted from big-endian (that's the reverse order).
	bytes := b.read_u8s(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.i64_value
	}
}

fn (mut b BytesLittleEndian) read_optional_i64() (bool, i64) {
	is_set := b.read_bool()
	if is_set {
		return true, b.read_i64()
	}

	return false, 0
}

fn (mut b BytesLittleEndian) read_u64() u64 {
	// This needs to be converted from big-endian (that's the reverse order).
	bytes := b.read_u8s(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.u64_value
	}
}

fn (mut b BytesLittleEndian) write_f64(data f64) {
	b.write_u8s(Bytes8{ f64_value: data }.bytes_reversed())
}

fn (mut b BytesLittleEndian) write_f32(data f32) {
	b.write_u8s(Bytes4{ f32_value: data }.bytes_reversed())
}

fn (mut b BytesLittleEndian) read_f32() f32 {
	// This needs to be converted from big-endian (that's the reverse order).
	bytes := b.read_u8s(4)
	return unsafe {
		Bytes4{
			bytes: [bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.f32_value
	}
}

fn (mut b BytesLittleEndian) read_f64() f64 {
	// This needs to be converted from big-endian (that's the reverse order).
	bytes := b.read_u8s(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.f64_value
	}
}

fn (mut b BytesLittleEndian) write_string1(s string) {
	b.write_u8(u8(s.len))
	b.write_u8s(s.bytes())
}

fn (mut b BytesLittleEndian) write_identifier(identifier Identifier) {
	b.write_string1(identifier.storage_id())
}

fn (mut b BytesLittleEndian) read_string1() string {
	len := b.read_u8()

	return b.read_string(len)
}

fn (mut b BytesLittleEndian) read_identifier() Identifier {
	return decode_identifier(b.read_string1())
}

fn (mut b BytesLittleEndian) read_string(len int) string {
	return b.read_u8s(len).bytestr()
}

fn (b BytesLittleEndian) has_more() bool {
	return b.bytes.has_more()
}

fn (mut b BytesLittleEndian) write_string4(s string) {
	b.write_i32(s.len)
	b.write_u8s(s.bytes())
}

fn (mut b BytesLittleEndian) read_string4() string {
	return b.read_string(b.read_i32())
}

// BytesBigEndian is used on big-endian systems. You will not interact with this
// instance directly, use BytesReaderWriter instead.
struct BytesBigEndian {
mut:
	at   int
	data []u8
}

fn (mut b BytesBigEndian) pos() int {
	return b.at
}

fn (mut b BytesBigEndian) set_pos(pos int) {
	b.at = pos
}

fn (mut b BytesBigEndian) bytes() []u8 {
	return b.data
}

fn (mut b BytesBigEndian) write_u8(d u8) {
	if b.at < b.data.len {
		b.data[b.at] = d
	} else {
		b.data << d
	}
	b.at++
}

fn (mut b BytesBigEndian) write_bool(d bool) {
	b.write_u8(if d { u8(1) } else { 0 })
}

fn (mut b BytesBigEndian) read_bool() bool {
	return b.read_u8() != 0
}

fn (mut b BytesBigEndian) read_u8() u8 {
	b.at++
	return b.data[b.at - 1]
}

fn (mut b BytesBigEndian) write_u8s(data []u8) {
	// As documented on the interface, u8s does not undergo any endian
	// conversion.
	//
	// TODO(elliotchance): Surely there is a more efficient way to copy a block
	//  of data.
	for d in data {
		b.write_u8(d)
	}
}

fn (mut b BytesBigEndian) read_u8s(len int) []u8 {
	// As documented on the interface, u8s does not undergo any endian
	// conversion.
	data := b.data[b.at..b.at + len]
	b.at += len

	return data.clone()
}

fn (mut b BytesBigEndian) write_i32(data int) {
	b.write_u8s(Bytes4{
		int_value: data
	}.bytes())
}

fn (mut b BytesBigEndian) read_i32() int {
	bytes := b.read_u8s(4)
	return unsafe {
		Bytes4{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3]]!
		}.int_value
	}
}

fn (mut b BytesBigEndian) write_i16(data i16) {
	b.write_u8s(Bytes2{ i16_value: data }.bytes())
}

fn (mut b BytesBigEndian) read_i16() i16 {
	bytes := b.read_u8s(2)
	return unsafe {
		Bytes2{
			bytes: [bytes[0], bytes[1]]!
		}.i16_value
	}
}

fn (mut b BytesBigEndian) write_u16(data u16) {
	b.write_u8s(Bytes2{ u16_value: data }.bytes())
}

fn (mut b BytesBigEndian) read_u16() u16 {
	bytes := b.read_u8s(2)
	return unsafe {
		Bytes2{
			bytes: [bytes[0], bytes[1]]!
		}.u16_value
	}
}

fn (mut b BytesBigEndian) write_i64(data i64) {
	b.write_u8s(Bytes8{
		i64_value: data
	}.bytes())
}

fn (mut b BytesBigEndian) write_optional_i64(is_set bool, data i64) {
	b.write_bool(is_set)
	if is_set {
		b.write_i64(data)
	}
}

fn (mut b BytesBigEndian) write_u64(data u64) {
	b.write_u8s(Bytes8{
		u64_value: data
	}.bytes())
}

fn (mut b BytesBigEndian) read_i64() i64 {
	bytes := b.read_u8s(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]]!
		}.i64_value
	}
}

fn (mut b BytesBigEndian) read_optional_i64() (bool, i64) {
	is_set := b.read_bool()
	if is_set {
		return true, b.read_i64()
	}

	return false, 0
}

fn (mut b BytesBigEndian) read_u64() u64 {
	bytes := b.read_u8s(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]]!
		}.u64_value
	}
}

fn (mut b BytesBigEndian) write_f64(data f64) {
	b.write_u8s(Bytes8{ f64_value: data }.bytes())
}

fn (mut b BytesBigEndian) write_f32(data f32) {
	b.write_u8s(Bytes4{ f32_value: data }.bytes())
}

fn (mut b BytesBigEndian) read_f32() f32 {
	bytes := b.read_u8s(4)
	return unsafe {
		Bytes4{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3]]!
		}.f32_value
	}
}

fn (mut b BytesBigEndian) read_f64() f64 {
	bytes := b.read_u8s(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]]!
		}.f64_value
	}
}

fn (mut b BytesBigEndian) write_string1(s string) {
	b.write_u8(u8(s.len))
	b.write_u8s(s.bytes())
}

fn (mut b BytesBigEndian) write_identifier(identifier Identifier) {
	b.write_string1(identifier.storage_id())
}

fn (mut b BytesBigEndian) read_string1() string {
	len := b.read_u8()

	return b.read_string(len)
}

fn (mut b BytesBigEndian) read_identifier() Identifier {
	return decode_identifier(b.read_string1())
}

fn (mut b BytesBigEndian) read_string(len int) string {
	return b.read_u8s(len).bytestr()
}

fn (b BytesBigEndian) has_more() bool {
	return b.at < b.data.len
}

fn (mut b BytesBigEndian) write_string4(s string) {
	b.write_i32(s.len)
	b.write_u8s(s.bytes())
}

fn (mut b BytesBigEndian) read_string4() string {
	return b.read_string(b.read_i32())
}

// new_empty_bytes creates a new zero-length buffer that can be used for reading
// or writing.
fn new_empty_bytes() BytesReaderWriter {
	if runtime.is_little_endian() {
		return BytesLittleEndian{}
	}

	return BytesBigEndian{}
}

// new_bytes creates a read and write buffer from some existing data. The data
// is cloned so it's safe to modify.
fn new_bytes(data []u8) BytesReaderWriter {
	big_endian := BytesBigEndian{
		data: data.clone()
	}

	if runtime.is_little_endian() {
		return BytesLittleEndian{big_endian}
	}

	return big_endian
}

union Bytes2 {
	bytes     [2]u8
	i16_value i16
	u16_value u16
}

fn (b Bytes2) bytes() []u8 {
	return unsafe { [b.bytes[0], b.bytes[1]] }
}

fn (b Bytes2) bytes_reversed() []u8 {
	return unsafe { [b.bytes[1], b.bytes[0]] }
}

union Bytes8 {
	bytes     [8]u8
	f64_value f64
	i64_value i64
	u64_value u64
}

fn (b Bytes8) bytes() []u8 {
	return unsafe {
		[b.bytes[0], b.bytes[1], b.bytes[2], b.bytes[3], b.bytes[4], b.bytes[5], b.bytes[6], b.bytes[7]]
	}
}

fn (b Bytes8) bytes_reversed() []u8 {
	return unsafe {
		[b.bytes[7], b.bytes[6], b.bytes[5], b.bytes[4], b.bytes[3], b.bytes[2], b.bytes[1], b.bytes[0]]
	}
}

union Bytes4 {
	bytes     [4]u8
	f32_value f32
	int_value int
}

fn (b Bytes4) bytes() []u8 {
	return unsafe { [b.bytes[0], b.bytes[1], b.bytes[2], b.bytes[3]] }
}

fn (b Bytes4) bytes_reversed() []u8 {
	return unsafe { [b.bytes[3], b.bytes[2], b.bytes[1], b.bytes[0]] }
}
