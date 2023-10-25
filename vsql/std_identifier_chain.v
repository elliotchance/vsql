// ISO/IEC 9075-2:2016(E), 6.6, <identifier chain>

module vsql

// Format
//~
//~ <identifier chain> /* IdentifierChain */ ::=
//~     <identifier>
//~   | <identifier> <period> <identifier>   -> identifier_chain1
//~
//~ <basic identifier chain> /* IdentifierChain */ ::=
//~     <identifier chain>

fn parse_identifier_chain1(a IdentifierChain, b IdentifierChain) !IdentifierChain {
	return IdentifierChain{a.identifier + '.' + b.identifier}
}
