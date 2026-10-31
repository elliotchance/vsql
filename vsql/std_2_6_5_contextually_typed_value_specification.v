module vsql

// ISO/IEC 9075-2:2016(E), 6.5, <contextually typed value specification>
//
// Specify a value whose data type is to be inferred from its context.

// ContextuallyTypedValueSpecification is a NULL or DEFAULT that takes its type
// from the column it's assigned to.
type ContextuallyTypedValueSpecification = DefaultSpecification | NullSpecification

fn (e ContextuallyTypedValueSpecification) compile(mut c Compiler) !CompileResult {
	match e {
		DefaultSpecification, NullSpecification {
			return e.compile(mut c)!
		}
	}
}

// NullSpecification (not to be confused with NullPredicate) represents an
// untyped NULL. This exists as an expression (rather than a special value)
// because it's devoid of a type until it's used in an actual expression. Also,
// having it use it's own SQLType creates a lot of branches in the codebase that
// require "this should not be possible" comments and panics.
struct NullSpecification {}

fn (e NullSpecification) pstr(_ map[string]Value) string {
	return 'NULL'
}

fn (e NullSpecification) compile(mut c Compiler) !CompileResult {
	if null_type := c.null_type {
		return CompileResult{
			run:          fn [null_type] (mut conn Connection, data Row, params map[string]Value) !Value {
				return new_null_value(null_type.typ)
			}
			typ:          null_type
			contains_agg: false
		}
	}

	return sqlstate_42601('cannot determine value of untyped NULL')
}

// DefaultSpecification is the DEFAULT keyword, which is the default value of the
// column it's assigned to (see Compiler.default_value), or the null value if
// the column doesn't have one. An identity column gets the next value of its
// sequence instead.
//
// ISO/IEC 9075-2:2016(E), 11.5, <default clause>, General Rules, 3.a, 3.b and 3.e
struct DefaultSpecification {}

fn (e DefaultSpecification) compile(mut c Compiler) !CompileResult {
	if table := c.identity {
		mut catalog := c.conn.catalog_for(table.name)
		start_value := ((table.identity_column() or { Column{} }).identity or { IdentityColumn{} }).sequence.start_value

		return CompileResult{
			run:          fn [table, mut catalog, start_value] (mut conn Connection, data Row, params map[string]Value) !Value {
				// Like NEXT VALUE FOR, a value isn't used up when the expression is
				// only being checked.
				if conn.dry_run {
					return new_bigint_value(start_value)
				}

				return new_bigint_value(catalog.storage.identity_next_value(table)!)
			}
			typ:          new_type('BIGINT', 0, 0)
			contains_agg: false
		}
	}

	if default_value := c.default_value {
		return default_value.compile(mut c)!
	}

	return NullSpecification{}.compile(mut c)!
}

// identity_of returns the table when the column is its identity column, for
// Compiler.identity.
fn identity_of(table Table, column Column) ?Table {
	if _ := column.identity {
		return table
	}

	return none
}

// is_default_specification is true when the value is DEFAULT, which is the only
// value that can be assigned to a GENERATED ALWAYS identity column.
fn is_default_specification(e ContextuallyTypedRowValueConstructorElement) bool {
	if e is ContextuallyTypedValueSpecification {
		return e is DefaultSpecification
	}

	return false
}
