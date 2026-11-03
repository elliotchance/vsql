module vsql

// The algorithm for Normalization Form C (NFC), from Unicode Standard Annex #15.
// The tables are in unicode_tables.v. A syllable of Hangul has no table: its
// mappings are calculated from these (Unicode Standard, 3.12).

const hangul_s_base = rune(0xAC00)
const hangul_l_base = rune(0x1100)
const hangul_v_base = rune(0x1161)
const hangul_t_base = rune(0x11A7)
const hangul_l_count = 19
const hangul_v_count = 21
const hangul_t_count = 28
const hangul_n_count = hangul_v_count * hangul_t_count
const hangul_s_count = hangul_l_count * hangul_n_count

// normalize_nfc returns the NFC form of a string.
fn normalize_nfc(s string) string {
	// Everything below U+0300 is already NFC and can't combine with what's before
	// it. In UTF-8 that's every lead byte below 0xCC.
	if s.bytes().all(it < 0xCC) {
		return s
	}

	mut runes := []rune{cap: s.len}
	for r in s.runes() {
		decompose_canonical(r, mut runes)
	}
	reorder_canonical(mut runes)

	return compose_canonical(runes).string()
}

// decompose_canonical appends the full canonical decomposition of a code point.
fn decompose_canonical(r rune, mut out []rune) {
	if r >= hangul_s_base && r < hangul_s_base + hangul_s_count {
		index := r - hangul_s_base
		out << hangul_l_base + index / hangul_n_count
		out << hangul_v_base + (index % hangul_n_count) / hangul_t_count
		if index % hangul_t_count != 0 {
			out << hangul_t_base + index % hangul_t_count
		}
		return
	}

	entry := unicode_table_lookup(unicode_decompositions, u64(r), 42) or {
		out << r
		return
	}
	decompose_canonical(rune(entry >> 21), mut out)
	if entry & 0x1FFFFF != 0 {
		decompose_canonical(rune(entry & 0x1FFFFF), mut out)
	}
}

// reorder_canonical puts each run of combining marks in the order of their
// combining classes. Marks of the same class must stay in the same order.
fn reorder_canonical(mut runes []rune) {
	for i in 1 .. runes.len {
		r := runes[i]
		class := unicode_combining_class(r)
		mut j := i
		for class != 0 && j > 0 && unicode_combining_class(runes[j - 1]) > class {
			runes[j] = runes[j - 1]
			j--
		}
		runes[j] = r
	}
}

// compose_canonical replaces each code point with the composite it forms with the
// last starter (a code point of class zero), unless it's blocked by what's between
// them. The marks are in order, so only the last one that's left can block it: it
// does when it's of the same class or higher, which includes this code point being
// a starter itself.
fn compose_canonical(runes []rune) []rune {
	mut out := []rune{cap: runes.len}
	mut starter := -1
	mut last_class := 0
	for r in runes {
		class := unicode_combining_class(r)
		if starter >= 0 && (starter == out.len - 1 || last_class < class) {
			if composite := unicode_composite(out[starter], r) {
				out[starter] = composite
				continue
			}
		}

		if class == 0 {
			starter = out.len
		}
		last_class = class
		out << r
	}

	return out
}

// unicode_composite returns the primary composite of two code points, if any.
fn unicode_composite(a rune, b rune) ?rune {
	if a >= hangul_l_base && a < hangul_l_base + hangul_l_count && b >= hangul_v_base
		&& b < hangul_v_base + hangul_v_count {
		index := (a - hangul_l_base) * hangul_v_count + (b - hangul_v_base)
		return hangul_s_base + index * hangul_t_count
	}

	if a >= hangul_s_base && a < hangul_s_base + hangul_s_count
		&& (a - hangul_s_base) % hangul_t_count == 0 && b > hangul_t_base
		&& b < hangul_t_base + hangul_t_count {
		return a + b - hangul_t_base
	}

	entry := unicode_table_lookup(unicode_compositions, u64(a) << 21 | u64(b), 21)?
	return rune(entry)
}

// unicode_combining_class returns the canonical combining class of a code point.
fn unicode_combining_class(r rune) int {
	return int(unicode_table_lookup(unicode_combining_classes, u64(r), 8) or { 0 })
}

// unicode_table_lookup finds the entry with a key (entry >> shift) in a sorted
// table and returns what's left of the entry.
fn unicode_table_lookup(table []u64, key u64, shift int) ?u64 {
	mut low := 0
	mut high := table.len
	for low < high {
		mid := (low + high) / 2
		found := table[mid] >> shift
		if found == key {
			return table[mid] & ((u64(1) << shift) - 1)
		}
		if found < key {
			low = mid + 1
		} else {
			high = mid
		}
	}

	return none
}
