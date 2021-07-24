// indentifier.v contains logic for normalzing and using identifiers (such as
// table and column names).

module vsql

fn identifier_name(s string) string {
	if s.len > 0 && s[0] == `"` {
		return s[1..s.len - 1]
	}

	return s.to_upper()
}
