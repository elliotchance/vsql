// testing_crash_windows.h reports a crash of a test process on Windows with
// more detail than V does, see install_sql_test_crash_report in
// testing_d_vsqltest.v. V only prints the code and address of the exception,
// and can't print a backtrace on Windows without debug information.

#include <windows.h>
#include <stdio.h>
#include <string.h>

static DWORD vsql_test_main_thread;
static char vsql_test_location[1024] = "(no test has started)";

// vsql_test_set_location remembers the test that is running, which is printed if
// the process crashes.
static void vsql_test_set_location(const char *location) {
	strncpy(vsql_test_location, location, sizeof(vsql_test_location) - 1);
	vsql_test_location[sizeof(vsql_test_location) - 1] = 0;
}

// vsql_test_print_address prints an address as the module that it's in and the
// offset into it, which is the same between runs.
static void vsql_test_print_address(const char *prefix, DWORD64 address) {
	HMODULE module = NULL;
	char name[MAX_PATH] = "?";
	if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
			GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)address, &module)) {
		GetModuleFileNameA(module, name, MAX_PATH);
	}
	const char *base = strrchr(name, '\\');
	fprintf(stderr, "%s%s+0x%llx (0x%llx)\n", prefix, base ? base + 1 : name,
		(unsigned long long)(address - (DWORD64)module), (unsigned long long)address);
}

static LONG WINAPI vsql_test_crash_filter(EXCEPTION_POINTERS *e) {
	EXCEPTION_RECORD *record = e->ExceptionRecord;
	DWORD thread = GetCurrentThreadId();
	fprintf(stderr, "\nCRASH: exception 0x%lx in %s thread %lu while running %s\n",
		(unsigned long)record->ExceptionCode,
		thread == vsql_test_main_thread ? "the main" : "another", (unsigned long)thread,
		vsql_test_location);
	if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && record->NumberParameters >= 2) {
		const char *op = record->ExceptionInformation[0] == 0 ? "reading"
			: record->ExceptionInformation[0] == 1 ? "writing" : "executing";
		fprintf(stderr, "CRASH: %s address 0x%llx\n", op,
			(unsigned long long)record->ExceptionInformation[1]);
	}

	// Walk the stack of the thread that crashed, from where it crashed. Code
	// built by gcc for x86-64 has the unwind information this needs.
#if defined(_M_X64) || defined(__x86_64__)
	CONTEXT context = *e->ContextRecord;
	for (int i = 0; i < 40 && context.Rip != 0; i++) {
		char prefix[32];
		snprintf(prefix, sizeof(prefix), "CRASH:   #%d ", i);
		vsql_test_print_address(prefix, context.Rip);
		DWORD64 image_base = 0;
		RUNTIME_FUNCTION *function = RtlLookupFunctionEntry(context.Rip, &image_base, NULL);
		if (function == NULL) {
			// A leaf function, which hasn't moved the stack pointer.
			context.Rip = *(DWORD64 *)context.Rsp;
			context.Rsp += 8;
		} else {
			void *handler_data = NULL;
			DWORD64 establisher_frame = 0;
			RtlVirtualUnwind(0 /* UNW_FLAG_NHANDLER */, image_base, context.Rip, function,
				&context, &handler_data, &establisher_frame, NULL);
		}
	}
#else
	vsql_test_print_address("CRASH:   at ", (DWORD64)record->ExceptionAddress);
#endif
	fflush(stderr);

	return EXCEPTION_CONTINUE_SEARCH;
}

// vsql_test_install_crash_report replaces V's handler of a crash (see
// add_unhandled_exception_handler in V's builtin).
static void vsql_test_install_crash_report(void) {
	vsql_test_main_thread = GetCurrentThreadId();
	SetUnhandledExceptionFilter(vsql_test_crash_filter);
}
