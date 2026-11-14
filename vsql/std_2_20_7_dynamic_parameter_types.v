module vsql

// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 4 and 5
//
// The data type of each dynamic parameter ("?") is determined from where it's
// used when the statement is prepared, such as the type of the column in "x =
// ?" or the target of "CAST(? AS INTEGER)". The value that it's given when the
// statement is executed is then cast to that type, rather than the value
// deciding the type.
//
// The statement is compiled (without being executed) with each dynamic
// parameter as an untyped null value (see CompileResult.untyped_parameter).
// Each expression that a dynamic parameter can take its type from gives it that
// type (see Compiler.with_type), so a dynamic parameter that is still untyped
// once the statement is compiled is a syntax error, such as either one in "? +
// ?".
//
// Only queries (including a DECLARE CURSOR), INSERT, UPDATE and DELETE are
// compiled, which are the statements that a dynamic parameter is useful in. A
// dynamic parameter of any other statement (or of one that couldn't be
// compiled, such as because the table doesn't exist yet) has the type of its
// value.

// untyped_parameter_type is the type of a dynamic parameter until its type is
// known. Any expression that can't give it a type leaves it untyped, so this
// is never its type.
const untyped_parameter_type = Type{.is_varchar, 0, 0, false}

// position_parameter_type is the type of a dynamic parameter that is the start
// position or string length of a SUBSTRING or OVERLAY, which is the largest
// exact numeric with scale 0.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.vi and 5.a.viii.2
const position_parameter_type = Type{.is_numeric, max_numeric_precision, 0, false}

// describe_parameters returns the data type of each dynamic parameter (by its
// name, such as "?1") that's determined by the statement. A dynamic parameter
// whose type can't be determined is a syntax error, and one that isn't in the
// result (because the statement couldn't be compiled) has the type of its value.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.b
fn (mut conn Connection) describe_parameters(stmt Stmt, params map[string]Value) !map[string]Type {
	conn.describing = true
	conn.parameter_types = map[string]Type{}
	conn.compiled_parameters = map[string]bool{}
	defer {
		conn.describing = false
		conn.parameter_types = map[string]Type{}
		conn.compiled_parameters = map[string]bool{}
	}

	// The closures that are made by compiling the statement are released, the
	// same as when a statement is executed (see PreparedStmt.query).
	conn.frame_describe = stmt
	conn.frame_params = params
	ran := conn.run_frame()
	conn.frame_describe = none
	mut described := true
	if ran {
		described = conn.frame_err is none
	} else {
		conn.describe_statement(stmt, params) or { described = false }
	}

	// A dynamic parameter that couldn't be given a type may also be why the
	// statement couldn't be compiled, such as in "ABS(?)". The error is for the
	// first one.
	mut undetermined := 0
	for name, _ in conn.compiled_parameters {
		position := name[1..].int()
		if name !in conn.parameter_types && (undetermined == 0 || position < undetermined) {
			undetermined = position
		}
	}
	if undetermined > 0 {
		return sqlstate_42601('the data type of ?${undetermined} cannot be determined')
	}

	if !described {
		return map[string]Type{}
	}

	return conn.parameter_types.clone()
}

// describe_statement compiles a statement, without executing it, to determine
// the types of its dynamic parameters (see describe_parameters).
fn (mut conn Connection) describe_statement(stmt Stmt, params map[string]Value) ! {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	match stmt {
		DeleteStatementSearched, QueryExpression {
			create_plan(stmt, params, mut conn)!
		}
		UpdateStatementSearched {
			create_plan(stmt, params, mut conn)!
			stmt.describe_set_clauses(mut conn, params)!
		}
		DeclareCursor {
			create_plan(stmt.query, params, mut conn)!
		}
		UpdateStatementPositioned {
			UpdateStatementSearched{
				table_name:       stmt.table_name
				correlation_name: stmt.correlation_name
				set:              stmt.set
			}.describe_set_clauses(mut conn, params)!
		}
		InsertStatement {
			stmt.describe_values(mut conn, params)!
		}
		else {}
	}
}

