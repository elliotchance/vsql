.PHONY: bench bench-on-disk bench-memory fmt fmt-verify test examples vsql

# Binaries

vsql:
	v -gc boehm -prod cmd/vsql.v

# Formatting

fmt:
	v fmt -w .

fmt-verify:
	v fmt -verify .

# Tests

test:
	v -stats -gc boehm -prod test vsql

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
