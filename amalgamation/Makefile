# Builds vsql (the command line program) and libvsql (the SQL/CLI shared
# library, see libvsql.h) from C, so V isn't needed. It works on Linux, macOS
# and Windows (with MinGW). CC, CFLAGS and LDFLAGS can be set as usual.
#
#   make            Builds bin/vsql and the library (bin/libvsql.so, .dylib or
#                   .dll).
#   make vsql       Builds bin/vsql.
#   make libvsql    Builds the library.
#   make example    Builds and runs example.c with the library.
#   make clean      Removes bin/.
#
# vsql.c and libvsql.c have the C in one file each (see
# scripts/amalgamation-merge.py), so they can also be built without this
# Makefile, such as with "cc -std=gnu11 -fwrapv -w -O2 vsql.c -o vsql" and the
# options for the OS and architecture in vsql.mk, which has the libraries and
# linker options that V uses on each OS and architecture.
#
# In the release (vsql-VERSION-amalgamation.zip) they have the C for every OS
# and architecture. In vsql's source, "make amalgamation" puts the rest of the
# files next to this Makefile (in amalgamation/), with the C for just the
# current one, and vsql's Makefile builds its binaries with it.

ifeq ($(OS),Windows_NT)
VSQL_OS = windows
VSQL = bin/vsql.exe
LIBVSQL = bin/libvsql.dll
EXAMPLE = bin/example.exe
# The library is built with MinGW, so cc may not exist. libgcc is linked
# statically, so that the DLL doesn't need the MinGW runtime, and libvsql.def
# gives the DLL its name. Windows has no rpath, a program finds the DLL in its
# own folder or on the PATH. Programs link against the import library
# (bin/libvsql.dll.a, which -lvsql finds before the DLL).
ifeq ($(origin CC),default)
CC = gcc
endif
LIBVSQL_SHARED = -shared -static-libgcc -Wl,--export-all-symbols -Wl,--out-implib,bin/libvsql.dll.a libvsql.def
else ifeq ($(shell uname -s),Darwin)
VSQL_OS = macos
VSQL = bin/vsql
LIBVSQL = bin/libvsql.dylib
EXAMPLE = bin/example
# Only the SQL/CLI routines are exported. The install name lets programs find
# the library by rpath.
LIBVSQL_SHARED = -shared -fPIC -Wl,-install_name,@rpath/libvsql.dylib -Wl,-exported_symbols_list,libvsql.exports
RPATH = -Wl,-rpath,$(CURDIR)/bin
else
VSQL_OS = linux
VSQL = bin/vsql
LIBVSQL = bin/libvsql.so
EXAMPLE = bin/example
# Only the SQL/CLI routines are exported.
LIBVSQL_SHARED = -shared -fPIC -Wl,-soname,libvsql.so -Wl,--version-script,libvsql.map
RPATH = -Wl,-rpath,$(CURDIR)/bin
endif

# The architecture is the one that the C compiler builds for.
VSQL_MACHINE := $(shell $(CC) -dumpmachine)
ifneq ($(filter x86_64% amd64%,$(VSQL_MACHINE)),)
VSQL_ARCH = amd64
else ifneq ($(filter aarch64% arm64%,$(VSQL_MACHINE)),)
VSQL_ARCH = arm64
else
$(error There is no generated C for $(VSQL_MACHINE).)
endif

include vsql.mk

CFLAGS ?= -O2

# V generates C that relies on wrapping signed overflow and causes many
# warnings.
VSQL_CFLAGS = -std=gnu11 -fwrapv -w

.PHONY: all vsql libvsql example clean

all: vsql libvsql

vsql: $(VSQL)

libvsql: $(LIBVSQL)

$(VSQL): vsql.c
	mkdir -p bin
	$(CC) $(VSQL_CFLAGS) $(CFLAGS) vsql.c -o $@ $(LDFLAGS) $(VSQL_FLAGS)

$(LIBVSQL): libvsql.c
	mkdir -p bin
	$(CC) $(VSQL_CFLAGS) $(CFLAGS) $(LIBVSQL_SHARED) libvsql.c -o $@ $(LDFLAGS) $(LIBVSQL_FLAGS)

example: $(LIBVSQL)
	$(CC) $(CFLAGS) example.c -I. -Lbin -lvsql $(RPATH) -o $(EXAMPLE)
	$(EXAMPLE)

clean:
	rm -rf bin
