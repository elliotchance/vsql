.PHONY: bench bench-on-disk bench-memory fmt fmt-verify test examples clean-grammar grammar sql-test sql-test-uncovered docs clean-docs oldv

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

# Only the B-tree tests are built with -prod. They take 5 minutes without it
# (rather than 70 seconds), but the other tests are much quicker to build
# without it.
#
# The SQL tests are run by sql-test, so that they're only built once (with
# coverage).
test: oldv sql-test
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) test $(filter-out vsql/btree_test.v vsql/sql_test.v,$(wildcard vsql/*_test.v))
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) $(PROD) test vsql/btree_test.v

btree-test: oldv
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) $(PROD) vsql/btree_test.v

# sql-test also prints how much of vsql/ the SQL tests cover, unless COVERAGE=0.
# -no-skip-unused keeps functions that are never called, otherwise they wouldn't
# be counted at all. The LCOV file can be used for a line by line report. On
# GitHub Actions the coverage is also added to the job summary.
sql-test: oldv
ifeq ($(COVERAGE),0)
	$(V) $(V3_OPTIONS) -stats $(BUILD_OPTIONS) vsql/sql_test.v
else
	rm -rf coverage/data
	$(V) $(V3_OPTIONS) -stats -no-skip-unused -coverage coverage/data $(BUILD_OPTIONS) vsql/sql_test.v
	$(V) cover coverage/data --filter "$(CURDIR)/vsql/" --lcov coverage/sql.lcov > /dev/null
	@awk -F: '/^LF:/ { total += $$2 } /^LH:/ { hit += $$2 } END { printf "SQL test coverage: %.2f%% (%d of %d lines, run \"make sql-test-uncovered\" to see the rest)\n", 100 * hit / total, hit, total }' coverage/sql.lcov \
		| tee -a "$${GITHUB_STEP_SUMMARY:-/dev/null}"
endif

# sql-test-uncovered prints each line that the last "make sql-test" didn't
# cover, such as "vsql/table.v:218: return error(...)".
sql-test-uncovered:
	@test -f coverage/sql.lcov || { echo 'Run "make sql-test" first.'; exit 1; }
	@awk -v root="$(CURDIR)/" ' \
		/^SF:/ { path = substr($$0, 4); file = path; sub(root, "", file); split("", src); n = 0; \
			while ((getline line < path) > 0) src[++n] = line; close(path) } \
		/^DA:/ { split(substr($$0, 4), da, ","); if (da[2] == 0) { code = src[da[1]]; \
			gsub(/^[ \t]+/, "", code); print file ":" da[1] ": " code } }' coverage/sql.lcov

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
