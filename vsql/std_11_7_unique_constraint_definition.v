module vsql

// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>
//
// Specify a uniqueness constraint for a table.

struct UniqueConstraintDefinition {
	columns []Identifier
}