// describe_values gives each dynamic parameter that is a value of a VALUES of
// an INSERT the type of its column. A query is the same as any other query.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xix.1.A
fn (stmt InsertStatement) describe_values(mut conn Connection, params map[string]Value) ! {
	if query := stmt.query {
		create_plan(query, params, mut conn)!
		return
	}

	table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())
	columns := if stmt.columns.len > 0 { stmt.columns } else { table.columns.map(it.name) }
	for row in stmt.values {
		for i, element in row_elements(row) {
			if i >= columns.len {
				break
			}
			column := table.column(columns[i].sub_entity_name)!
			mut c := Compiler{
				conn:          conn
				params:        params
				null_type:     column.typ
				default_value: column.default_value
				identity:      identity_of(table, column)
			}
			c.with_type(element.compile(mut c)!, column.typ)
		}
	}
}

// describe_set_clauses gives each dynamic parameter that is the value of a
// <set clause> the type of its column.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xxvi
fn (stmt UpdateStatementSearched) describe_set_clauses(mut conn Connection, params map[string]Value) ! {
	table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())

	// A correlation name is the only name of the table (see execute).
	mut tables := map[string]&Table{}
	if stmt.correlation_name.sub_entity_name != '' {
		tables[stmt.correlation_name.id()] = &Table{
			name:    stmt.correlation_name
			columns: create_update_plan(stmt, params, mut conn)!.columns()
		}
	}
	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}
	for clause in stmt.set {
		table_column := table.column(clause.column_name)!
		if tables.len == 0 {
			c.context = Identifier{
				catalog_name: table_column.name.catalog_name
				schema_name:  table_column.name.schema_name
				entity_name:  table.name.entity_name
			}
		}
		c.null_type = table_column.typ
		c.default_value = table_column.default_value
		c.identity = identity_of(table, table_column)
		c.with_type(clause.source.compile(mut c)!, table_column.typ)
	}
}

// parameter_result is a dynamic parameter that is compiled while its type is
// being determined (see describe_parameters). Its value is the null value,
// since it's never executed. untyped is its name if its type isn't known yet.
fn parameter_result(untyped string, typ Type) CompileResult {
	return CompileResult{
		run:               fn [typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			return Value{
				typ:     typ
				is_null: true
			}
		}
		typ:               typ
		contains_agg:      false
		untyped_parameter: untyped
	}
}

// is_untyped is true if r is a dynamic parameter whose type hasn't been
// determined yet.
fn (c Compiler) is_untyped(r CompileResult) bool {
	return r.untyped_parameter != '' && r.untyped_parameter !in c.conn.parameter_types
}

// with_type returns r, unless it's a dynamic parameter whose type hasn't been
// determined yet. Then its type is typ (without NOT NULL, since it can be the
// null value), and the result has that type.
fn (mut c Compiler) with_type(r CompileResult, typ Type) CompileResult {
	if !c.is_untyped(r) {
		return r
	}

	t := Type{typ.typ, typ.size, typ.scale, false}
	c.conn.parameter_types[r.untyped_parameter] = t

	return parameter_result('', t)
}

// with_types gives the dynamic parameters in results whose types haven't been
// determined the type that the other results combine to (9.5, Result of data
// type combinations), passed through derive. They stay untyped if every result
// is a dynamic parameter, or if the types of the others can't be combined.
fn (mut c Compiler) with_types(results []CompileResult, derive fn (Type) Type) []CompileResult {
	if !c.conn.describing {
		return results
	}

	mut combined := ?Type(none)
	for r in results {
		if c.is_untyped(r) {
			continue
		}
		if typ := combined {
			combined = combine_types(typ, r.typ) or { return results }
		} else {
			combined = r.typ
		}
	}

	typ := combined or { return results }
	return results.map(c.with_type(it, derive(typ)))
}

// with_boolean_type is with_type for an operand that must be a BOOLEAN, such as
// of AND, OR, NOT or IS TRUE, or a search condition. A dynamic parameter on its
// own is also a <boolean value expression> (see common_value_expression), so it
// isn't always a BOOLEAN.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xii
fn (mut c Compiler) with_boolean_type(r CompileResult) CompileResult {
	return c.with_type(r, Type{.is_boolean, 0, 0, false})
}

