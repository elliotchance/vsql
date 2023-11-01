module vsql

// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers
//
// # Function
//
// Specify names.
//
// # Format
//~
//~ <identifier> /* IdentifierChain */ ::=
//~     <actual identifier>
//~
//~ <actual identifier> /* IdentifierChain */ ::=
//~     <regular identifier>
//~
//~ <table name> /* Identifier */ ::=
//~     <local or schema qualified name>   -> table_name
//~
//~ <schema name> /* Identifier */ ::=
//~     <catalog name> <period> <unqualified schema name>   -> schema_name_1
//~   | <unqualified schema name>
//~
//~ <unqualified schema name> /* Identifier */ ::=
//~     <identifier>   -> unqualified_schema_name
//~
//~ <catalog name> /* IdentifierChain */ ::=
//~     <identifier>
//~
//~ <schema qualified name> /* IdentifierChain */ ::=
//~     <qualified identifier>
//~   | <schema name> <period> <qualified identifier>   -> schema_qualified_name_2
//~
//~ <local or schema qualified name> /* IdentifierChain */ ::=
//~     <qualified identifier>
//~   | <local or schema qualifier> <period>
//~     <qualified identifier>                 -> local_or_schema_qualified_name2
//~
//~ <local or schema qualifier> /* Identifier */ ::=
//~     <schema name>
//~
//~ <qualified identifier> /* IdentifierChain */ ::=
//~     <identifier>
//~
//~ <column name> /* Identifier */ ::=
//~     <identifier>   -> column_name
//~
//~ <host parameter name> /* GeneralValueSpecification */ ::=
//~     <colon> <identifier>   -> host_parameter_name
//~
//~ <correlation name> /* Identifier */ ::=
//~     <identifier>   -> correlation_name
//~
//~ <sequence generator name> /* Identifier */ ::=
//~     <schema qualified name>   -> sequence_generator_name

// Identifier is used to describe a object within a schema (such as a table
// name) or a property of an object (like a column name of a table). You should
// not instantiate this directly, instead use the appropriate new_*_identifier()
// function.
//
// If you need the fully qualified (canonical) form of an identified you can use
// Connection.resolve_schema_identifier().
pub struct Identifier {
pub:
	// catalog_name is optional. If not provided, the CURRENT_CATALOG will be
	// used.
	catalog_name string
	// schema_name is optional. If not provided, it will use CURRENT_SCHEMA.
	schema_name string
	// entity_name would be the table name, sequence name, etc. Something inside
	// of a schema. It is case sensitive.
	entity_name string
	// sub_entity_name would represent a column name. It is case sensitive.
	sub_entity_name string
	// custom_id is a way to override the behavior of rendering and storage. This
	// is only used for internal identifiers.
	custom_id string
}

fn (e Identifier) resolve_identifiers(conn &Connection, tables map[string]Table) !Identifier {
	if e.custom_id != '' {
		return e
	}

	// If the table name is not provided we need to find it.
	if e.entity_name == '' {
		for _, table in tables {
			if (table.column(e.sub_entity_name) or { Column{} }).name.sub_entity_name == e.sub_entity_name {
				return conn.resolve_identifier(new_column_identifier('${table.name}.${e.sub_entity_name}')!)
			}
		}
	}

	// TODO(elliotchance): Need tests for table qualifier not existing.
	return conn.resolve_identifier(e)
}

// new_table_identifier is the correct way to create a new Identifier that
// represents a table. It can take several forms:
//
//   foo                   => FOO
//   "foo"                 => foo
//   schema.Bar            => SCHEMA.BAR
//   "Schema".bar          => Schema.BAR
//   "Fully"."Qualified"   => Fully.Qualified
//
// It's important to note that when a schema is not provided it will be left
// blank. You will need to use Connection.resolve_schema_identifier() to fill in
// the missing schema.
//
// An error is returned if the identifer is not valid (cannot be parsed).
//
// Even though it's valid to have a '.' in an entity name (ie. "foo.bar"),
// new_table_identifier does not correct parse this yet.
fn new_table_identifier(s string) !Identifier {
	return new_identifier2(s)
}

