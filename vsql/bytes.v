// bytes.v contains a byte stream that can be read from and written to.

module vsql

struct Bytes {
mut:
	at   int
	data []byte
}

fn new_bytes(data []byte) Bytes {
	return Bytes{
		data: data.clone()
	}
}

fn (mut b Bytes) write_bool(d bool) {
	b.write_byte(if d { byte(1) } else { 0 })
}

fn (mut b Bytes) read_bool() bool {
	return b.read_byte() != 0
}

fn (mut b Bytes) write_byte(d byte) {
	b.data << d
}

fn (mut b Bytes) read_byte() byte {
	b.at++
	return b.data[b.at - 1]
}

fn (mut b Bytes) write_bytes(data []byte) {
	for d in data {
		b.data << d
	}
}

fn (mut b Bytes) read_bytes(len int) []byte {
	data := b.data[b.at..b.at + len]
	b.at += len
	return data.clone()
}

fn (mut b Bytes) write_string1(s string) {
	b.write_byte(byte(s.len))
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
	bytes     [2]byte
	i16_value i16
	u16_value u16
}

fn (b Bytes2) bytes() []byte {
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

fn (b Bytes) bytes() []byte {
	return b.data.clone()
}

fn (b Bytes) has_more() bool {
	return b.at < b.data.len
}

union Bytes8 {
	bytes     [8]byte
	f64_value f64
	i64_value i64
	u64_value u64
}

fn (b Bytes8) bytes() []byte {
	return unsafe {
		[b.bytes[0], b.bytes[1], b.bytes[2], b.bytes[3], b.bytes[4], b.bytes[5], b.bytes[6],
			b.bytes[7],
		]
	}
}

fn (mut b Bytes) write_f64(x f64) {
	b.write_bytes(Bytes8{ f64_value: x }.bytes())
}

fn (mut b Bytes) write_i64(x i64) {
	b.write_bytes(i64_to_bytes(x))
}

union Bytes4 {
	bytes     [4]byte
	f32_value f32
	int_value int
}

fn (b Bytes4) bytes() []byte {
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

fn int_to_bytes(n int) []byte {
	return Bytes4{
		int_value: n
	}.bytes().reverse()
}

fn bytes_to_int(bytes []byte) int {
	return unsafe {
		Bytes4{
			bytes: [bytes[3], bytes[2], bytes[1], bytes[0]]!
		}.int_value
	}
}

fn i64_to_bytes(n i64) []byte {
	return Bytes8{
		i64_value: n
	}.bytes().reverse()
}

fn (mut b Bytes) write_string1_list(ss []string) {
	b.write_byte(byte(ss.len))
	for s in ss {
		b.write_string1(s)
	}
}

fn (mut b Bytes) read_string1_list() []string {
	len := b.read_byte()
	mut ss := []string{len: int(len)}
	for i in 0 .. len {
		ss[i] = b.read_string1()
	}

	return ss
}

fn (mut b Bytes) read_bytes1() []byte {
	len := b.read_byte()
	return b.read_bytes(len)
}

fn (mut b Bytes) write_bytes1(s []byte) {
	b.write_byte(byte(s.len))
	b.write_bytes(s.clone())
}
