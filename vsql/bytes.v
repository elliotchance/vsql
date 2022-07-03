// bytes.v contains a byte stream that can be read from and written to.

module vsql

struct Bytes {
mut:
	at   int
	data []u8
}

fn new_bytes(data []u8) Bytes {
	return Bytes{
		data: data.clone()
	}
}

fn (mut b Bytes) write_bool(d bool) {
	b.write_byte(if d { u8(1) } else { 0 })
}

fn (mut b Bytes) read_bool() bool {
	return b.read_byte() != 0
}

fn (mut b Bytes) write_byte(d u8) {
	b.data << d
}

fn (mut b Bytes) read_byte() u8 {
	b.at++
	return b.data[b.at - 1]
}

fn (mut b Bytes) write_bytes(data []u8) {
	for d in data {
		b.data << d
	}
}

fn (mut b Bytes) read_bytes(len int) []u8 {
	data := b.data[b.at..b.at + len]
	b.at += len
	return data.clone()
}

fn (mut b Bytes) write_string1(s string) {
	b.write_byte(u8(s.len))
	b.write_bytes(s.bytes())
}

fn (mut b Bytes) read_string(len int) string {
	return b.read_bytes(len).bytestr()
}

fn (mut b Bytes) read_string1() string {
	len := b.read_byte()
	return b.read_string(len)
}

fn (mut b Bytes) write_string4(s string) {
	b.write_int(s.len)
	b.write_bytes(s.bytes())
}

fn (mut b Bytes) read_string4() string {
	len := b.read_int()
	return b.read_string(len)
}

union Bytes2 {
	bytes     [2]u8
	i16_value i16
	u16_value u16
}

fn (b Bytes2) bytes() []u8 {
	return unsafe { [b.bytes[0], b.bytes[1]] }
}

fn (mut b Bytes) write_i16(d i16) {
	b.write_bytes(Bytes2{ i16_value: d }.bytes())
}

fn (mut b Bytes) write_u16(d u16) {
	b.write_bytes(Bytes2{ u16_value: d }.bytes())
}

fn (mut b Bytes) write_int(x int) {
	b.write_bytes(int_to_bytes(x))
}

fn (mut b Bytes) read_i16() i16 {
	bytes := b.read_bytes(2)
	return unsafe {
		Bytes2{
			bytes: [bytes[0], bytes[1]]!
		}.i16_value
	}
}

fn (mut b Bytes) read_u16() u16 {
	bytes := b.read_bytes(2)
	return unsafe {
		Bytes2{
			bytes: [bytes[0], bytes[1]]!
		}.u16_value
	}
}

fn (mut b Bytes) read_int() int {
	return bytes_to_int(b.read_bytes(4))
}

fn (b Bytes) bytes() []u8 {
	return b.data.clone()
}

fn (b Bytes) has_more() bool {
	return b.at < b.data.len
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

fn (mut b Bytes) write_f64(x f64) {
	b.write_bytes(Bytes8{ f64_value: x }.bytes())
}

fn (mut b Bytes) write_i64(x i64) {
	b.write_bytes(i64_to_bytes(x))
}

union Bytes4 {
	bytes     [4]u8
	f32_value f32
	int_value int
}

fn (b Bytes4) bytes() []u8 {
	return unsafe { [b.bytes[0], b.bytes[1], b.bytes[2], b.bytes[3]] }
}

fn (mut b Bytes) write_f32(x f32) {
	b.write_bytes(Bytes4{ f32_value: x }.bytes())
}

fn (mut b Bytes) read_f32() f32 {
	bytes := b.read_bytes(4)
	return unsafe {
		Bytes4{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3]]!
		}.f32_value
	}
}

fn (mut b Bytes) read_f64() f64 {
	bytes := b.read_bytes(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]]!
		}.f64_value
	}
}

fn (mut b Bytes) read_i64() i64 {
	bytes := b.read_bytes(8)
	return unsafe {
		Bytes8{
			bytes: [bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]]!
		}.i64_value
	}
}

fn int_to_bytes(n int) []u8 {
	return Bytes4{
		int_value: n
	}.bytes().reverse()
}

fn bytes_to_int(bytes []u8) int {
	return unsafe {
		Bytes4{
			bytes: [bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.int_value
	}
}

fn bytes_to_i16(bytes []u8) i16 {
	return unsafe {
		Bytes2{
			bytes: [bytes[0], bytes[1]]!
		}.i16_value
	}
}

fn i64_to_bytes(n i64) []u8 {
	return Bytes8{
		i64_value: n
	}.bytes().reverse()
}

fn bytes_to_i64(bytes []u8) i64 {
	return unsafe {
		Bytes8{
			bytes: [bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.i64_value
	}
}

fn (mut b Bytes) write_string1_list(ss []string) {
	b.write_byte(u8(ss.len))
	for s in ss {
		b.write_string1(s)
	}
}

fn (mut b Bytes) read_string1_list() []string {
	len := b.read_byte()
	mut ss := []string{len: int(len)}
	for i in 0 .. int(len) {
		ss[i] = b.read_string1()
	}

	return ss
}

fn (mut b Bytes) read_bytes1() []u8 {
	len := b.read_byte()
	return b.read_bytes(len)
}

fn (mut b Bytes) write_bytes1(s []u8) {
	b.write_byte(u8(s.len))
	b.write_bytes(s.clone())
}
