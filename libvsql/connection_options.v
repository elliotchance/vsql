module main

import time
import vsql

// The connection attributes for vsql.ConnectionOptions, which aren't in the
// standard. Each is an SQLINTEGER. They're the options that SQLConnect opens
// the connection with, so they can only be set while the connection isn't
// established: CLI-specific condition — attribute cannot be set now.
//
// LOCK_TIMEOUT and CREATE_INDEX_TIMEOUT are in milliseconds. ISOLATION_LEVEL
// is the isolation level of a transaction that doesn't have one from
// SQLStartTran, START TRANSACTION or SET TRANSACTION, as one of the
// SQLStartTran IsolationLevels. CACHE_SIZE is in pages, and PAGE_SIZE in
// octets (only used for :memory: and new files). FULL_FSYNC is SQL_TRUE or
// SQL_FALSE.
const sql_attr_vsql_lock_timeout = 11100
const sql_attr_vsql_create_index_timeout = 11101
const sql_attr_vsql_isolation_level = 11102
const sql_attr_vsql_cache_size = 11103
const sql_attr_vsql_page_size = 11104
const sql_attr_vsql_full_fsync = 11105

fn is_connection_option(attribute SQLInteger) bool {
	return attribute in [SQLInteger(sql_attr_vsql_lock_timeout), sql_attr_vsql_create_index_timeout,
		sql_attr_vsql_isolation_level, sql_attr_vsql_cache_size, sql_attr_vsql_page_size,
		sql_attr_vsql_full_fsync]
}

// set_connection_option sets one of the connection options. A value that
// isn't valid is a CLI-specific condition — invalid attribute value.
fn set_connection_option(mut dbc Dbc, attribute SQLInteger, value voidptr) ! {
	if dbc.conn != none {
		return cli_error('HY011', 'attribute cannot be set now')
	}
	v := read_integer(value)!
	invalid := cli_error('HY024', 'invalid attribute value')
	match attribute {
		sql_attr_vsql_lock_timeout {
			if v < 0 {
				return invalid
			}
			dbc.options.lock_timeout = v * time.millisecond
		}
		sql_attr_vsql_create_index_timeout {
			if v < 0 {
				return invalid
			}
			dbc.options.create_index_timeout = v * time.millisecond
		}
		sql_attr_vsql_isolation_level {
			dbc.options.isolation_level = match v {
				sql_transaction_read_uncommitted { vsql.IsolationLevel.read_uncommitted }
				sql_transaction_read_committed { vsql.IsolationLevel.read_committed }
				sql_transaction_repeatable_read { vsql.IsolationLevel.repeatable_read }
				sql_transaction_serializable { vsql.IsolationLevel.serializable }
				else { return invalid }
			}
		}
		sql_attr_vsql_cache_size {
			if v < 0 {
				return invalid
			}
			dbc.options.cache_size = int(v)
		}
		sql_attr_vsql_page_size {
			// See vsql.ConnectionOptions.page_size.
			if v <= 16 || v > 65535 {
				return invalid
			}
			dbc.options.page_size = int(v)
		}
		else {
			if v !in [i64(sql_false), sql_true] {
				return invalid
			}
			dbc.options.full_fsync = v == sql_true
		}
	}
}

// connection_option is the value of one of the connection options.
fn connection_option(dbc &Dbc, attribute SQLInteger) i64 {
	return match attribute {
		sql_attr_vsql_lock_timeout {
			dbc.options.lock_timeout / time.millisecond
		}
		sql_attr_vsql_create_index_timeout {
			dbc.options.create_index_timeout / time.millisecond
		}
		sql_attr_vsql_isolation_level {
			match dbc.options.isolation_level {
				.read_uncommitted { i64(sql_transaction_read_uncommitted) }
				.read_committed { sql_transaction_read_committed }
				.repeatable_read { sql_transaction_repeatable_read }
				.serializable { sql_transaction_serializable }
			}
		}
		sql_attr_vsql_cache_size {
			dbc.options.cache_size
		}
		sql_attr_vsql_page_size {
			dbc.options.page_size
		}
		else {
			if dbc.options.full_fsync { sql_true } else { sql_false }
		}
	}
}
