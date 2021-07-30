// cast.v handles the conversion of a value from one type to another.

module vsql

// TODO(elliotchance): This should be rewritten to follow the table in
//  <cast specification>.

fn cast(msg string, v Value, to Type) ?Value {
	match v.typ.typ {
		.is_null {
			// A NULL can be any type so it's always castable.
			return v
		}
		.is_boolean {
			match to.typ {
				.is_boolean { return v }
				else {}
			}
		}
		.is_bigint {
			match to.typ {
				.is_bigint, .is_double_precision, .is_integer, .is_real, .is_smallint { return v }
				else {}
			}
		}
		.is_character {
			match to.typ {
				.is_character, .is_varchar { return v }
				else {}
			}
		}
		.is_double_precision {
			match to.typ {
				.is_bigint, .is_double_precision, .is_integer, .is_real, .is_smallint { return v }
				else {}
			}
		}
		.is_integer {
			match to.typ {
				.is_bigint, .is_double_precision, .is_integer, .is_real, .is_smallint { return v }
				else {}
			}
		}
		.is_real {
			match to.typ {
				.is_bigint, .is_double_precision, .is_integer, .is_real, .is_smallint { return v }
				else {}
			}
		}
		.is_smallint {
			match to.typ {
				.is_bigint, .is_double_precision, .is_integer, .is_real, .is_smallint { return v }
				else {}
			}
		}
		.is_varchar {
			match to.typ {
				.is_varchar, .is_character { return v }
				else {}
			}
		}
	}

	return sqlstate_42804(msg, to.typ.str(), v.typ.str())
}
