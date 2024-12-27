module vsql

// ISO/IEC 9075-2:2016(E), 6.6, <identifier chain>
//
// Disambiguate a <period>-separated chain of identifiers.

// IdentifierChain wraps a single string that contains the chain of one or more
// identifiers, such as: "Foo".bar."BAZ"
struct IdentifierChain {
	identifier string
}

fn (identifier IdentifierChain) str() string {
	return identifier.identifier
}
