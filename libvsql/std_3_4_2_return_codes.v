module main

// ISO/IEC 9075-3:2003(E), 4.2, Return codes
//
// Every CLI routine returns one of these codes. When more than one applies, the
// later one in this list is returned. An error is returned as soon as it
// happens, otherwise any warning makes it SQL_SUCCESS_WITH_INFO (see
// Diagnostics.result).

const sql_success = i16(0)
const sql_success_with_info = i16(1)
const sql_need_data = i16(99)
const sql_no_data = i16(100)
const sql_error = i16(-1)
const sql_invalid_handle = i16(-2)
