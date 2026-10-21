// bytes.v contains a byte stream that can be read from and written to.
//
// Numbers are always stored big-endian (most significant byte first), so the
// data is the same on every platform and the byte order is ideal for sorting.
// The encoding.binary functions shift the bits rather than copying memory, so
// they don't depend on the byte order of the CPU.

module vsql

import encoding.binary
import math

// Bytes is a buffer that can be read from any point, and written to by appending
// to the end.
//
// Bytes does not return errors because it's expected the caller knows when the
// buffer ends. Trying to read beyond the end of the buffer will result in a
// panic.
struct Bytes {
mut:
	at   int
	data []u8
}

// new_empty_bytes creates a new zero-length buffer that can be used for reading
// or writing.
fn new_empty_bytes() Bytes {
	return Bytes{}
}

// new_bytes creates a read and write buffer from some existing data. The data
// is cloned so it's safe to modify.
fn new_bytes(data []u8) Bytes {
	return Bytes{
		data: data.clone()
	}
}

// set_pos moves the position for future reads.
fn (mut b Bytes) set_pos(pos int) {
	b.at = pos
}

// bytes returns the entire buffer. It does not move the current position.
fn (b Bytes) bytes() []u8 {
	return b.data
}

// has_more can be used by the reader to see if we're at the end.
fn (b Bytes) has_more() bool {
	return b.at < b.data.len
}

fn (mut b Bytes) write_u8(d u8) {
	b.data << d
	b.at++
}

fn (mut b Bytes) read_u8() u8 {
	b.at++
	return b.data[b.at - 1]
}

fn (mut b Bytes) write_bool(d bool) {
	b.write_u8(if d { u8(1) } else { 0 })
}

fn (mut b Bytes) read_bool() bool {
	return b.read_u8() != 0
}

// write_u8s writes raw bytes as they are. It should only be used for raw
// binary data, not the binary representations of numbers.
fn (mut b Bytes) write_u8s(data []u8) {
	for d in data {
		b.write_u8(d)
	}
}

// read_u8s is the opposite of write_u8s.
fn (mut b Bytes) read_u8s(len int) []u8 {
	data := b.data[b.at..b.at + len].clone()
	b.at += len

	return data
}

fn (mut b Bytes) write_i16(data i16) {
	b.write_u16(u16(data))
}

fn (mut b Bytes) read_i16() i16 {
	return i16(b.read_u16())
}

fn (mut b Bytes) write_u16(data u16) {
	b.write_u8s(binary.big_endian_get_u16(data))
}

fn (mut b Bytes) read_u16() u16 {
	return binary.big_endian_u16(b.read_u8s(2))
}

fn (mut b Bytes) write_i32(data int) {
	b.write_u8s(binary.big_endian_get_u32(u32(i32(data))))
}

fn (mut b Bytes) read_i32() int {
	return int(i32(binary.big_endian_u32(b.read_u8s(4))))
}

fn (mut b Bytes) write_i64(data i64) {
	b.write_u64(u64(data))
}

fn (mut b Bytes) read_i64() i64 {
	return i64(b.read_u64())
}

fn (mut b Bytes) write_u64(data u64) {
	b.write_u8s(binary.big_endian_get_u64(data))
}

fn (mut b Bytes) read_u64() u64 {
	return binary.big_endian_u64(b.read_u8s(8))
}

fn (mut b Bytes) write_f32(data f32) {
	b.write_u8s(binary.big_endian_get_u32(math.f32_bits(data)))
}

fn (mut b Bytes) read_f32() f32 {
	return math.f32_from_bits(binary.big_endian_u32(b.read_u8s(4)))
}

fn (mut b Bytes) write_f64(data f64) {
	b.write_u64(math.f64_bits(data))
}

fn (mut b Bytes) read_f64() f64 {
	return math.f64_from_bits(b.read_u64())
}

// write_string4 is safe to use for long strings (up to 2GB).
fn (mut b Bytes) write_string4(s string) {
	b.write_i32(s.len)
	b.write_u8s(s.bytes())
}

// read_string4 is the opposite of write_string4.
fn (mut b Bytes) read_string4() string {
	return b.read_u8s(b.read_i32()).bytestr()
}