fn new_function_identifier(s string) !Identifier {
	return new_identifier2(s)
}

fn new_schema_identifier(s string) !Identifier {
	return new_identifier1(s)
}

fn new_identifier1(s string) !Identifier {
	parts := split_identifier_parts(s)!

	match parts.len {
		1 {
			return Identifier{
				schema_name: parts[0]
			}
		}
		2 {
			return Identifier{
				catalog_name: parts[0]
				schema_name: parts[1]
			}
		}
		else {
			return error('invalid identifier: ${s}')
		}
	}
}

fn new_identifier2(s string) !Identifier {
	parts := split_identifier_parts(s)!

	match parts.len {
		1 {
			return Identifier{
				entity_name: parts[0]
			}
		}
		2 {
			return Identifier{
				schema_name: parts[0]
				entity_name: parts[1]
			}
		}
		3 {
			return Identifier{
				catalog_name: parts[0]
				schema_name: parts[1]
				entity_name: parts[2]
			}
		}
		else {
			return error('invalid identifier: ${s}')
		}
	}
}

// new_column_identifier is the correct way to create a new Identifier that
// represents a table column. It can take several forms:
//
//   col                            => COL
//   "col"                          => col
//   tbl.Bar                        => TBL.BAR
//   "Table".bar                    => Table.BAR
//   schema.tbl.Bar                 => SCHEMA.TBL.BAR
//   "Schema"."Table".bar           => Schema.Table.BAR
//   "Fully"."Qualified"."Column"   => Fully.Qualified.Column
//
// It's important to note that when a schema is not provided it will be left
// blank. You will need to use Connection.resolve_schema_identifier() to fill in
// the missing schema.
//
// An error is returned if the identifer is not valid (cannot be parsed).
//
// Even though it's valid to have a '.' in an entity name (ie. "foo.bar"),
// new_column_identifier does not correct parse this yet.
fn new_column_identifier(s string) !Identifier {
	return new_identifier3(s)
}

fn new_identifier3(s string) !Identifier {
	parts := split_identifier_parts(s)!

	match parts.len {
		1 {
			return Identifier{
				sub_entity_name: parts[0]
			}
		}
		2 {
			return Identifier{
				entity_name: parts[0]
				sub_entity_name: parts[1]
			}
		}
		3 {
			return Identifier{
				schema_name: parts[0]
				entity_name: parts[1]
				sub_entity_name: parts[2]
			}
		}
		4 {
			return Identifier{
				catalog_name: parts[0]
				schema_name: parts[1]
				entity_name: parts[2]
				sub_entity_name: parts[3]
			}
		}
		else {
			return error('invalid identifier: ${s}')
		}
	}
}

// decode_identifier is only for internal use. It is the opposite of
// Identifier.storage_id().
fn decode_identifier(s string) Identifier {
	parts := split_identifier_parts(s) or { panic('cannot parse identifier: ${s}') }

	return Identifier{
		schema_name: parts[0]
		entity_name: parts[1]
	}
}

fn split_identifier_parts(s string) ![]string {
	if s == '' {
		return error('cannot use empty string for identifier')
	}

	mut parts := []string{}
	mut s2 := s
	for s2 != '' {
		if s2[0] == `"` {
			s2 = s2[1..]
			index := s2.index('"') or { return error('invalid identifier chain: ${s}') }
			parts << s2[..index]
			s2 = s2[index + 1..]
		} else {
			mut index := s2.index('.') or { -1 }
			if index < 0 {
				parts << s2.to_upper()
				break
			}
			if index > 0 {
				parts << s2[..index].to_upper()
			}
			s2 = s2[index + 1..]
		}
	}

	return parts
}

