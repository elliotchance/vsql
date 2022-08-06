.PHONY: bench bench-on-disk bench-memory fmt fmt-verify test examples grammar sql-test docs clean-docs

# Is not used at the moment. It is useful for testing options like different
# `-gc` values.
BUILD_OPTIONS =

PROD = -prod

# Ready is a some quick tasks that can easily be forgotten when preparing a
# diff.

ready: grammar fmt snippets

# Binaries

bin/vsql:
	mkdir -p bin
	v $(BUILD_OPTIONS) $(PROD) cmd/vsql -o bin/vsql

bin/vsql.exe:
	mkdir -p bin
	v $(BUILD_OPTIONS) $(PROD) cmd/vsql
	mv cmd/vsql/vsql.exe bin/vsql.exe

# Documentation

snippets:
	python3 generate-snippets.py > docs/snippets.rst

docs: snippets
	mkdir -p docs/_static
	cd docs && make html SPHINXOPTS="-W --keep-going -n"

clean-docs:
	cd docs && make clean

# Grammar (BNF)

grammar:
	python3 generate-grammar.py
	v fmt -w vsql/grammar.v

# Formatting

fmt:
	v fmt -w .

fmt-verify:
	v fmt -verify .

# Tests

test:
	v -stats $(BUILD_OPTIONS) $(PROD) test vsql

btree-test:
	v -stats $(BUILD_OPTIONS) $(PROD) test vsql/btree_test.v

sql-test:
	v -stats $(BUILD_OPTIONS) test vsql/sql_test.v

# Examples

examples:
	for f in `ls examples/*.v`; do \
		v run $$f ; \
	done

examples/%:
	v run examples/$*.v

# Benchmarking

bench: bench-on-disk bench-memory

bench-on-disk: vsql
	./bin/vsql bench

bench-memory: vsql
	./bin/vsql bench -file ':memory:'
