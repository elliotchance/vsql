.PHONY: bench bench-on-disk bench-memory fmt fmt-verify test examples vsql grammar sql-test docs

# Binaries

vsql:
	v -gc boehm -prod cmd/vsql.v

# Documentation

docs:
	cd docs && make html

# Grammar (BNF)

grammar:
	python generate-grammar.py
	v fmt -w vsql/grammar.v

# Formatting

fmt:
	v fmt -w .

fmt-verify:
	v fmt -verify .

# Tests

test:
	v -stats -gc boehm -prod test vsql

sql-test:
	v -stats -gc boehm test vsql/sql_test.v

# Examples

examples:
	for f in `ls examples/*.v`; do \
		v -gc boehm -prod run $$f ; \
	done

# Benchmarking

bench: bench-on-disk bench-memory

bench-on-disk:
	v -gc boehm run cmd/vsql.v bench

bench-memory:
	v -gc boehm run cmd/vsql.v bench -file ':memory:'