fn requote_identifier(s string) string {
	if s.to_upper() == s {
		return s
	}

	return '"${s}"'
}

fn (e Identifier) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	value := data.data[e.id()] or { return sqlstate_42601('unknown column: ${e}') }

	return value
}

fn (e Identifier) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	col := data.data[e.id()] or { return sqlstate_42601('unknown column: ${e}') }

	return col.typ
}

// id is the internal canonical name. How it is represented in memory during
// processing. As opposed to str() which is the human readable form.
fn (e Identifier) id() string {
	if e.custom_id != '' {
		return e.custom_id
	}

	mut parts := []string{}

	if e.catalog_name != '' {
		parts << e.catalog_name
	}

	if e.schema_name != '' {
		parts << e.schema_name
	}

	if e.entity_name != '' {
		parts << e.entity_name
	}

	if e.sub_entity_name != '' {
		parts << e.sub_entity_name
	}

	return parts.join('.')
}

// storage_id is the internal canonical name for disk storage, as opposed to
// str() which is the human readable form.
fn (e Identifier) storage_id() string {
	if e.custom_id != '' {
		return e.custom_id
	}

	mut parts := []string{}

	// Note: The catalog name is not included here because its registered
	// virtually on the connection to the storage.

	if e.schema_name != '' {
		parts << e.schema_name
	}

	if e.entity_name != '' {
		parts << e.entity_name
	}

	if e.sub_entity_name != '' {
		parts << e.sub_entity_name
	}

	return parts.join('.')
}

fn (e Identifier) pstr(params map[string]Value) string {
	return e.str()
}

pub fn (e Identifier) str() string {
	if e.custom_id != '' {
		return e.custom_id
	}

	mut parts := []string{}

	if e.catalog_name != '' {
		parts << requote_identifier(e.catalog_name)
	}

	if e.schema_name != '' {
		parts << requote_identifier(e.schema_name)
	}

	if e.entity_name != '' {
		parts << requote_identifier(e.entity_name)
	}

	if e.sub_entity_name != '' {
		parts << requote_identifier(e.sub_entity_name)
	}

	return parts.join('.')
}

// HostParameterName is :foo. The colon is not included in the name. Parameters
// are case sensitive.
struct HostParameterName {
	name string
}

fn (e HostParameterName) pstr(params map[string]Value) string {
	p := params[e.name]

	if p.typ.typ != .is_numeric && (p.typ.uses_string() || p.typ.uses_time()) {
		return '\'${p.str()}\''
	}

	return p.str()
}

fn (e HostParameterName) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return params[e.name] or { return sqlstate_42p02(e.name) }
}

fn (e HostParameterName) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	p := params[e.name] or { return sqlstate_42p02(e.name) }

	return p.eval_type(conn, data, params)
}

fn parse_table_name(identifier IdentifierChain) !Identifier {
	return new_table_identifier(identifier.identifier)
}

fn parse_schema_name_1(catalog IdentifierChain, identifier Identifier) !Identifier {
	return new_schema_identifier('${catalog}.${identifier}')
}

fn parse_unqualified_schema_name(identifier IdentifierChain) !Identifier {
	return new_schema_identifier(identifier.identifier)
}

fn parse_schema_qualified_name_2(schema_name Identifier, identifier IdentifierChain) !IdentifierChain {
	return IdentifierChain{'${schema_name.schema_name}.${identifier}'}
}

fn parse_local_or_schema_qualified_name2(schema_name Identifier, table_name IdentifierChain) !IdentifierChain {
	return IdentifierChain{'${schema_name}.${table_name}'}
}

fn parse_column_name(column_name IdentifierChain) !Identifier {
	return new_column_identifier(column_name.identifier)
}

fn parse_host_parameter_name(name IdentifierChain) !GeneralValueSpecification {
	return HostParameterName{name.identifier}
}

fn parse_correlation_name(identifier IdentifierChain) !Identifier {
	return new_column_identifier(identifier.identifier)
}
