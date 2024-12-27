module vsql

// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>
//
// Specify a list of updates.

type UpdateSource = NullSpecification | ValueExpression

fn (e UpdateSource) pstr(params map[string]Value) string {
	return match e {
		ValueExpression, NullSpecification {
			e.pstr(params)
		}
	}
}

fn (e UpdateSource) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, NullSpecification {
			return e.compile(mut c)!
		}
	}
}
