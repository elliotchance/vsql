.PHONY: bench bench-on-disk bench-memory fmt fmt-verify test examples vsql grammar sql-test docs clean-docs

# Is not used at the moment. It is useful for testing options like different
# `-gc` values.
BUILD_OPTIONS =

PROD = -prod

# Binaries

vsql:
	v $(BUILD_OPTIONS) $(PROD) cmd/vsql.v

# Documentation

docs:
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

bench-on-disk:
	v run $(PROD) cmd/vsql.v bench

bench-memory:
	v run $(PROD) cmd/vsql.v bench -file ':memory:'
