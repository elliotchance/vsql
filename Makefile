.PHONY: bench bench-on-disk bench-memory fmt fmt-verify test examples clean-grammar grammar sql-test docs clean-docs oldv

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

# V3 fails to compile vsql and falls back to the old compiler anyway, so skip
# straight to it. -n hides the notices, which are thousands of lines.
V3_OPTIONS = -old-compiler -n
endif

# Ready is a some quick tasks that can easily be forgotten when preparing a
# diff.

ready: grammar fmt snippets

# Binaries

bin/vsql: vsql/y.v
	mkdir -p bin
	v $(V3_OPTIONS) $(BUILD_OPTIONS) $(PROD) cmd/vsql-cli -o bin/vsql

bin/vsql.exe: vsql/y.v
	mkdir -p bin
	v $(V3_OPTIONS) -os windows $(BUILD_OPTIONS) $(PROD) cmd/vsql-cli -o bin/vsql.exe

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

vsql/y.y:
	./scripts/generate-grammar.vsh

vsql/y.v: vsql/y.y
	v run scripts/vyacc.v -o vsql/y.v vsql/y.y

clean-grammar:
	rm -f vsql/y.v vsql/y.y

grammar: clean-grammar vsql/y.v

# Formatting

fmt:
	v fmt -w cmd examples scripts vsql

fmt-verify:
	v fmt -verify cmd examples scripts vsql

# Tests

test: oldv
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) $(PROD) test vsql

btree-test: oldv
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) $(PROD) vsql/btree_test.v

sql-test: oldv
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) vsql/sql_test.v

# CLI Tests

cli-test: bin/vsql
	for f in `ls cmd/tests/*.sh`; do \
		echo $$f; VSQL=bin/vsql ./$$f || exit 1; \
	done

cmd/tests/%: bin/vsql
	VSQL=bin/vsql ./cmd/tests/$*.sh

# Examples

examples:
	for f in `ls examples/*.v`; do \
		echo $$f; v $(V3_OPTIONS) run $$f || exit 1; \
	done

examples/%: vsql/y.v
	v $(V3_OPTIONS) run examples/$*.v

# Benchmarking

bench: bench-on-disk bench-memory

bench-on-disk: bin/vsql
	./bin/vsql bench

bench-memory: bin/vsql
	./bin/vsql bench -file ':memory:'
