module vsql

// crc32_tables are the tables of crc32_update, which reads 8 bytes at a time
// ("slicing-by-8"). The first 256 are the usual table of the IEEE polynomial,
// and each next 256 are for a byte that's one more byte before the end of the
// 8.
const crc32_tables = new_crc32_tables()

fn new_crc32_tables() []u32 {
	mut t := []u32{len: 8 * 256}
	for i in 0 .. 256 {
		mut c := u32(i)
		for _ in 0 .. 8 {
			c = if c & 1 == 1 { (c >> 1) ^ u32(0xedb88320) } else { c >> 1 }
		}
		t[i] = c
	}
	for k in 1 .. 8 {
		for i in 0 .. 256 {
			previous := t[(k - 1) * 256 + i]
			t[k * 256 + i] = (previous >> 8) ^ t[int(previous & 0xff)]
		}
	}

	return t
}

// crc32_update returns the CRC-32 (IEEE) of data, continuing from crc (which is
// 0 to start). It's the same as hash.crc32, but reads 8 bytes at a time instead
// of one, since every page that's written is checked (see wal_checksum).
@[direct_array_access]
fn crc32_update(crc u32, data []u8) u32 {
	t := crc32_tables
	mut c := ~crc
	mut i := 0
	for i + 8 <= data.len {
		lo := c ^ (u32(data[i]) | (u32(data[i + 1]) << 8) | (u32(data[i + 2]) << 16) | (u32(data[i + 3]) << 24))
		hi := u32(data[i + 4]) | (u32(data[i + 5]) << 8) | (u32(data[i + 6]) << 16) | (u32(data[i + 7]) << 24)
		c = t[7 * 256 + int(lo & 0xff)] ^ t[6 * 256 + int((lo >> 8) & 0xff)] ^ t[5 * 256 +
			int((lo >> 16) & 0xff)] ^ t[4 * 256 + int(lo >> 24)] ^ t[3 * 256 + int(hi & 0xff)] ^ t[2 * 256 + int((hi >> 8) & 0xff)] ^ t[256 + int((hi >> 16) & 0xff)] ^ t[int(hi >> 24)]
		i += 8
	}
	for i < data.len {
		c = t[int(u8(c) ^ data[i])] ^ (c >> 8)
		i++
	}

	return ~c
}
