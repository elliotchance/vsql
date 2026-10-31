module vsql

// ISO/IEC 9075-2:2016(E), 13.1, <SQL-client module definition>
//
// Define an SQL-client module.
//
// "vsql module" compiles a module with LANGUAGE C (Feature B112, "Module
// language C") into a C header and source file. Each <externally-invoked
// procedure> becomes a C function that calls the SQL/CLI routines in libvsql.

// CompiledModule is the C header (.h) and source (.c) of an SQL-client module.
pub struct CompiledModule {
pub:
	header string
	source string
}

struct SQLClientModule {
	// The schema is the default schema of the module's statements (13.1 Syntax
	// Rule 2). vsql has no authorization identifiers, so AUTHORIZATION only
	// gives the schema when there isn't a SCHEMA.
	schema     string
	cursors    []ModuleCursor
	procedures []ExternallyInvokedProcedure
}

// require adds a section of the C runtime, and the sections that it uses.
fn require(mut sections []string, section string) {
	if section in sections {
		return
	}
	sections << section
	for other in c_runtime_requires[section] or { []string{} } {
		require(mut sections, other)
	}
}

// The C runtime that the generated source file uses, in sections that are only
// included when a procedure needs them, otherwise the C compiler warns that a
// static function isn't used.
const c_module_runtime = $embed_file('std_2_13_1_sql_client_module_definition.c').to_string() +
	$embed_file('std_2_14_7_select_statement_single_row.c').to_string() +
	$embed_file('std_2_14_1_declare_cursor.c').to_string() +
	$embed_file('std_2_23_1_get_diagnostics_statement.c').to_string() +
	$embed_file('std_2_20_1_description_of_sql_descriptor_areas.c').to_string() +
	$embed_file('std_2_20_7_prepare_statement.c').to_string()

// The other sections that a section of the C runtime uses, which are also
// included.
const c_runtime_requires = {
	'exec':                  ['param']
	'cursor':                ['cursors']
	'descriptor':            ['connection', 'find_descriptor']
	'allocate_descriptor':   ['connection', 'find_descriptor']
	'deallocate_descriptor': ['connection', 'find_descriptor']
	'get_item':              ['descriptor', 'match']
	'get_data':              ['diagnostics_put']
	'set_count':             ['descriptor']
	'set_item':              ['descriptor']
	'set_data':              ['match']
	'prepared':              ['connection', 'cursors']
	'prepared_statement':    ['prepared']
	'prepare':               ['prepared']
	'deallocate_prepare':    ['prepared']
	'describe':              ['prepared_statement', 'descriptor']
	'input':                 ['param', 'scan', 'descriptor', 'items']
	'output':                ['target', 'descriptor', 'items']
	'execute_prepared':      ['prepared_statement', 'input', 'output']
	'execute_immediate':     ['connection', 'scan']
	'open_dynamic':          ['prepared_statement', 'input', 'cursor']
	'fetch_dynamic':         ['cursor', 'output']
}

// compile_module compiles an SQL-client module (with LANGUAGE C) into C. The C
// source includes the header as name + ".h", so name is usually the file name
// of the module without its extension. The C source must be compiled with
// libvsql.h and linked with libvsql.
pub fn compile_module(source string, name string) !CompiledModule {
	m := parse_sql_client_module(source)!

	return CompiledModule{
		header: m.c_header(name)
		source: m.c_source(name, false)
	}
}

// parse_sql_client_module reads an <SQL-client module definition>. Each part
// that ends with a semicolon is a <declare cursor>, a "PROCEDURE ... (...)" or
// the <SQL procedure statement> after it. The first part also starts with the
// rest of the module. The cursors are read first, so a procedure can use a
// cursor that's declared after it.
fn parse_sql_client_module(source string) !SQLClientModule {
	parts := split_module(source)!

	mut t := new_module_tokens(parts[0])!
	schema := t.module_header()!

	mut cursors := []ModuleCursor{}
	mut declarations := []ModuleTokens{}
	mut statements := []string{}
	mut i := 0
	for i < parts.len {
		if i > 0 {
			t = new_module_tokens(parts[i])!
		}
		if peek := t.peek() {
			if peek.kind == .word && peek.text.to_upper() == 'DECLARE' {
				cursor := declare_module_cursor(parts[i].runes()[peek.start..].string(), cursors.len)!

				// - 14.1 SR 1.a. Each cursor has a different name.
				for c in cursors {
					if c.name == cursor.name {
						return sqlstate_42601('cursor ${cursor.name} is declared more than once')
					}
				}
				cursors << cursor
				i++
				continue
			}
		}
		if i + 1 >= parts.len {
			return sqlstate_42601('a module must end with a procedure that has a statement')
		}
		declarations << t
		statements << parts[i + 1]
		i += 2
	}

	// - 20.15 SR 2. A dynamic cursor is declared for a statement that's
	// prepared in the module.
	prepared := prepared_statement_names(statements)
	for cursor in cursors {
		if cursor.statement != '' && cursor.statement !in prepared {
			return sqlstate_42601('cursor ${cursor.name}: statement ${cursor.statement} is not prepared in the module')
		}
	}

	mut procedures := []ExternallyInvokedProcedure{}
	for j, declaration in declarations {
		t = declaration
		mut procedure := t.procedure_declaration()!

		// - 13.3 SR 1. Each procedure has a different name.
		for p in procedures {
			if p.name.to_upper() == procedure.name.to_upper() {
				return sqlstate_42601('procedure ${procedure.name} is defined more than once')
			}
		}

		procedure.statement = parse_module_statement(statements[j], procedure, cursors,
			prepared)!
		procedures << procedure
	}

	return SQLClientModule{schema, cursors, procedures}
}

