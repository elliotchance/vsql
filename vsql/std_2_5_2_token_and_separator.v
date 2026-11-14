module vsql

// <truncating whitespace> is the characters that a string can lose when it's
// truncated without an error or warning, and that are removed from the start
// and end of a string that's cast to a number. Which characters it has is
// implementation-defined, but it must have the space. In vsql it's only the
// space, so a tab or a new line is never truncated or removed.
//
// ISO/IEC 9075-2:2023, 5.2, <token> and <separator>, Syntax Rules, 4

// is_truncating_whitespace reports whether ch is <truncating whitespace>.
fn is_truncating_whitespace(ch rune) bool {
	return ch == ` `
}

// trim_truncating_whitespace removes any leading or trailing <truncating
// whitespace>.
fn trim_truncating_whitespace(s string) string {
	return s.trim(' ')
}
