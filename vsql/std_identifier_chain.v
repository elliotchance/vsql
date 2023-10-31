// ISO/IEC 9075-2:2016(E), 6.6, <identifier chain>

module vsql

// Format
//~
//~ <identifier chain> /* IdentifierChain */ ::=
//~     <identifier>
//~   | <identifier> <period> <identifier>   -> identifier_chain
//~
//~ <basic identifier chain> /* IdentifierChain */ ::=
//~     <identifier chain>

// IdentifierChain wraps a single string that contains the chain of one or more
// identifiers, such as: "Foo".bar."BAZ"
struct IdentifierChain {
	identifier string
}

fn (identifier IdentifierChain) str() string {
	return identifier.identifier
}

fn parse_identifier_chain(a IdentifierChain, b IdentifierChain) !IdentifierChain {
	return IdentifierChain{a.identifier + '.' + b.identifier}
}
