// V's helpers include <gc.h>. This replaces the gc.h that comes with V, which
// also defines a fallback GC_noop1_ptr (without an include guard) that clashes
// with the one in gc.c, since they're compiled together in vsql_runtime.c.
#include "gc/gc.h"
