module vsql

// A CHARACTER LARGE OBJECT or BINARY LARGE OBJECT can't be grouped or ordered.
// Their values are stored outside of the row (see large_value.v) so they're only
// read when they're needed.

// check_grouping_operand returns an error if the declared type of an operand
// of a grouping operation (such as GROUP BY, DISTINCT or UNION) is a large
// object. The operand is described by what, such as "column X in GROUP BY".
//
// ISO/IEC 9075-2:2023, 9.12, Grouping operations, Syntax Rules, 3
fn check_grouping_operand(typ Type, what string) ! {
	if typ.typ in [.is_clob, .is_blob] {
		return sqlstate_42601('${what} cannot be a ${typ.typ}')
	}
}

// check_ordering_operand returns an error if the declared type of an operand
// of an ordering operation (such as ORDER BY, MAX or <) is a large object. The
// operand is described by what, such as "expression in ORDER BY".
//
// ISO/IEC 9075-2:2023, 9.14, Ordering operations, Syntax Rules, 3
fn check_ordering_operand(typ Type, what string) ! {
	if typ.typ in [.is_clob, .is_blob] {
		return sqlstate_42601('${what} cannot be a ${typ.typ}')
	}
}
