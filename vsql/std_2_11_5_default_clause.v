module vsql

// ISO/IEC 9075-2:2016(E), 11.5, <default clause>
//
// Specify the default for a column, domain, or attribute.

type DefaultOption = CurrentCatalog
	| CurrentSchema
	| DatetimeValueFunction
	| NullSpecification
	| Value

// str returns the SQL for the default, which is also how it's stored in the
// file as part of the CREATE TABLE.
fn (o DefaultOption) str() string {
	return match o {
		CurrentCatalog { 'CURRENT_CATALOG' }
		CurrentSchema { 'CURRENT_SCHEMA' }
		DatetimeValueFunction { o.pstr(map[string]Value{}) }
		NullSpecification { 'NULL' }
		Value { o.literal() }
	}
}

fn (o DefaultOption) compile(mut c Compiler) !CompileResult {
	match o {
		CurrentCatalog, CurrentSchema {
			return GeneralValueSpecification(o).compile(mut c)!
		}
		DatetimeValueFunction, NullSpecification, Value {
			return o.compile(mut c)!
		}
	}
}

// check_default_clause returns an error if the default of the column doesn't
// suit the type of the column. A datetime value function (such as
// CURRENT_DATE), CURRENT_CATALOG and CURRENT_SCHEMA aren't evaluated until the
// default is used, so they're only checked by their type. The length of the
// column for CURRENT_CATALOG and CURRENT_SCHEMA, and whether a datetime value
// function has a time zone, aren't checked (#788).
//
// ISO/IEC 9075-2:2016(E), 11.5, <default clause>, Syntax Rules, 4.b and 4.d
fn check_default_clause(mut conn Connection, column Column) ! {
	default_value := column.default_value or { return }
	mut c := Compiler{
		conn:      conn
		params:    map[string]Value{}
		null_type: column.typ
	}
	typ := default_value.compile(mut c)!.typ

	is_valid := match default_value {
		CurrentCatalog, CurrentSchema {
			column.typ.typ.is_string()
		}
		DatetimeValueFunction {
			column.typ.typ.is_datetime() && datetime_fields(typ.typ) == datetime_fields(column.typ.typ)
		}
		NullSpecification {
			true
		}
		Value {
			is_valid_default_literal(mut conn, default_value, column.typ)
		}
	}

	if !is_valid {
		return sqlstate_42601('DEFAULT ${default_value} is not valid for column ${column.name.sub_entity_name} ${column.typ}')
	}
}

// is_valid_default_literal is true if a literal can be the default of a column
// of type t. It's stricter than storing the value: a number can't be the
// default of a character string, an exact numeric can't have an approximate
// default or lose any significant digits, and a datetime must have the same
// fields, and a time zone if the column has one. A datetime that has a time
// zone when the column doesn't, or more fractional seconds than the column, is
// allowed (#788).
//
// ISO/IEC 9075-2:2016(E), 11.5, <default clause>, Syntax Rules, 4.a
fn is_valid_default_literal(mut conn Connection, v Value, t Type) bool {
	return match t.typ {
		.is_boolean {
			v.typ.typ == .is_boolean
		}
		.is_character, .is_varchar {
			v.typ.typ.is_string() && (t.size == 0 || v.string_value().runes().len <= t.size)
		}
		.is_real, .is_double_precision {
			v.typ.typ.is_number()
		}
		.is_smallint, .is_integer, .is_bigint, .is_decimal, .is_numeric {
			v.typ.typ.is_number() && v.typ.typ !in [.is_real, .is_double_precision]
				&& keeps_significant_digits(mut conn, v, t)
		}
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			v.typ.typ.is_datetime() && datetime_fields(v.typ.typ) == datetime_fields(t.typ)
				&& (v.typ.has_time_zone() || !t.has_time_zone())
		}
	}
}

// keeps_significant_digits is true if the exact number v can be stored as type
// t without losing any significant digits. For example, 1.50 can be a
// NUMERIC(3, 1), but 1.5 can't be an INTEGER and 100000 can't be a SMALLINT.
fn keeps_significant_digits(mut conn Connection, v Value, t Type) bool {
	stored := cast(mut conn, '', v, t) or { return false }

	return compare(conn, v, stored) or { return false } == .is_equal
}
