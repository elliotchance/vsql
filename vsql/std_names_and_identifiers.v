// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers

module vsql

// Format
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

	return eval_as_type(conn, data, p, params)
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
