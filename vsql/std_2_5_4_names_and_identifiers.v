module vsql

// ISO/IEC 9075-2:2023(E), 5.4, Names and identifiers
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
			check_schema_name(parts[0])!
			return Identifier{
				schema_name: parts[0]
			}
		}
		2 {
			check_schema_name(parts[1])!
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
			check_schema_name(parts[0])!
			return Identifier{
				schema_name: parts[0]
				entity_name: parts[1]
			}
		}
		3 {
			check_schema_name(parts[1])!
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
			check_schema_name(parts[0])!
			return Identifier{
				schema_name:     parts[0]
				entity_name:     parts[1]
				sub_entity_name: parts[2]
			}
		}
		4 {
			check_schema_name(parts[1])!
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
			// ISO/IEC 9075-2:2023(E), 6.6, <identifier chain>, Syntax Rules, 5
			return sqlstate_42601('invalid column reference: ${parts.map(requote_identifier(it)).join('.')}')
		}
	}
}

// check_schema_name returns an error for a schema name that can't be used. The
// Definition Schema has this name (ISO/IEC 9075-11:2006(E), 4.1), so nothing
// else can.
//
// ISO/IEC 9075-2:2023(E), 5.4, Names and identifiers, Syntax Rules, 10
fn check_schema_name(name string) ! {
	if name == 'DEFINITION_SCHEMA' {
		return sqlstate_42601('DEFINITION_SCHEMA cannot be used as a schema name')
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
			// A regular identifier is its case-normal form, which is the same as
			// a delimited identifier in upper case (ISO/IEC 9075-2:2023(E), 5.2,
			// <token> and <separator>, Syntax Rules, 25 to 29).
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
	// (long identifiers) needs at least 128 characters (ISO/IEC 9075-2:2023(E),
	// 5.2, <token> and <separator>, Syntax Rules, 13 and 14). Some names (such as of a
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
	// The names of subqueries (such as $1) aren't parsed, so they aren't quoted.
	if s.starts_with('$') || (s.to_upper() == s && is_regular_identifier(s)) {
		return s
	}

	return delimit_identifier(s)
}

// without_catalog_qualifiers returns a statement printed by vsql with the catalog
// name removed from each column reference, which is the only name that has four
// parts. The catalog of a stored definition is always the file (see
// Compiler.stored_definition), but a dump can be loaded into a file with any
// name. The text is scanned because a definition is printed from its expression,
// which has no way to change an identifier. A name is always printed without
// spaces around the dots, and anything in a string isn't a name.
fn without_catalog_qualifiers(stmt string) string {
	cs := stmt.runes()
	mut result := []rune{cap: cs.len}
	mut i := 0
	for i < cs.len {
		mut start := i
		mut end := i + 1
		if cs[i] == `'` {
			end = quoted_end(cs, i)
		} else if cs[i] == `"` || is_identifier_char(cs[i], false) {
			mut starts := [i]
			end = identifier_part_end(cs, i)
			for end < cs.len && cs[end] == `.` {
				starts << end + 1
				end = identifier_part_end(cs, end + 1)
			}
			if starts.len == 4 {
				start = starts[1]
			}
		}
		result << cs[start..end]
		i = end
	}

	return result.string()
}

// identifier_part_end is the index after the name that starts at the index.
fn identifier_part_end(cs []rune, start int) int {
	if cs[start] == `"` {
		return quoted_end(cs, start)
	}

	mut end := start
	for end < cs.len && is_identifier_char(cs[end], true) {
		end++
	}

	return end
}

// quoted_end is the index after the string or delimited identifier that starts
// at the index, where a doubled quote is a part of it. It's only used on a whole
// statement printed by vsql, so the closing quote is always followed by something
// (at least the semicolon).
fn quoted_end(cs []rune, start int) int {
	mut i := start + 1
	for cs[i] != cs[start] || cs[i + 1] == cs[start] {
		i += if cs[i] == cs[start] { 2 } else { 1 }
	}

	return i + 1
}

// is_regular_identifier is true if s is read as a name without quotes. It must
// only contain identifier characters, and not be a token other than a
// non-reserved word (see tokenize and "non-reserved words" in grammar.y).
fn is_regular_identifier(s string) bool {
	for i, c in s.runes() {
		if !is_identifier_char(c, i > 0) {
			return false
		}
	}

	upper := s.to_upper()
	if upper == 'E' || upper == 'LIMIT' {
		return true
	}
	tok_number := token_numbers[upper] or { return true }

	// Only a non-reserved word can be a regular identifier.
	return tok_number >= token_a && tok_number <= token_zone
}

// token_numbers is the token of each name in yy_toknames, so that a name can be
// found without going through all of them.
const token_numbers = new_token_numbers()

fn new_token_numbers() map[string]int {
	mut tokens := map[string]int{}
	for tok_pos, tok_name in yy_toknames {
		tokens[tok_name] = tok_pos + 57343
	}

	return tokens
}

fn (e Identifier) compile(mut c Compiler) !CompileResult {
	// A name in an ORDER BY is the column of the result with that name, if there
	// is one, even if it's also the name of a column of a table. That column is
	// already allowed by the select list, so the rules for a column that's in a
	// sort key (DISTINCT and grouping) don't apply. It isn't in the scope of the
	// argument of an aggregate function, or of a subquery (a subquery has its own
	// Compiler).
	//
	// ISO/IEC 9075-2:2023(E), 6.6, <identifier chain>, Syntax Rules, 9.a.i and 9.c
	if e.entity_name == '' && e.custom_id == '' && !c.in_aggregate {
		if exprs := c.result_columns[e.sub_entity_name] {
			if exprs.len > 1 {
				return sqlstate_42702(e.sub_entity_name)
			}

			mut select_list := Compiler{
				conn:   c.conn
				params: c.params
				tables: c.tables
			}
			result := exprs[0].compile(mut select_list)!
			if select_list.uses_next_value {
				c.next_value_sort_keys << exprs[0]
			}

			return result
		}
	}

	// The column must exist before it can be checked against the grouping
	// columns, otherwise an unknown column would be reported as not grouped.
	aggregated_columns := c.aggregated_columns.len
	compiled := e.compile_column(mut c)!
	c.flag_column_reference(e)

	// A column of this query, rather than an outer reference (which is added by
	// compile_outer).
	if c.in_aggregate && e.custom_id == '' && c.aggregated_columns.len == aggregated_columns {
		c.aggregated_columns << AggregatedColumn{
			scope: -1
		}
	}

	// A group-invariant column reference must be a grouping column, since there
	// are no functional dependencies (Feature T301).
	//
	// ISO/IEC 9075-2:2023(E), 6.7, <column reference>, Conformance Rules, 2
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

	// ISO/IEC 9075-2:2023(E), 11.4, <column definition>, Syntax Rules, 17.d
	if c.check_column != '' && e.custom_id == '' && e.sub_entity_name != c.check_column {
		return sqlstate_42601('CHECK on column ${c.check_column} cannot use column ${e.sub_entity_name}')
	}
	if c.restricted != '' && e.custom_id == '' {
		c.check_columns[e.sub_entity_name] = true
	}

	// ISO/IEC 9075-2:2023(E), 11.4, <column definition>, Syntax Rules, 10.c
	if c.generation_column != '' && e.custom_id == '' {
		table := c.tables[c.context.id()] or { &Table{} }
		column := table.column(e.sub_entity_name) or { Column{} }
		if _ := column.generated {
			return sqlstate_42601('generation expression of ${c.generation_column} cannot use generated column ${e.sub_entity_name}')
		}
	}

	if c.conn.collect_columns && e.custom_id == '' {
		c.conn.collect_column(e, c.tables)
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
	// The id is only made once, rather than for each row.
	id := e.id()

	// 1. custom_id is used as a hack to wrap aggregate functions. This should be
	// removed in the future.
	if e.custom_id != '' {
		return CompileResult{
			run:          fn [e, id] (mut conn Connection, data Row, params map[string]Value) !Value {
				return data.data.get(id) or { return sqlstate_42601('unknown column: ${e}') }
			}
			typ:          e.custom_typ
			contains_agg: false
		}
	}

	// A column of a query that contains this subquery (an outer reference),
	// unless it's a column of this query.
	if c.conn.subquery_scopes.len > 0 && !e.is_column_of(c.conn, c.tables, c.context) {
		for i := c.conn.subquery_scopes.len - 1; i >= 0; i-- {
			scope := c.conn.subquery_scopes[i]
			if e.is_column_of(c.conn, scope.tables, scope.context) {
				return e.compile_outer(mut c, i)
			}
		}
	}

	// A column must be in one of the tables in the FROM clause.
	if c.tables.len > 0 && c.context.entity_name == ''
		&& !e.is_column_of(c.conn, c.tables, c.context) {
		return sqlstate_42601_column('unknown column: ${c.conn.resolve_identifier(e)}',
			e.qualifying_table(c), e.sub_entity_name)
	}

	// 2. A qualified field in a subquery table.
	if table := c.tables[e.entity_name] {
		column := table.column(e.sub_entity_name) or { Column{} }
		if column.name.sub_entity_name == e.sub_entity_name {
			return CompileResult{
				run:          fn [e, id] (mut conn Connection, data Row, params map[string]Value) !Value {
					return data.data.get(id) or { return sqlstate_42601('unknown column: ${e}') }
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
		qualifier := if c.stored_definition {
			c.context
		} else {
			c.conn.resolve_identifier(Identifier{
				catalog_name: e.catalog_name
				schema_name:  e.schema_name
				entity_name:  e.entity_name
			})
		}
		if qualifier.catalog_name != c.context.catalog_name
			|| qualifier.schema_name != c.context.schema_name
			|| qualifier.entity_name != c.context.entity_name {
			return sqlstate_42p01_table(qualifier)
		}

		// The table of a CHECK constraint doesn't exist yet when the CREATE TABLE
		// is checked (see CheckConstraintDefinition.compile).
		if table := c.tables[qualifier.id()] {
			if column := table.column(e.sub_entity_name) {
				column_id := column.name.id()
				return CompileResult{
					run:          fn [column, column_id] (mut conn Connection, data Row, params map[string]Value) !Value {
						return data.data.get(column_id) or {
							return sqlstate_42601('unknown column: ${column.name}')
						}
					}
					typ:          column.typ
					contains_agg: false
				}
			}
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
	// The table is looked up by name, rather than going through every table,
	// since getting the Table of a virtual table copies all of its columns.
	table_id := Identifier{
		schema_name: ident.schema_name
		entity_name: ident.entity_name
	}.storage_id()
	mut found := ?Table(none)
	if table := catalog.storage.tables[table_id] {
		found = table
	} else if virtual_table := catalog.virtual_tables[table_id] {
		found = virtual_table.table()
	}
	if table := found {
		column := table.column(ident.sub_entity_name) or { Column{} }
		if column.name.sub_entity_name == ident.sub_entity_name {
			ident_id := ident.id()
			return CompileResult{
				run:          fn [ident, ident_id] (mut conn Connection, data Row, params map[string]Value) !Value {
					return data.data.get(ident_id) or {
						return sqlstate_42601('unknown column: ${ident}')
					}
				}
				typ:          column.typ
				contains_agg: false
			}
		}
	}

	// An unqualified column name must only be in one of the tables.
	//
	// ISO/IEC 9075-2:2023(E), 6.6, <identifier chain>, Syntax Rules, 9.c
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

			ident_id := ident.id()
			return CompileResult{
				run:          fn [ident, ident_id] (mut conn Connection, data Row, params map[string]Value) !Value {
					return data.data.get(ident_id) or {
						return sqlstate_42601('unknown column: ${ident}')
					}
				}
				typ:          column.typ
				contains_agg: false
			}
		}
	}

	return sqlstate_42601('unknown column: ${ident}')
}

// qualifying_table is the table in the FROM clause that a qualified column
// reference is qualified with, or empty if there isn't one.
fn (e Identifier) qualifying_table(c &Compiler) Identifier {
	if e.entity_name == '' {
		return Identifier{}
	}

	qualifier := c.conn.resolve_identifier(Identifier{
		catalog_name: e.catalog_name
		schema_name:  e.schema_name
		entity_name:  e.entity_name
	})
	for _, table in c.tables {
		if table.name.schema_name == qualifier.schema_name
			&& table.name.entity_name == qualifier.entity_name {
			return table.name
		}
	}

	return Identifier{}
}

// is_column_of is true if the column reference is a column of one of the
// tables, or of the table of the context (such as the table of an UPDATE).
fn (e Identifier) is_column_of(conn &Connection, tables map[string]&Table, context Identifier) bool {
	for _, table in tables {
		if e.is_column_of_table(conn, table) {
			return true
		}
	}

	if context.entity_name != '' {
		table_name := conn.resolve_identifier(context)
		if catalog := conn.catalogs[table_name.catalog_name] {
			if table := catalog.storage.tables[table_name.storage_id()] {
				return e.is_column_of_table(conn, table)
			}
		}
	}

	return false
}

fn (e Identifier) is_column_of_table(conn &Connection, table Table) bool {
	table.column(e.sub_entity_name) or { return false }

	if e.entity_name == '' {
		return true
	}

	// A derived table, or a table with a correlation name, is only known by that
	// name.
	if table.name.schema_name == '' {
		return e.schema_name == '' && e.catalog_name == '' && table.name.id() == e.entity_name
	}

	qualifier := conn.resolve_identifier(Identifier{
		catalog_name: e.catalog_name
		schema_name:  e.schema_name
		entity_name:  e.entity_name
	})

	return table.name.schema_name == qualifier.schema_name
		&& table.name.entity_name == qualifier.entity_name
		&& table.name.catalog_name in ['', qualifier.catalog_name]
}

// compile_outer compiles a reference to a column of the query of
// conn.subquery_scopes[i], which contains the subquery being compiled. It's the
// value of the column in the row of that query that the subquery is being
// evaluated for.
//
// ISO/IEC 9075-2:2023(E), 6.6, <identifier chain>, Syntax Rules, 8
fn (e Identifier) compile_outer(mut c Compiler, i int) !CompileResult {
	scope := c.conn.subquery_scopes[i]

	// ISO/IEC 9075-2:2023(E), 7.16, <query specification>, Syntax Rules, 15
	// ISO/IEC 9075-2:2023(E), 7.14, <having clause>, Syntax Rules, 4
	mut ungrouped := false
	if grouping_columns := scope.grouping_columns {
		ungrouped = !e.is_grouping_column(grouping_columns)
	}

	// In the argument of an aggregate function it might not need to be grouped,
	// because the aggregate function may be of the outer query (see
	// Compiler.aggregation_scope).
	if c.in_aggregate {
		c.aggregated_columns << AggregatedColumn{i, e.str(), ungrouped}
	} else if ungrouped {
		return sqlstate_42803(e.str())
	}

	// It's compiled like it is in that query, which can only see the queries that
	// contain it.
	mut outer := Compiler{
		conn:    c.conn
		params:  c.params
		tables:  scope.tables
		context: scope.context
	}
	scopes := c.conn.subquery_scopes.clone()
	c.conn.subquery_scopes = scopes[..i].clone()
	compiled := e.compile_column(mut outer) or {
		c.conn.subquery_scopes = scopes
		return err
	}
	c.conn.subquery_scopes = scopes
	c.conn.vary_subqueries(i)

	return CompileResult{
		run:          fn [i, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
			return compiled.run(mut conn, conn.subquery_scopes[i].row, params)!
		}
		typ:          compiled.typ
		contains_agg: false
	}
}

// id is the internal canonical name. How it is represented in memory during
// processing. As opposed to str() which is the human readable form.
fn (e Identifier) id() string {
	if e.custom_id != '' {
		return e.custom_id
	}

	// This is called for every name that's compiled, so it doesn't build an
	// array of the parts to join them.
	return join_name_part(join_name_part(join_name_part(e.catalog_name, e.schema_name),
		e.entity_name), e.sub_entity_name)
}

// join_name_part puts part after name with a '.', unless either is empty.
fn join_name_part(name string, part string) string {
	if part == '' {
		return name
	}

	if name == '' {
		return part
	}

	return '${name}.${part}'
}

// storage_id is the internal canonical name for disk storage, as opposed to
// str() which is the human readable form.
fn (e Identifier) storage_id() string {
	// Note: The catalog name is not included here because its registered
	// virtually on the connection to the storage.
	return join_name_part(join_name_part(storage_id_part(e.schema_name), storage_id_part(e.entity_name)),
		storage_id_part(e.sub_entity_name))
}

// storage_id_part is a part of a storage_id. A name that contains a '.' is
// quoted, otherwise "A.B".C and A."B.C" would be the same. So is a name with a
// quote, so that it can't be mistaken for a quoted name.
fn storage_id_part(part string) string {
	if part.contains('.') || part.contains('"') {
		return delimit_identifier(part)
	}

	return part
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
