module main

// ISO/IEC 9075-3:2003(E), 6.37, GetFunctions
//
// Determine whether a CLI routine is supported.

// Codes from Table 27, "Codes used to identify SQL/CLI routines".
const sql_api_sqlallocconnect = 1
const sql_api_sqlallocenv = 2
const sql_api_sqlallochandle = 1001
const sql_api_sqlallocstmt = 3
const sql_api_sqlbindcol = 4
const sql_api_sqlbindparameter = 72
const sql_api_sqlcancel = 5
const sql_api_sqlclosecursor = 1003
const sql_api_sqlcolattribute = 6
const sql_api_sqlcolumnprivileges = 56
const sql_api_sqlcolumns = 40
const sql_api_sqlconnect = 7
const sql_api_sqlcopydesc = 1004
const sql_api_sqldatasources = 57
const sql_api_sqldescribecol = 8
const sql_api_sqldisconnect = 9
const sql_api_sqlendtran = 1005
const sql_api_sqlerror = 10
const sql_api_sqlexecdirect = 11
const sql_api_sqlexecute = 12
const sql_api_sqlfetch = 13
const sql_api_sqlfetchscroll = 1021
const sql_api_sqlforeignkeys = 60
const sql_api_sqlfreeconnect = 14
const sql_api_sqlfreeenv = 15
const sql_api_sqlfreehandle = 1006
const sql_api_sqlfreestmt = 16
const sql_api_sqlgetconnectattr = 1007
const sql_api_sqlgetcursorname = 17
const sql_api_sqlgetdata = 43
const sql_api_sqlgetdescfield = 1008
const sql_api_sqlgetdescrec = 1009
const sql_api_sqlgetdiagfield = 1010
const sql_api_sqlgetdiagrec = 1011
const sql_api_sqlgetenvattr = 1012
const sql_api_sqlgetfeatureinfo = 1027
const sql_api_sqlgetfunctions = 44
const sql_api_sqlgetinfo = 45
const sql_api_sqlgetlength = 1022
const sql_api_sqlgetparamdata = 1025
const sql_api_sqlgetposition = 1023
const sql_api_sqlgetsessioninfo = 1028
const sql_api_sqlgetstmtattr = 1014
const sql_api_sqlgetsubstring = 1024
const sql_api_sqlgettypeinfo = 47
const sql_api_sqlmoreresults = 61
const sql_api_sqlnextresult = 73
const sql_api_sqlnumresultcols = 18
const sql_api_sqlparamdata = 48
const sql_api_sqlprepare = 19
const sql_api_sqlprimarykeys = 65
const sql_api_sqlputdata = 49
const sql_api_sqlrowcount = 20
const sql_api_sqlsetconnectattr = 1016
const sql_api_sqlsetcursorname = 21
const sql_api_sqlsetdescfield = 1017
const sql_api_sqlsetdescrec = 1018
const sql_api_sqlsetenvattr = 1019
const sql_api_sqlsetstmtattr = 1020
const sql_api_sqlspecialcolumns = 52
const sql_api_sqlstarttran = 74
const sql_api_sqltableprivileges = 70
const sql_api_sqltables = 54

// The supported routines are true.
const cli_routines = {
	sql_api_sqlallocconnect:     true
	sql_api_sqlallocenv:         true
	sql_api_sqlallochandle:      true
	sql_api_sqlallocstmt:        true
	sql_api_sqlbindcol:          true
	sql_api_sqlbindparameter:    true
	sql_api_sqlcancel:           true
	sql_api_sqlclosecursor:      true
	sql_api_sqlcolattribute:     true
	sql_api_sqlcolumnprivileges: false
	sql_api_sqlcolumns:          true
	sql_api_sqlconnect:          true
	sql_api_sqlcopydesc:         true
	sql_api_sqldatasources:      true
	sql_api_sqldescribecol:      true
	sql_api_sqldisconnect:       true
	sql_api_sqlendtran:          true
	sql_api_sqlerror:            true
	sql_api_sqlexecdirect:       true
	sql_api_sqlexecute:          true
	sql_api_sqlfetch:            true
	sql_api_sqlfetchscroll:      true
	sql_api_sqlforeignkeys:      true
	sql_api_sqlfreeconnect:      true
	sql_api_sqlfreeenv:          true
	sql_api_sqlfreehandle:       true
	sql_api_sqlfreestmt:         true
	sql_api_sqlgetconnectattr:   true
	sql_api_sqlgetcursorname:    true
	sql_api_sqlgetdata:          true
	sql_api_sqlgetdescfield:     true
	sql_api_sqlgetdescrec:       true
	sql_api_sqlgetdiagfield:     true
	sql_api_sqlgetdiagrec:       true
	sql_api_sqlgetenvattr:       true
	sql_api_sqlgetfeatureinfo:   true
	sql_api_sqlgetfunctions:     true
	sql_api_sqlgetinfo:          true
	sql_api_sqlgetlength:        false
	sql_api_sqlgetparamdata:     false
	sql_api_sqlgetposition:      false
	sql_api_sqlgetsessioninfo:   false
	sql_api_sqlgetstmtattr:      true
	sql_api_sqlgetsubstring:     false
	sql_api_sqlgettypeinfo:      true
	sql_api_sqlmoreresults:      true
	sql_api_sqlnextresult:       true
	sql_api_sqlnumresultcols:    true
	sql_api_sqlparamdata:        true
	sql_api_sqlprepare:          true
	sql_api_sqlprimarykeys:      true
	sql_api_sqlputdata:          true
	sql_api_sqlrowcount:         true
	sql_api_sqlsetconnectattr:   true
	sql_api_sqlsetcursorname:    true
	sql_api_sqlsetdescfield:     true
	sql_api_sqlsetdescrec:       true
	sql_api_sqlsetenvattr:       true
	sql_api_sqlsetstmtattr:      true
	sql_api_sqlspecialcolumns:   true
	sql_api_sqlstarttran:        true
	sql_api_sqltableprivileges:  false
	sql_api_sqltables:           true
}

@[export: 'SQLGetFunctions']
fn sql_get_functions(connection_handle SQLInteger, function_id i16, supported &i16) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.37, GetFunctions, General Rules, 1
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	// ISO/IEC 9075-3:2003(E), 6.37, GetFunctions, General Rules, 2: the
	// connection must be established.
	if dbc.conn == none {
		return dbc.diag.error(cli_error('08003', 'connection does not exist'))
	}

	// ISO/IEC 9075-3:2003(E), 6.37, GetFunctions, General Rules, 3
	implicit_set_connection(i64(connection_handle)) or { return dbc.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.37, GetFunctions, General Rules, 4 and 5: the
	// FunctionId must be one of the codes in Table 27 (cli_routines).
	is_supported := cli_routines[int(function_id)] or {
		return dbc.diag.error(cli_error('HY095', 'invalid FunctionId specified'))
	}

	// ISO/IEC 9075-3:2003(E), 4.4.3, Null pointers
	if supported == unsafe { nil } {
		return dbc.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// ISO/IEC 9075-3:2003(E), 6.37, GetFunctions, General Rules, 6
	unsafe {
		*supported = if is_supported { 1 } else { 0 }
	}

	return sql_success
}
