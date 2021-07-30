// utils.v is just general helpful functions that don't fall into any specific
// category.

module vsql

// TODO(elliotchance): Make private when CLI is moved into vsql package.
pub fn pluralize(n int, word string) string {
	if n == 1 {
		return word
	}

	return '${word}s'
}
