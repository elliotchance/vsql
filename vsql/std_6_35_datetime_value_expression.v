module vsql

// ISO/IEC 9075-2:2016(E), 6.35, <datetime value expression>
//
// Specify a datetime value.

type DatetimePrimary = DatetimeValueFunction | ValueExpressionPrimary

fn (e DatetimePrimary) pstr(params map[string]Value) string {
	return match e {
		ValueExpressionPrimary, DatetimeValueFunction {
			e.pstr(params)
		}
	}
}

fn (e DatetimePrimary) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpressionPrimary, DatetimeValueFunction {
			return e.compile(mut c)!
		}
	}
}
