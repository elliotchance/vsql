// vsql_runtime.c is the C that V links into vsql and libvsql from outside of
// the generated C: the Boehm garbage collector (gc.c) and V's own helpers.
//
// It's compiled separately from vsql.c and libvsql.c, since V declares parts
// of the garbage collector API itself, with different types to gc.h.
#if defined(_WIN32)
#include "vsql_runtime_windows.c"
#elif defined(__APPLE__)
#include "vsql_runtime_macos.c"
#elif defined(__linux__)
#include "vsql_runtime_linux.c"
#else
#error "There is no generated C for this OS."
#endif
