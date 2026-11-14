module vsql

// ISO/IEC 9075-2:2023, 6.29, <value expression>
//
// Specify a value.

type ValueExpression = BooleanValueExpression | CommonValueExpression

fn (e ValueExpression) pstr(params map[string]Value) string {
	return match e {
		CommonValueExpression, BooleanValueExpression {
			e.pstr(params)
		}
	}
}

fn (e ValueExpression) compile(mut c Compiler) !CompileResult {
	match e {
		CommonValueExpression, BooleanValueExpression {
			return e.compile(mut c)!
		}
	}
}

type CommonValueExpression = CharacterValueExpression | DatetimePrimary | NumericValueExpression

fn (e CommonValueExpression) pstr(params map[string]Value) string {
	return match e {
		NumericValueExpression, CharacterValueExpression, DatetimePrimary {
			e.pstr(params)
		}
	}
}

fn (e CommonValueExpression) compile(mut c Compiler) !CompileResult {
	match e {
		NumericValueExpression, CharacterValueExpression, DatetimePrimary {
			return e.compile(mut c)!
		}
	}
}
