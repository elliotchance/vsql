.PHONY: bench bench-on-disk bench-memory fmt fmt-verify test examples vsql grammar sql-test docs

# Binaries

vsql:
	v -prod cmd/vsql.v

# Documentation

docs:
	cd docs && make html

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
	v -stats -prod test vsql

btree-test:
	v -stats -prod test vsql/btree_test.v

sql-test:
	v -stats test vsql/sql_test.v

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
	v run cmd/vsql.v bench

bench-memory:
	v run cmd/vsql.v bench -file ':memory:'
