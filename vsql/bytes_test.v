module vsql

import math

// Numbers must be stored big-endian on every platform, so these check the
// exact bytes and that each value reads back the same.
fn test_bytes_are_big_endian() {
	mut b := new_empty_bytes()
	b.write_u8(0xab)
	b.write_bool(true)
	b.write_i16(-2)
	b.write_u16(0x0102)
	b.write_i32(-2)
	b.write_i32(0x01020304)
	b.write_i64(-2)
	b.write_u64(0x0102030405060708)
	b.write_f32(1.5)
	b.write_f64(-2.25)
	b.write_string4('hi')

	assert b.bytes() == [
		u8(0xab),
		0x01,
		0xff,
		0xfe,
		0x01,
		0x02,
		0xff,
		0xff,
		0xff,
		0xfe,
		0x01,
		0x02,
		0x03,
		0x04,
		0xff,
		0xff,
		0xff,
		0xff,
		0xff,
		0xff,
		0xff,
		0xfe,
		0x01,
		0x02,
		0x03,
		0x04,
		0x05,
		0x06,
		0x07,
		0x08,
		0x3f,
		0xc0,
		0x00,
		0x00,
		0xc0,
		0x02,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		0x02,
		`h`,
		`i`,
	]

	mut r := new_bytes(b.bytes())
	assert r.read_u8() == 0xab
	assert r.read_bool() == true
	assert r.read_i16() == -2
	assert r.read_u16() == 0x0102
	assert r.read_i32() == -2
	assert r.read_i32() == 0x01020304
	assert r.read_i64() == -2
	assert r.read_u64() == 0x0102030405060708
	assert r.read_f32() == 1.5
	assert r.read_f64() == -2.25
	assert r.read_string4() == 'hi'
	assert !r.has_more()
}

fn test_bytes_limits() {
	mut b := new_empty_bytes()
	b.write_i16(min_i16)
	b.write_i32(max_i32)
	b.write_i32(min_i32)
	b.write_i64(max_i64)
	b.write_i64(min_i64)
	b.write_u64(max_u64)
	b.write_f64(math.inf(-1))

	mut r := new_bytes(b.bytes())
	assert r.read_i16() == min_i16
	assert r.read_i32() == max_i32
	assert r.read_i32() == min_i32
	assert r.read_i64() == max_i64
	assert r.read_i64() == min_i64
	assert r.read_u64() == max_u64
	assert math.is_inf(r.read_f64(), -1)
}

// Writing at an earlier position overwrites the data rather than inserting.
fn test_bytes_overwrite() {
	mut b := new_bytes([u8(1), 2, 3, 4, 5])
	b.set_pos(1)
	b.write_u16(0xaabb)
	assert b.bytes() == [u8(1), 0xaa, 0xbb, 4, 5]
	assert b.has_more()
	b.set_pos(4)
	b.write_u16(0xccdd)
	assert b.bytes() == [u8(1), 0xaa, 0xbb, 4, 0xcc, 0xdd]
	assert !b.has_more()
}
