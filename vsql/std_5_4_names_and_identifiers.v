module vsql

// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers
//
// Specify names.

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
	custom_id  string
	custom_typ Type
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
				schema_name:  parts[1]
			}
		}
		else {
			return sqlstate_42602('invalid identifier: ${s}')
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
				schema_name:  parts[1]
				entity_name:  parts[2]
			}
		}
		else {
			return sqlstate_42602('invalid identifier: ${s}')
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
				entity_name:     parts[0]
				sub_entity_name: parts[1]
			}
		}
		3 {
			return Identifier{
				schema_name:     parts[0]
				entity_name:     parts[1]
				sub_entity_name: parts[2]
			}
		}
		4 {
			return Identifier{
				catalog_name:    parts[0]
				schema_name:     parts[1]
				entity_name:     parts[2]
				sub_entity_name: parts[3]
			}
		}
		else {
			// More parts would be fields of a row type, which aren't supported.
			//
			// ISO/IEC 9075-2:2016(E), 6.6, <identifier chain>, Syntax Rules, 5
			return sqlstate_42601('invalid column reference: ${parts.map(requote_identifier(it)).join('.')}')
		}
	}
}

fn split_identifier_parts(s string) ![]string {
	if s == '' {
		return sqlstate_42602('cannot use empty string for identifier')
	}

	mut parts := []string{}
	mut s2 := s
	for s2 != '' {
		if s2[0] == `"` {
			// A doubled quote ("") is one quote character of the name.
			mut part := []u8{}
			mut i := 1
			for {
				if i >= s2.len {
					return sqlstate_42602('invalid identifier chain: ${s}')
				}
				if s2[i] == `"` {
					if i + 1 < s2.len && s2[i + 1] == `"` {
						part << `"`
						i += 2
						continue
					}
					break
				}
				part << s2[i]
				i++
			}
			parts << part.bytestr()
			s2 = s2[i + 1..]
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

	// The maximum length of an identifier is implementation-defined, but F391
	// (long identifiers) needs at least 128 characters. Some names (such as of a
	// schema or sequence) are in the keys of objects in the file, which must fit
	// in a page.
	for part in parts {
		if part.runes().len > max_identifier_length {
			return sqlstate_42601('identifier is longer than ${max_identifier_length} characters: ${part}')
		}
	}

	return parts
}

const max_identifier_length = 128

// delimit_identifier always quotes the name, like "foo" or "FOO". Use this
// (rather than requote_identifier) when the SQL needs to mean the same thing
// in every version of vsql, even if new reserved words are added.
//
// A quote in the name is doubled ("").
fn delimit_identifier(s string) string {
	return '"${s.replace('"', '""')}"'
}

// requote_identifier only quotes the name if it needs to be, so that the
// result can be parsed back into the same name.
fn requote_identifier(s string) string {
	if s.to_upper() == s && !s.contains('.') && !s.contains('"') {
		return s
	}

	return delimit_identifier(s)
}

fn (e Identifier) compile(mut c Compiler) !CompileResult {
	// The column must exist before it can be checked against the grouping
	// columns, otherwise an unknown column would be reported as not grouped.
	compiled := e.compile_column(mut c)!

	if grouping_columns := c.grouping_columns {
		if e.custom_id == '' && !c.in_aggregate && !e.is_grouping_column(grouping_columns) {
			return sqlstate_42803(e.str())
		}
	}

	if distinct_columns := c.distinct_columns {
		if e.custom_id == '' && !e.is_grouping_column(distinct_columns) {
			return sqlstate_42p10(e.str())
		}
	}

	return compiled
}

// is_grouping_column is true if the column reference is one of the grouping
// columns. A qualified name must also match the table.
fn (e Identifier) is_grouping_column(grouping_columns []Column) bool {
	for column in grouping_columns {
		if e.sub_entity_name == column.name.sub_entity_name
			&& (e.entity_name == '' || e.entity_name == column.name.entity_name) {
			return true
		}
	}

	return false
}

fn (e Identifier) compile_column(mut c Compiler) !CompileResult {
	// There are lots of ways to reoslve an identifer...
	//
	// 1. custom_id is used as a hack to wrap aggregate functions. This should be
	// removed in the future.
	if e.custom_id != '' {
		return CompileResult{
			run:          fn [e] (mut conn Connection, data Row, params map[string]Value) !Value {
				return data.data[e.id()] or { return sqlstate_42601('unknown column: ${e}') }
			}
			typ:          e.custom_typ
			contains_agg: false
		}
	}

	// 2. A qualified field in a subquery table.
	if table := c.tables[e.entity_name] {
		column := table.column(e.sub_entity_name) or { Column{} }
		if column.name.sub_entity_name == e.sub_entity_name {
			return CompileResult{
				run:          fn [e] (mut conn Connection, data Row, params map[string]Value) !Value {
					return data.data[e.id()] or { return sqlstate_42601('unknown column: ${e}') }
				}
				typ:          column.typ
				contains_agg: false
			}
		}
	}

	// 3. Try to use the context, which is the table of an UPDATE. Only that
	// table is in scope, so a column qualified with another table isn't a column
	// of it.
	if c.context.entity_name != '' && e.entity_name != '' {
		qualifier := c.conn.resolve_identifier(Identifier{
			catalog_name: e.catalog_name
			schema_name:  e.schema_name
			entity_name:  e.entity_name
		})
		if qualifier.catalog_name != c.context.catalog_name
			|| qualifier.schema_name != c.context.schema_name
			|| qualifier.entity_name != c.context.entity_name {
			return sqlstate_42p01('table', qualifier.str())
		}
	}

	mut ident := c.conn.resolve_identifier(Identifier{
		catalog_name:    if c.context.catalog_name != '' {
			c.context.catalog_name
		} else {
			e.catalog_name
		}
		schema_name:     if c.context.schema_name != '' {
			c.context.schema_name
		} else {
			e.schema_name
		}
		entity_name:     if c.context.entity_name != '' {
			c.context.entity_name
		} else {
			e.entity_name
		}
		sub_entity_name: e.sub_entity_name
	})
	mut catalog := c.conn.catalogs[ident.catalog_name] or {
		return sqlstate_42601('unknown column: ${ident}')
	}
	mut catalog_tables := catalog.storage.tables.values()
	for _, virtual_table in catalog.virtual_tables {
		catalog_tables << virtual_table.table()
	}
	for table in catalog_tables {
		if table.name.schema_name == ident.schema_name
			&& table.name.entity_name == ident.entity_name {
			column := table.column(ident.sub_entity_name) or { Column{} }
			if column.name.sub_entity_name == ident.sub_entity_name {
				return CompileResult{
					run:          fn [ident] (mut conn Connection, data Row, params map[string]Value) !Value {
						return data.data[ident.id()] or {
							return sqlstate_42601('unknown column: ${ident}')
						}
					}
					typ:          column.typ
					contains_agg: false
				}
			}
		}
	}

	// An unqualified column name must only be in one of the tables.
	//
	// ISO/IEC 9075-2:2016(E), 6.6, <identifier chain>, Syntax Rules, 8c
	if e.entity_name == '' {
		mut tables_with_column := map[string]bool{}
		for _, table in c.tables {
			if _ := table.column(e.sub_entity_name) {
				tables_with_column[table.name.id()] = true
			}
		}
		if tables_with_column.len > 1 {
			return sqlstate_42702(e.sub_entity_name)
		}
	}

	// 3. An bare field in a subquery tables.
	ident = c.conn.resolve_identifier(e)
	for _, table in c.tables {
		column := table.column(e.sub_entity_name) or { Column{} }
		if e.entity_name == '' && column.name.sub_entity_name == e.sub_entity_name {
			ident = column.name

			return CompileResult{
				run:          fn [ident] (mut conn Connection, data Row, params map[string]Value) !Value {
					return data.data[ident.id()] or {
						return sqlstate_42601('unknown column: ${ident}')
					}
				}
				typ:          column.typ
				contains_agg: false
			}
		}
	}

	// 4. A bare table field. A qualified name that didn't match a table above
	// isn't one (its qualifier mustn't be ignored).
	//
	// TODO(elliotchance): Check for ambiguous field name.
	for _, table in catalog.storage.tables {
		if e.entity_name == '' && table.name.schema_name == ident.schema_name {
			column := table.column(ident.sub_entity_name) or { Column{} }
			if column.name.sub_entity_name == ident.sub_entity_name {
				ident = column.name

				return CompileResult{
					run:          fn [ident] (mut conn Connection, data Row, params map[string]Value) !Value {
						return data.data[ident.id()] or {
							return sqlstate_42601('unknown column: ${ident}')
						}
					}
					typ:          column.typ
					contains_agg: false
				}
			}
		}
	}

	return sqlstate_42601('unknown column: ${ident}')
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
	mut parts := []string{}

	// Note: The catalog name is not included here because its registered
	// virtually on the connection to the storage.

	// A name that contains a '.' is quoted, otherwise "A.B".C and A."B.C" would
	// be the same. So is a name with a quote, so that it can't be mistaken for
	// a quoted name.
	for part in [e.schema_name, e.entity_name, e.sub_entity_name] {
		if part != '' {
			parts << if part.contains('.') || part.contains('"') {
				delimit_identifier(part)
			} else {
				part
			}
		}
	}

	return parts.join('.')
}

// storage_sql is the name as it's written in the definition of an object in the
// file, like "PUBLIC"."foo". The catalog name is not included (just like
// storage_id) because the catalog is the file itself.
pub fn (e Identifier) storage_sql() string {
	mut parts := []string{}

	if e.schema_name != '' {
		parts << delimit_identifier(e.schema_name)
	}

	if e.entity_name != '' {
		parts << delimit_identifier(e.entity_name)
	}

	if e.sub_entity_name != '' {
		parts << delimit_identifier(e.sub_entity_name)
	}

	return parts.join('.')
}

fn (e Identifier) pstr(_ map[string]Value) string {
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
	return params[e.name].pstr(params)
}

fn (e HostParameterName) compile(mut c Compiler) !CompileResult {
	p := c.params[e.name] or { return sqlstate_42p02(e.name) }

	return CompileResult{
		run:          fn [p] (mut conn Connection, data Row, params map[string]Value) !Value {
			return p
		}
		typ:          p.typ
		contains_agg: false
	}
}
