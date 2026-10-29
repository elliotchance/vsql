module main

import os
import sync
import vsql

// libvsql can be called from any thread, including threads that weren't created
// by V (such as the threads of a Go program).
//
// Each SQL-environment is an SQL-agent (see 5.3, "Implicit set connection"),
// which runs one routine at a time: a routine locks the mutex of the
// SQL-environment of its handle. The handles (envs, dbcs, stmts and descs) are
// shared by every SQL-environment, so they're protected by the registry mutex,
// which a routine also holds, except while it waits for the database (see
// unlocked). So a routine of one SQL-environment can wait for a lock that's held
// by a transaction in another SQL-environment, which can still commit.
//
// A routine that's called by another routine (such as SQLAllocEnv calling
// SQLAllocHandle) already holds the mutexes, so it doesn't lock them again.
//
// The GC must know about every thread that has V memory on its stack, so a
// thread that isn't registered with the GC is registered for the duration of
// the routine.

__global registry = sync.new_mutex()

// registry_owner is the thread that holds the registry mutex, or 0. It's only
// compared to the current thread, which is the only thread that can set it to
// its own ID.
__global registry_owner = u64(0)

// The database files that are open, and the mutex that every connection to the
// same file must share (see vsql.ConnectionOptions).
__global file_mutexes = map[string]&sync.RwMutex{}

// Entry is a routine that's been entered with enter, and must be left with
// leave.
struct Entry {
	env        ?&Env
	outer      bool
	registered bool
}

// enter must be called (and leave deferred) at the start of each routine, with
// the handle that identifies the SQL-environment. A handle that isn't allocated
// doesn't lock an SQL-environment, but it still locks the registry. Nothing
// before it may allocate memory, since the thread may not be registered with
// the GC yet.
fn enter(handle_type i16, h i64) Entry {
	registered := register_thread()
	if registry_owner == sync.thread_id() {
		return Entry{
			registered: registered
		}
	}

	registry.lock()
	mut env := envs[handle_env(handle_type, h)] or { unsafe { nil } }
	registry.unlock()
	if env != unsafe { nil } {
		env.mutex.lock()
	}
	registry.lock()
	registry_owner = sync.thread_id()

	return Entry{
		env:        if env == unsafe { nil } { none } else { env }
		outer:      true
		registered: registered
	}
}

// alloc_input_type is the type of the InputHandle of AllocHandle, or 0 if it
// isn't used.
fn alloc_input_type(handle_type i16) i16 {
	return match handle_type {
		sql_handle_dbc { sql_handle_env }
		sql_handle_stmt, sql_handle_desc { sql_handle_dbc }
		else { 0 }
	}
}

// error_handle_type and error_handle are the handle that Error uses.
fn error_handle_type(connection_handle SQLInteger, statement_handle SQLInteger) i16 {
	return if statement_handle != 0 {
		sql_handle_stmt
	} else if connection_handle != 0 {
		sql_handle_dbc
	} else {
		sql_handle_env
	}
}

fn error_handle(environment_handle SQLInteger, connection_handle SQLInteger, statement_handle SQLInteger) i64 {
	return i64(if statement_handle != 0 {
		statement_handle
	} else if connection_handle != 0 {
		connection_handle
	} else {
		environment_handle
	})
}

fn (e Entry) leave() {
	if e.outer {
		registry_owner = 0
		registry.unlock()
		if env := e.env {
			env.mutex.unlock()
		}
	}
	unregister_thread(e.registered)
}

// register_thread registers the current thread with the GC, if it isn't
// already, and returns true if it did. GC_register_my_thread returns
// GC_SUCCESS (0) if it registered the thread, or GC_DUPLICATE if the thread was
// already registered.
fn register_thread() bool {
	$if gcboehm ? {
		sb := C.GC_stack_base{}
		if C.GC_get_stack_base(&sb) == 0 {
			return C.GC_register_my_thread(&sb) == 0
		}
	}

	return false
}

fn unregister_thread(registered bool) {
	$if gcboehm ? {
		if registered {
			C.GC_unregister_my_thread()
		}
	}
}

// release unlocks the registry while the database is used, and returns true
// if it did. The routine must call reacquire with it before it uses a handle
// again.
fn release() bool {
	if registry_owner != sync.thread_id() {
		return false
	}
	registry_owner = 0
	registry.unlock()

	return true
}

fn reacquire(released bool) {
	if released {
		registry.lock()
		registry_owner = sync.thread_id()
	}
}

// The database operations that may wait (such as for a lock), which unlock the
// registry while they run.

fn db_open(path string) !&vsql.Connection {
	mut options := vsql.default_connection_options()
	if path != ':memory:' {
		// The same file may have different paths, such as through a symbolic
		// link. The file may not exist yet, but its folder should.
		abs := os.abs_path(path)
		key := os.join_path(os.real_path(os.dir(abs)), os.base(abs))
		options.mutex = file_mutexes[key] or {
			mutex := sync.new_rwmutex()
			file_mutexes[key] = mutex
			mutex
		}
	}
	released := release()
	defer {
		reacquire(released)
	}

	return vsql.open_database(path, options)
}

fn db_query(mut conn vsql.Connection, text string) !vsql.Result {
	released := release()
	defer {
		reacquire(released)
	}

	return conn.query(text)
}

fn db_prepare(mut conn vsql.Connection, text string) !vsql.PreparedStmt {
	released := release()
	defer {
		reacquire(released)
	}

	return conn.prepare(text)
}

fn db_run(mut prepared vsql.PreparedStmt, params map[string]vsql.Value) !vsql.Result {
	released := release()
	defer {
		reacquire(released)
	}

	return prepared.query(params)
}

fn db_close(mut conn vsql.Connection) {
	released := release()
	defer {
		reacquire(released)
	}

	conn.close()
}
