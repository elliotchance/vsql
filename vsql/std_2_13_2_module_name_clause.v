module vsql

// ISO/IEC 9075-2:2016(E), 13.2, <module name clause>
//
// Name an SQL-client module.

// module_name_clause reads MODULE and the optional <SQL-client module name>.
// The name isn't used, since the C functions are named after the procedures.
// A <module character set specification> (NAMES ARE) needs Feature F461,
// "Named character sets".
fn (mut t ModuleTokens) module_name_clause() ! {
	t.expect('MODULE')!
	if tok := t.peek() {
		if tok.kind == .delimited || tok.text.to_upper() != 'LANGUAGE' {
			t.identifier('SQL-client module name')!
		}
	}
}