// with_pair_types is with_types for two operands, such as the sides of a
// comparison.
fn (mut c Compiler) with_pair_types(a CompileResult, b CompileResult, derive fn (Type) Type) (CompileResult, CompileResult) {
	typed := c.with_types([a, b], derive)

	return typed[0], typed[1]
}

// with_row_types is with_types for each position of rows that are compared
// with each other, such as "(a, b) = (?, ?)" or the values of an IN.
fn (mut c Compiler) with_row_types(rows [][]CompileResult) [][]CompileResult {
	if !c.conn.describing {
		return rows
	}

	mut typed := rows.map(it.clone())
	mut degree := 0
	for row in rows {
		if row.len > degree {
			degree = row.len
		}
	}
	for j in 0 .. degree {
		mut column := []CompileResult{}
		for row in typed {
			if j < row.len {
				column << row[j]
			}
		}
		column = c.with_types(column, same_type)
		mut k := 0
		for mut row in typed {
			if j < row.len {
				row[j] = column[k]
				k++
			}
		}
	}

	return typed
}

// with_field_types gives each dynamic parameter in fields whose type hasn't
// been determined the type at the same position of types, such as the columns
// of a subquery that it's compared with.
fn (mut c Compiler) with_field_types(fields []CompileResult, types []Type) []CompileResult {
	mut typed := fields.clone()
	for i, typ in types {
		if i < typed.len {
			typed[i] = c.with_type(typed[i], typ)
		}
	}

	return typed
}

// with_pattern_types gives the dynamic parameters of a LIKE or SIMILAR TO (the
// value, the pattern and the escape character, if there is one) the combined
// type of the others, as a character string. They're all character strings if
// they're all dynamic parameters.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xxv
fn (mut c Compiler) with_pattern_types(value CompileResult, pattern CompileResult, escape CompileResult, has_escape bool) (CompileResult, CompileResult, CompileResult) {
	mut operands := [value, pattern]
	if has_escape {
		operands << escape
	}

	operands = if operands.all(c.is_untyped(it)) {
		operands.map(c.with_type(it, character_type(untyped_parameter_type)))
	} else {
		c.with_types(operands, character_type)
	}

	return operands[0], operands[1], if has_escape { operands[2] } else { escape }
}

// with_argument_types gives the dynamic parameters that are arguments of a
// function their types. CHAR_LENGTH, OCTET_LENGTH, POSITION and MOD have their
// own rules. Any other function is treated as an SQL-invoked routine, where an
// argument has the type of its parameter, as long as there's only one function
// with that name and number of arguments (otherwise it's ambiguous, such as for
// ABS). An aggregate function's argument can't be a dynamic parameter.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.iii, 5.a.iv and 5.a.v
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xxx.1 and 5.a.xxx
fn (mut c Compiler) with_argument_types(function_name string, args []CompileResult) []CompileResult {
	return match function_name {
		'CHAR_LENGTH', 'OCTET_LENGTH' {
			args.map(c.with_type(it, character_type(untyped_parameter_type)))
		}
		'POSITION' {
			c.with_types(args, character_type)
		}
		'MOD' {
			c.with_types(args, same_type)
		}
		else {
			candidates := c.conn.funcs.filter(it.name == function_name
				&& it.arg_types.len == args.len && !it.is_agg)
			if candidates.len == 1 {
				c.with_field_types(args, candidates[0].arg_types.map(character_type(it)))
			} else {
				args
			}
		}
	}
}

// same_type is the derive of with_types for a dynamic parameter that has the
// same type as the other operands.
fn same_type(typ Type) Type {
	return typ
}

// character_type is the derive of with_types for a dynamic parameter of an
// operation on character strings. A character string is a CHARACTER VARYING of
// the implementation-defined maximum length (ML), and any other type is the
// same type.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5
fn character_type(typ Type) Type {
	if typ.typ.is_string() {
		return Type{.is_varchar, max_character_length, 0, false}
	}

	return typ
}