// module_header reads everything before the first PROCEDURE, and returns the
// schema of the module.
fn (mut t ModuleTokens) module_header() !string {
	t.module_name_clause()!

	// - 13.1 SR 1. A <language clause>, which must be C.
	t.expect('LANGUAGE')!
	language := t.next_word()
	if language != 'C' {
		return sqlstate_42601('only LANGUAGE C is supported, not ${language}')
	}

	// - <module authorization clause>.
	mut schema := ''
	if t.accept('SCHEMA') {
		schema = t.identifier('schema name')!
	}
	if t.accept('AUTHORIZATION') {
		authorization := t.identifier('module authorization identifier')!

		// - 13.1 SR 2. Without SCHEMA, the schema has the same name as the
		// <module authorization identifier>.
		if schema == '' {
			schema = authorization
		}
	}
	if schema == '' {
		return sqlstate_42601('expected SCHEMA or AUTHORIZATION after LANGUAGE C')
	}

	// The other optional parts of the module (such as FOR STATIC ONLY or PATH)
	// aren't supported yet.
	if t.next_word() !in ['PROCEDURE', 'DECLARE'] {
		return sqlstate_42601('expected PROCEDURE or DECLARE after the module authorization clause')
	}
	t.pos--

	return schema
}

// split_module splits the module at each semicolon that isn't in a literal, a
// delimited identifier or a comment. There can only be spaces and comments
// after the last one.
fn split_module(source string) ![]string {
	cs := source.runes()
	mut parts := []string{}
	mut start := 0
	mut i := 0
	for i < cs.len {
		if is_comment(cs, i) {
			i = skip_comment(cs, i)!
		} else if cs[i] == `'` {
			_, end, _ := read_string_literal(cs, i)!
			i = end
		} else if cs[i] == `"` {
			i = skip_delimited_identifier(cs, i)
		} else {
			if cs[i] == `;` {
				parts << cs[start..i].string()
				start = i + 1
			}
			i++
		}
	}

	if tokenize(cs[start..].string())!.len > 0 {
		return sqlstate_42601('a statement in a module must end with a semicolon')
	}

	return parts
}

// skip_delimited_identifier returns the position after the delimited
// identifier that starts at cs[i]. A doubled quote is a quote in the name. It
// can be after the end, if there's no closing quote.
fn skip_delimited_identifier(cs []rune, i int) int {
	mut j := i + 1
	for j < cs.len && (cs[j] != `"` || (j + 1 < cs.len && cs[j + 1] == `"`)) {
		j += if cs[j] == `"` { 2 } else { 1 }
	}

	return j + 1
}

// c_header declares a C function for each procedure.
fn (m SQLClientModule) c_header(name string) string {
	guard := c_identifier(name).to_upper() + '_H'
	mut s := '/* Generated by "vsql module". */\n\n#ifndef ${guard}\n#define ${guard}\n\n'
	s += '#ifdef __cplusplus\nextern "C" {\n#endif\n\n'
	for p in m.procedures {
		s += '${p.c_prototype()};\n'
	}
	s += '\n#ifdef __cplusplus\n}\n#endif\n\n#endif\n'

	return s
}

// c_source defines a C function for each procedure, after the parts of the C
// runtime that they use. The functions of an embedded SQL program's implied
// module (see 21.1) are static, and there's no header.
fn (m SQLClientModule) c_source(name string, embedded bool) string {
	mut sections := ['core']
	for p in m.procedures {
		for section in p.statement.sections {
			require(mut sections, section)
		}
	}

	command := if embedded { 'precompile' } else { 'module' }
	mut s := '/* Generated by "vsql ${command}". */\n\n#include <ctype.h>\n#include <stdlib.h>\n#include <string.h>\n\n'
	s += '#include "libvsql.h"\n'
	if !embedded {
		s += '#include "${name}.h"\n'
	}
	s += '\n'
	set_schema := "SET SCHEMA '" + m.schema.replace("'", "''") + "'"
	s += 'static const char vsql_m_set_schema[] = ${c_string(set_schema)};\n\n'
	if 'cursors' in sections {
		s += 'static const int vsql_m_cursor_count = ${m.cursors.len};\n\n'
	}

	// The prepared statement of each dynamic cursor, or NULL for a cursor that
	// isn't dynamic. The last one is always NULL.
	if 'prepared' in sections {
		mut names := []string{}
		for cursor in m.cursors {
			names << if cursor.statement == '' { 'NULL' } else { c_string(cursor.statement) }
		}
		names << 'NULL'
		s += 'static const char *const vsql_m_cursor_statements[] = {${names.join(', ')}};\n\n'
	}
	// Git may check out the runtime with CRLF line endings (on Windows).
	for section in c_module_runtime.replace('\r\n', '\n').split('/* section ')[1..] {
		section_name := section.all_before(' ')
		if section_name in sections {
			s += section.all_after('*/\n') + '\n'
		}
	}
	for p in m.procedures {
		if embedded {
			s += 'static '
		}
		s += p.c_function()
	}

	return s
}

