// bench_big.v is the big suite of "vsql bench". It inserts large values, and
// then reads each one back and checks that it's exactly what was inserted.
//
// See https://github.com/elliotchance/vsql/blob/main/docs/benchmark.rst

module main

import time
import vsql

// big_min_bytes and big_max_bytes are the smallest and largest size of a value
// of the big suite, in bytes of UTF-8 (1 to 10 MiB). A value that's larger than
// half a page is split into blob and fragment objects (see "Blob Object" in
// docs/file-format.rst), so with the default page size each value is split
// into 512 to 5,120 of them.
const big_min_bytes = 1024 * 1024

const big_max_bytes = 10 * 1024 * 1024

// big_default_mib is the total size of the values, in MiB, when there's no
// -size.
const big_default_mib = 100

// big is the big suite. It creates the BIG schema and its OBJECTS table, and
// inserts values until they add up to mib MiB. Then it reads each value back,
// and fails unless it has every byte (and CHAR_LENGTH) of the value that was
// inserted.
fn (mut b Benchmark) big(mib int) ! {
	b.conn.query('CREATE SCHEMA big') or {
		return error('${err.msg()} (use DROP SCHEMA big CASCADE to remove it and its table)')
	}
	b.conn.query('CREATE TABLE big.objects (id INT NOT NULL PRIMARY KEY, v VARCHAR(10485760))')!

	sizes := big_sizes(mib)
	println('')
	println('# big')
	print_value('values', sizes.len.str())

	// Only the time of the statements is counted, not the time to make the
	// values or to check them.
	mut insert := b.conn.prepare('INSERT INTO big.objects (id, v) VALUES (?, ?)')!
	mut elapsed := time.Duration(0)
	for i, bytes in sizes {
		id := i + 1
		value, _ := big_value(id, bytes)
		started := time.now()
		insert.query({
			'?1': vsql.new_integer_value(id)
			'?2': vsql.new_varchar_value(value)
		})!
		elapsed += time.since(started)
		b.sample_memory()
	}
	print_rate('insert', mib, 'mib', elapsed)

	mut selected := b.conn.prepare('SELECT v, CHAR_LENGTH(v) AS len FROM big.objects WHERE id = ?')!
	elapsed = 0
	for i, bytes in sizes {
		id := i + 1
		started := time.now()
		mut result := selected.query({
			'?1': vsql.new_integer_value(id)
		})!
		row := result.next() or { return error('big: value ${id} is missing') }
		got := row.get_string('V')!
		got_length := row.get_int('LEN')!
		elapsed += time.since(started)
		b.sample_memory()

		want, want_length := big_value(id, bytes)
		check_big_value(id, got, got_length, want, want_length)!
	}
	print_rate('select', mib, 'mib', elapsed)
}

// big_sizes are the sizes of the values, in bytes, that add up to mib MiB. Each
// one is a random size from big_min_bytes to big_max_bytes, except that the
// last one is cut to what's left. The sizes are the same every time, so that
// runs can be compared.
fn big_sizes(mib int) []int {
	mut sizes := []int{}
	mut left := i64(mib) * 1024 * 1024
	mut x := u32(2463534242)
	for left > 0 {
		x ^= x << 13
		x ^= x >> 17
		x ^= x << 5
		mut bytes := i64(big_min_bytes + x % u32(big_max_bytes - big_min_bytes + 1))
		if bytes > left {
			bytes = left
		}
		sizes << int(bytes)
		left -= bytes
	}
	return sizes
}

// big_value is the value with the id, which is always bytes long, and its
// length in characters. Every value is different, and so is every part of it,
// so a value that's put back together from the wrong blob objects (or in the
// wrong order), or that has changed, doesn't match. Most characters are ASCII
// letters, but there are also characters of 2, 3 and 4 bytes, so the length in
// characters is less than the length in bytes, and some characters are split
// between blob objects.
fn big_value(id int, bytes int) (string, int) {
	mut buf := []u8{len: bytes}
	mut x := u32(id) * 2654435761 + 1
	mut i := 0
	mut chars := 0
	for i < bytes {
		x ^= x << 13
		x ^= x >> 17
		x ^= x << 5
		left := bytes - i
		kind := x % 16
		if kind == 0 && left >= 4 {
			// U+1F600
			buf[i] = 0xf0
			buf[i + 1] = 0x9f
			buf[i + 2] = 0x98
			buf[i + 3] = 0x80
			i += 4
		} else if kind == 1 && left >= 3 {
			// U+20AC
			buf[i] = 0xe2
			buf[i + 1] = 0x82
			buf[i + 2] = 0xac
			i += 3
		} else if kind in [u32(2), 3] && left >= 2 {
			// U+00E9
			buf[i] = 0xc3
			buf[i + 1] = 0xa9
			i += 2
		} else {
			buf[i] = u8(`a` + (x >> 4) % 26)
			i++
		}
		chars++
	}
	return buf.bytestr(), chars
}

// check_big_value fails unless the value (and its CHAR_LENGTH) that was read
// back is the same as the one that was inserted. If a byte is different, the
// error shows the bytes around it.
fn check_big_value(id int, got string, got_length int, want string, want_length int) ! {
	if got_length != want_length {
		return error('big: value ${id}: CHAR_LENGTH is ${got_length}, not ${want_length}')
	}
	if got.len != want.len {
		return error('big: value ${id}: ${got.len} bytes, not ${want.len}')
	}
	if got != want {
		for i in 0 .. got.len {
			if got[i] != want[i] {
				start := if i > 16 { i - 16 } else { 0 }
				end := if i + 16 < got.len { i + 16 } else { got.len }
				return error('big: value ${id} is different from byte ${i}: got ${got[start..end].bytes().hex()}, want ${want[start..end].bytes().hex()} (from byte ${start})')
			}
		}
	}
}
