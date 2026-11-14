module vsql

// ISO/IEC 9075-2:2023, 11.19, <alter column data type clause>
//
// Change the declared type of a column.

struct AlterColumnDataTypeClause {
	data_type Type
}

// execute returns the column with the new type. The new type must be able to
// hold every value of the old type, so it's the same kind of type that's at
// least as big (see Type.can_widen_to), and the existing values are cast to it when
// the rows are written again (see replace_table_definition).
//
// The column can't be used by a CHECK constraint that also uses other columns,
// or by the generation expression of a generated column. A FOREIGN KEY, a
// PRIMARY KEY, UNIQUE and an index can use it.
//
// Every type is a predefined type. A character string keeps its character set
// and collation, because there's only UTF8 and its default collation.
//
// ISO/IEC 9075-2:2023, 11.19, <alter column data type clause>, Syntax Rules, 6, 10, 12.a, 13 and 14
// ISO/IEC 9075-2:2023, 11.19, <alter column data type clause>, General Rules, 1
fn (c AlterColumnDataTypeClause) execute(mut conn Connection, table Table, column Column) !Column {
	name := column.name.sub_entity_name
	for constraint in table.check_constraints {
		columns := constraint.columns(mut conn, table)!
		if name in columns && columns.len > 1 {
			return sqlstate_42601('cannot change the data type of column ${requote_identifier(name)}, it is used by constraint ${requote_identifier(constraint.name.entity_name)}')
		}
	}
	for generated_column in table.columns {
		generated := generated_column.generated or { continue }
		if name in generated.columns(mut conn, table, generated_column)! {
			return sqlstate_42601('cannot change the data type of column ${requote_identifier(name)}, it is used by generated column ${requote_identifier(generated_column.name.sub_entity_name)}')
		}
	}

	if !column.typ.can_widen_to(c.data_type) {
		return sqlstate_42601('cannot change the data type of column ${requote_identifier(name)} from ${column.typ} to ${c.data_type}')
	}

	new_column := Column{
		...column
		typ: Type{
			...c.data_type
			not_null: column.typ.not_null
		}
	}
	check_default_clause(mut conn, new_column)!

	return new_column
}

// can_widen_to is true when to can hold every value of t: the same kind of
// type, with at least the same length, precision or scale. A character string
// must have room for the most characters and the most octets of t (a length can
// be in either unit). An integer type is compared to a NUMERIC or DECIMAL by the
// number of decimal digits that it can always hold (see whole_digits).
//
// ISO/IEC 9075-2:2023, 11.19, <alter column data type clause>, Syntax Rules, 15.a, 15.c, 15.d, 15.e, 15.f, 15.g, 15.j and 15.k
fn (t Type) can_widen_to(to Type) bool {
	integers := [SQLType.is_smallint, .is_integer, .is_bigint]
	exact := [SQLType.is_smallint, .is_integer, .is_bigint, .is_numeric, .is_decimal]
	characters := [SQLType.is_character, .is_varchar]
	approximate := [SQLType.is_real, .is_double_precision]
	datetimes := [SQLType.is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone]

	if t.typ in characters && to.typ in characters {
		return to.size >= t.size && to.max_octets() >= t.max_octets()
	}
	if t.typ in integers && to.typ in integers {
		return integers.index(to.typ) >= integers.index(t.typ)
	}
	if t.typ in exact && to.typ in exact {
		return to.scale >= t.scale && to.whole_digits() - to.scale >= t.digits() - t.scale
	}
	if t.typ in approximate && to.typ in approximate {
		return to.typ == .is_double_precision || t.typ == .is_real
	}
	if t.typ in datetimes && to.typ == t.typ {
		return to.size >= t.size
	}

	return to.typ == t.typ
}

// digits is the number of decimal digits that a value of an exact numeric type
// can have. A NUMERIC or DECIMAL without a precision has the maximum precision.
fn (t Type) digits() int {
	return if t.typ in [.is_numeric, .is_decimal] {
		t.numeric_precision()
	} else {
		t.exact_precision()
	}
}

// whole_digits is the number of decimal digits that every value of an exact
// numeric type can have. That's one less than digits for an integer type,
// because not every value with that many digits fits, such as 99999 for a
// SMALLINT.
fn (t Type) whole_digits() int {
	return if t.typ in [.is_numeric, .is_decimal] {
		t.numeric_precision()
	} else {
		t.exact_precision() - 1
	}
}

// max_octets is the most octets that a value of a character string type can
// have. A character is at most 4 octets in UTF-8.
fn (t Type) max_octets() i64 {
	return if t.octets { i64(t.size) } else { i64(t.size) * 4 }
}