// c_string is a C string literal.
fn c_string(s string) string {
	return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r',
		'\\r').replace('\t', '\\t') + '"'
}

// c_identifier replaces each character of name that can't be in a C
// identifier with an underscore.
fn c_identifier(name string) string {
	mut s := ''
	for i, c in name.runes() {
		s += if is_identifier_char(c, i > 0) { c.str() } else { '_' }
	}

	return s
}

// ModuleToken is a word (a keyword or a regular identifier, as it was written),
// a delimited identifier (without the quotes), a number, a character string
// literal (its value) or another character. start is the position of its first
// character.
struct ModuleToken {
	kind  ModuleTokenKind
	text  string
	start int
}

enum ModuleTokenKind {
	word
	delimited
	number
	literal
	other
}

// ModuleTokens reads the tokens of a module, other than the statements that
// libvsql executes. Unlike tokenize, a keyword is kept as it was written, since
// the name of a procedure or host parameter is also a C name.
struct ModuleTokens {
	tokens []ModuleToken
mut:
	pos int
}

fn new_module_tokens(text string) !ModuleTokens {
	cs := text.runes()
	mut tokens := []ModuleToken{}
	mut i := 0
	for i < cs.len {
		start := i
		if is_comment(cs, i) {
			i = skip_comment(cs, i)!
		} else if cs[i] == `'` {
			value, end, _ := read_string_literal(cs, i)!
			tokens << ModuleToken{.literal, value, start}
			i = end
		} else if cs[i] == `"` {
			i = skip_delimited_identifier(cs, i)
			if i - start == 2 {
				return sqlstate_42601('invalid delimited identifier: ${cs[start..].string()}')
			}
			tokens << ModuleToken{.delimited, cs[start + 1..i - 1].string().replace('""', '"'), start}
		} else if is_identifier_char(cs[i], false) {
			for i < cs.len && is_identifier_char(cs[i], true) {
				i++
			}
			tokens << ModuleToken{.word, cs[start..i].string(), start}
		} else if cs[i] >= `0` && cs[i] <= `9` {
			for i < cs.len && cs[i] >= `0` && cs[i] <= `9` {
				i++
			}
			tokens << ModuleToken{.number, cs[start..i].string(), start}
		} else {
			if cs[i].str().trim_space() != '' {
				tokens << ModuleToken{.other, cs[i].str(), start}
			}
			i++
		}
	}

	return ModuleTokens{
		tokens: tokens
	}
}

// next_word is the next token as an upper case word, or the character for
// another token. It's empty at the end, or for an identifier or literal.
fn (mut t ModuleTokens) next_word() string {
	t.pos++
	if t.pos > t.tokens.len {
		return ''
	}

	tok := t.tokens[t.pos - 1]
	return match tok.kind {
		.word { tok.text.to_upper() }
		.other { tok.text }
		else { '' }
	}
}

// accept reads the next token if it's word.
fn (mut t ModuleTokens) accept(word string) bool {
	if t.next_word() == word {
		return true
	}
	t.pos--

	return false
}

fn (mut t ModuleTokens) expect(word string) ! {
	if !t.accept(word) {
		return sqlstate_42601('expected ${word}${t.near()}')
	}
}

// peek is the next token, if there is one.
fn (t ModuleTokens) peek() ?ModuleToken {
	if t.pos < t.tokens.len {
		return t.tokens[t.pos]
	}

	return none
}

// near describes where the next token is, for an error message.
fn (t ModuleTokens) near() string {
	tok := t.peek() or { return ' at the end' }

	return ' near ${tok.text}'
}

// identifier reads an <identifier>, which is delimited ("Name") or upper case
// (name is NAME).
fn (mut t ModuleTokens) identifier(what string) !string {
	if tok := t.peek() {
		if tok.kind == .delimited {
			t.pos++
			return tok.text
		}
	}

	return t.c_name(what)!.to_upper()
}

// c_name reads an <identifier> that is also used as a C name, so it must be a
// regular identifier. It's kept as it was written.
fn (mut t ModuleTokens) c_name(what string) !string {
	if tok := t.peek() {
		if tok.kind == .word {
			t.pos++
			return tok.text
		}
	}

	return sqlstate_42601('expected ${what}${t.near()}')
}

// length reads an <unsigned integer> for the length of a string.
fn (mut t ModuleTokens) length() !int {
	if tok := t.peek() {
		if tok.kind == .number && tok.text.int() > 0 {
			t.pos++
			return tok.text.int()
		}
	}

	return sqlstate_42601('expected a length${t.near()}')
}
