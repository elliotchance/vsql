%%

// ISO/IEC 9075-2:2016(E), 5.1, <SQL terminal character>
//
// Define the terminal symbols of the SQL language and the elements of strings.

left_paren: OPERATOR_LEFT_PAREN

right_paren: OPERATOR_RIGHT_PAREN

asterisk: OPERATOR_ASTERISK { $$.v = $1.v as string }

plus_sign: OPERATOR_PLUS { $$.v = $1.v as string }

comma: OPERATOR_COMMA

minus_sign: OPERATOR_MINUS { $$.v = $1.v as string }

period: OPERATOR_PERIOD

solidus: OPERATOR_SOLIDUS { $$.v = $1.v as string }

colon: OPERATOR_COLON

less_than_operator: OPERATOR_LESS_THAN

equals_operator: OPERATOR_EQUALS

greater_than_operator: OPERATOR_GREATER_THAN

%%
