.PHONY: libvsql libvsql-example libvsql-test module-example module-test release bench bench-on-disk bench-memory fmt fmt-verify test unit-test btree-test cli-test examples-test clean-grammar grammar sql-test sql-test-uncovered vorm-test vorm-test-uncovered docs clean-docs oldv

# Is not used at the moment. It is useful for testing options like different
# `-gc` values.
BUILD_OPTIONS =

PROD = -prod

# OLDV let's you specify a differnt V version rather than the default one. This
# is important for testing V language changes or legacy performance tests. It is
# documented in testing.rst.
ifdef OLDV
V_DIR := $(shell dirname `which v`)
V := "/tmp/oldv/v_at_$(OLDV)/v"
else
V := $(shell which v)

# -n hides the notices, which are thousands of lines. V3's module cache makes it
# compile vsql three times (55s rather than 17s), so it's turned off.
V3_OPTIONS = -n -nocache
endif

# Ready is a some quick tasks that can easily be forgotten when preparing a
# diff.

ready: grammar fmt snippets

# Binaries

# The binaries are rebuilt when any of the source files change.
SOURCES = vsql/y.v $(wildcard vsql/*.v vsql/*.c cmd/vsql-cli/*.v)

bin/vsql: $(SOURCES)
	mkdir -p bin
	v $(V3_OPTIONS) $(BUILD_OPTIONS) $(PROD) cmd/vsql-cli -o bin/vsql

bin/vsql.exe: $(SOURCES)
	mkdir -p bin
	v $(V3_OPTIONS) -os windows $(BUILD_OPTIONS) $(PROD) cmd/vsql-cli -o bin/vsql.exe

# libvsql is the SQL/CLI (ISO/IEC 9075-3) shared library, see
# libvsql/libvsql.h. On macOS the install name must be set so that programs can
# find it by rpath. Windows has no rpath (a program finds the DLL in its own
# folder or on the PATH), and it's built with MinGW, since that's what CI has.
# libgcc is linked statically so that the DLL doesn't need the MinGW runtime,
# and libvsql.def gives the DLL its name.
ifeq ($(OS),Windows_NT)
LIBVSQL = bin/libvsql.dll
LIBVSQL_OPTIONS = -cc gcc -ldflags '-static-libgcc -Wl,--export-all-symbols $(CURDIR)/libvsql/libvsql.def'
LIBVSQL_C = gcc
LIBVSQL_CPP = g++
else ifeq ($(shell uname),Darwin)
LIBVSQL = bin/libvsql.dylib
LIBVSQL_OPTIONS = -ldflags '-Wl,-install_name,@rpath/libvsql.dylib'
LIBVSQL_RPATH = -Wl,-rpath,$(CURDIR)/bin
else
LIBVSQL = bin/libvsql.so
LIBVSQL_RPATH = -Wl,-rpath,$(CURDIR)/bin
endif
LIBVSQL_C ?= cc
LIBVSQL_CPP ?= c++
# The tests use POSIX threads, except on Windows.
ifneq ($(OS),Windows_NT)
LIBVSQL_PTHREAD = -pthread
endif

libvsql: $(LIBVSQL)

$(LIBVSQL): $(SOURCES) $(wildcard libvsql/*.v)
	mkdir -p bin
	v $(V3_OPTIONS) $(BUILD_OPTIONS) $(PROD) -enable-globals -shared $(LIBVSQL_OPTIONS) libvsql -o bin/libvsql

# The release is a zip of a folder named after the release (VERSION, such as
# v0.34.0), OS and architecture, so that versions can be unzipped side by side:
#
#   vsql-v0.34.0-macos-arm64/bin/vsql
#   vsql-v0.34.0-macos-arm64/include/libvsql.h
#   vsql-v0.34.0-macos-arm64/lib/libvsql.dylib (libvsql.so on Linux)
#   vsql-v0.34.0-macos-arm64/example.c
#
# bin/, include/ and lib/ are the usual layout of an install prefix (such as
# /usr/local), so the folder can be used as one.
VERSION ?= dev
RELEASE = vsql-$(VERSION)-$(if $(filter Darwin,$(shell uname)),macos,linux)-$(if $(filter arm64 aarch64,$(shell uname -m)),arm64,x86-64)

release: bin/vsql $(LIBVSQL)
	rm -rf $(RELEASE) $(RELEASE).zip
	mkdir -p $(RELEASE)/bin $(RELEASE)/include $(RELEASE)/lib
	cp bin/vsql $(RELEASE)/bin/
	cp libvsql/libvsql.h $(RELEASE)/include/
	cp $(LIBVSQL) $(RELEASE)/lib/
	cp libvsql/example.c $(RELEASE)/
	zip -r $(RELEASE).zip $(RELEASE)
	rm -rf $(RELEASE)

oldv: vsql/y.v
ifdef OLDV
	@mkdir -p /tmp/oldv/
	@# VJOBS and VFLAGS needs to be provided for macOS. I'm not sure if they also
	@# have to be removed for linux.
	cd $(V_DIR) && VJOBS=1 VFLAGS='-no-parallel' cmd/tools/oldv $(OLDV) -w /tmp/oldv/
	@# Print out the version to make sure the V build was successful.
	$(V) version
endif

# Documentation

snippets:
	v -path '$(shell dirname `realpath $(V)`)/cmd/tools/vdoc|@vlib|@vmodules' run scripts/generate-v-client-library-docs.vsh > docs/v-client-library-docs.rst

docs: snippets
	mkdir -p docs/_static
	cd docs && make html SPHINXOPTS="-W --keep-going -n"

clean-docs:
	cd docs && make clean

# Grammar

# vsql/y.v is committed so that the module works after "v install". vsql/y.y is
# only an intermediate file, made by joining the other vsql/*.y files.
vsql/y.y: $(filter-out vsql/y.y,$(wildcard vsql/*.y))
	./scripts/generate-grammar.vsh

# v fmt has to run twice because the first pass leaves some of the long arrays
# in a state that it would format differently again.
vsql/y.v: vsql/y.y
	v run scripts/vyacc.v -o vsql/y.v vsql/y.y
	v fmt -w vsql/y.v
	v fmt -w vsql/y.v

clean-grammar:
	rm -f vsql/y.v vsql/y.y

grammar: clean-grammar vsql/y.v

# Formatting

fmt:
	v fmt -w cmd examples libvsql scripts vsql

fmt-verify:
	v fmt -verify cmd examples libvsql scripts vsql

# Tests

# test runs every test suite. Each one can also be run on its own.
test: sql-test vorm-test unit-test btree-test examples-test cli-test libvsql-test module-test

# unit-test runs the V tests in vsql/, except for the SQL and B-tree tests that
# have their own targets.
unit-test: oldv
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) test $(filter-out vsql/btree_test.v vsql/sql_test.v,$(wildcard vsql/*_test.v))

# Only the B-tree tests are built with -prod. They take 5 minutes without it
# (rather than 70 seconds), but the other tests are much quicker to build
# without it.
btree-test: oldv
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) $(PROD) vsql/btree_test.v

# sql-test also prints how much of vsql/ the SQL tests cover, unless COVERAGE=0.
# When all of the tests are run, every line must be covered.
# -no-skip-unused keeps functions that are never called, otherwise they wouldn't
# be counted at all. -d coverage lets the code know it's a coverage build (see
# crash_point). The LCOV file can be used for a line by line report. On
# GitHub Actions the coverage is also added to the job summary.
sql-test: oldv
ifeq ($(COVERAGE),0)
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) vsql/sql_test.v
else
	rm -rf coverage/data
	$(V) $(V3_OPTIONS) -stats -no-skip-unused -coverage coverage/data -d coverage $(BUILD_OPTIONS) vsql/sql_test.v
	$(V) cover coverage/data --filter "$(CURDIR)/vsql/" --lcov coverage/sql.lcov > /dev/null
	$(call coverage_summary,coverage/sql.lcov,SQL test,sql-test-uncovered)
ifeq ($(TEST)$(filter 0,$(MEMORY) $(FILE) $(SERVER)),)
	$(call verify_full_coverage,coverage/sql.lcov)
endif
endif

# sql-test-uncovered prints each line that the last "make sql-test" didn't
# cover, such as "vsql/table.v:218: return error(...)".
sql-test-uncovered:
	$(call coverage_uncovered,coverage/sql.lcov,sql-test)

# vorm-test runs the unit tests of the ORM driver (vorm/), and prints how much of
# vorm/ they cover, unless COVERAGE=0. See sql-test. It fails unless they cover
# every line of vorm/.
vorm-test: oldv
ifeq ($(COVERAGE),0)
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) vorm/vorm_test.v
else
	rm -rf coverage/vorm-data
	$(V) $(V3_OPTIONS) -stats -no-skip-unused -coverage coverage/vorm-data $(BUILD_OPTIONS) vorm/vorm_test.v
	$(V) cover coverage/vorm-data --filter "$(CURDIR)/vorm/" --lcov coverage/vorm.lcov > /dev/null
	$(call coverage_summary,coverage/vorm.lcov,vorm test,vorm-test-uncovered)
	$(call verify_full_coverage,coverage/vorm.lcov)
endif

# vorm-test-uncovered prints each line that the last "make vorm-test" didn't
# cover.
vorm-test-uncovered:
	$(call coverage_uncovered,coverage/vorm.lcov,vorm-test)

# coverage_summary prints the lines covered in the LCOV file $(1), such as
# "SQL test coverage: 92.71% (3509 of 3785 lines, ...)" for $(2) "SQL test".
# $(3) is the target that shows the lines that aren't covered. On GitHub Actions
# it's also added to the job summary.
coverage_summary = @awk -F: '/^LF:/ { total += $$2 } /^LH:/ { hit += $$2 } END { printf "$(2) coverage: %.2f%% (%d of %d lines, run \"make $(3)\" to see the rest)\n", 100 * hit / total, hit, total }' $(1) \
	| tee -a "$${GITHUB_STEP_SUMMARY:-/dev/null}"

# coverage_uncovered prints each line that isn't covered in the LCOV file $(1),
# which is created by the target $(2).
coverage_uncovered = @test -f $(1) || { echo 'Run "make $(2)" first.'; exit 1; }; \
	$(call uncovered_lines,$(1))

# verify_full_coverage fails unless every line in the LCOV file $(1) is covered,
# and prints the lines that aren't.
verify_full_coverage = @awk -F: '/^LF:/ { total += $$2 } /^LH:/ { hit += $$2 } END { exit hit == total ? 0 : 1 }' $(1) \
		|| { echo '$(1) must have 100% coverage. These lines are not covered:'; \
			$(call uncovered_lines,$(1)); exit 1; }

# uncovered_lines prints each line that isn't covered in the LCOV file $(1),
# such as "vsql/table.v:218: return error(...)".
uncovered_lines = awk -v root="$(CURDIR)/" ' \
		/^SF:/ { path = substr($$0, 4); file = path; sub(root, "", file); split("", src); n = 0; \
			while ((getline line < path) > 0) src[++n] = line; close(path) } \
		/^DA:/ { split(substr($$0, 4), da, ","); if (da[2] == 0) { code = src[da[1]]; \
			gsub(/^[ \t]+/, "", code); print file ":" da[1] ": " code } }' $(1)

# CLI Tests

cli-test: bin/vsql
	for f in `ls cmd/tests/*.sh`; do \
		echo $$f; VSQL=bin/vsql ./$$f || exit 1; \
	done

cmd/tests/%: bin/vsql
	VSQL=bin/vsql ./cmd/tests/$*.sh

# Examples

examples-test:
	for f in `ls examples/*.v`; do \
		echo $$f; v $(V3_OPTIONS) run $$f || exit 1; \
	done
	$(MAKE) libvsql-example module-example

# The C programs that use libvsql must be C99.
LIBVSQL_CC = $(LIBVSQL_C) -std=c99 -pedantic-errors -Wall -Wextra -Werror -Ilibvsql

# libvsql.h and example.c must also work with C++.
LIBVSQL_CXX = $(LIBVSQL_CPP) -x c++ -std=c++11 -pedantic-errors -Wall -Wextra -Werror -Ilibvsql

libvsql-example: $(LIBVSQL)
	$(LIBVSQL_CC) libvsql/example.c -Lbin -lvsql $(LIBVSQL_RPATH) -o bin/libvsql-example
	bin/libvsql-example
	$(LIBVSQL_CXX) libvsql/example.c -Lbin -lvsql $(LIBVSQL_RPATH) -o bin/libvsql-example-cpp
	bin/libvsql-example-cpp

# VSQL_BIN is the vsql binary that compiles the modules (bin/vsql.exe on
# Windows, where it isn't built by this Makefile).
VSQL_BIN ?= bin/vsql

# module-example compiles libvsql/module/example.mod (see
# docs/language-c.rst) and runs example_main.c with it. The generated C
# must also be C99 and C++11.
module-example: $(LIBVSQL) $(VSQL_BIN)
	$(call module_program,example)

# module-test is like module-example, for the tests of the generated C in
# libvsql/module/test_main.c.
module-test: $(LIBVSQL) $(VSQL_BIN)
	$(call module_program,test)

module_program = $(VSQL_BIN) module libvsql/module/$(1).mod \
	&& $(LIBVSQL_CC) libvsql/module/$(1).c libvsql/module/$(1)_main.c -Lbin -lvsql $(LIBVSQL_RPATH) -o bin/module-$(1) \
	&& bin/module-$(1) \
	&& $(LIBVSQL_CXX) libvsql/module/$(1).c libvsql/module/$(1)_main.c -Lbin -lvsql $(LIBVSQL_RPATH) -o bin/module-$(1)-cpp \
	&& bin/module-$(1)-cpp

libvsql-test: $(LIBVSQL)
	v run scripts/check-libvsql-constants.vsh
	$(LIBVSQL_CC) libvsql/test.c libvsql/*_test.c $(LIBVSQL_PTHREAD) -Lbin -lvsql $(LIBVSQL_RPATH) -o bin/libvsql-test
	bin/libvsql-test

examples/%: vsql/y.v
	v $(V3_OPTIONS) run examples/$*.v

# Benchmarking

bench: bench-on-disk bench-memory

bench-on-disk: bin/vsql
	./bin/vsql bench

bench-memory: bin/vsql
	./bin/vsql bench -file ':memory:'
