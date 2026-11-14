module vsql

// set_result_key sets Column.key_type of the columns of the result of a query
// specification that are its primary key, or its preferred candidate key when it
// has no primary key. The query must not be grouped, which the caller checks.
//
// Functional dependencies (T301) aren't supported, so the only keys known are
// for a query of one base table. The counterpart of a column of the table is
// the first column of the result that is a reference to it (including by an
// asterisk). The primary key is the PRIMARY KEY of the table (a BPK-set), when
// each of its columns has a counterpart. Otherwise, the preferred candidate key
// is the left-most of the smallest UNIQUE constraints (a BUC-set, which must be
// nondeferrable, with columns that are known not null) that have a counterpart
// for each column. Any other candidate key (such as every column of a result
// without duplicate rows) isn't known, so the result has no key at all.
//
// ISO/IEC 9075-2:2023, 4.26.3, Known functional dependencies in a base table
// ISO/IEC 9075-2:2023, 4.27, Candidate keys
fn set_result_key(mut columns []Column, body QuerySpecification, tables map[string]&Table, mut conn Connection) {
	mut table := Table{}
	mut base := Table{}
	from_clause := body.table_expression.from_clause
	if from_clause is TablePrimary && !body.without_from {
		name := from_clause.body
		if name is Identifier {
			// The plan has already found the table, which is virtual if it's
			// not in the storage (so it has no constraints).
			if table_name := conn.resolve_table_identifier(name, true) {
				if catalog := conn.catalogs[table_name.catalog_name] {
					base = catalog.storage.table(table_name.storage_id())
				}
			}

			// The columns of the range variable are the columns of the base
			// table in the same order, but may have been renamed (such as "t AS
			// x (a, b)").
			for _, t in tables {
				table = *t
			}
		}
	}

	// The position of the column of the table that each column of the result
	// is a counterpart of, if it's the first reference to it.
	mut sources := []int{}
	match body.exprs {
		AsteriskExpr {
			sources << []int{len: table.columns.len, init: index}
		}
		[]SelectSublist {
			for item in body.exprs {
				match item {
					QualifiedAsteriskExpr {
						sources << []int{len: table.columns.len, init: index}
					}
					DerivedColumn {
						mut source := -1
						if reference := item.column_reference() {
							if reference.is_column_of_table(conn, table) {
								source = table.column_names().index(reference.sub_entity_name)
							}
						}
						sources << source
					}
				}
			}
		}
	}

	mut key := key_counterparts(base, base.primary_key, sources)
	mut key_type := 1
	if key.len == 0 {
		key_type = 2
		for unique in base.unique_constraints {
			if unique.characteristics.is_deferrable()
				|| base.columns.any(it.name.sub_entity_name in unique.columns
					&& !is_known_not_nullable(base, it)) {
				continue
			}
			numbers := key_counterparts(base, unique.columns, sources)
			if numbers.len > 0 && (key.len == 0 || is_preferred_key(numbers, key)) {
				key = numbers.clone()
			}
		}
	}

	for number in key {
		columns[number - 1] = Column{
			...columns[number - 1]
			key_type: key_type
		}
	}
}

// key_counterparts is the column numbers of the result (from 1, in order) that
// are the counterparts of the named columns of the table, or none if any of them
// doesn't have one.
fn key_counterparts(table Table, names []string, sources []int) []int {
	mut numbers := []int{}
	for name in names {
		number := sources.index(table.column_names().index(name)) + 1
		if number == 0 {
			return []int{}
		}
		numbers << number
	}
	numbers.sort()

	return numbers
}

// is_preferred_key is true if the candidate key a (as column numbers in order)
// is preferred over b. A key that's a subset of the other is smaller, so the
// other one isn't a candidate key. Otherwise, the "left-most" rule compares the
// column numbers in order, where the shorter key is padded with zeros.
//
// ISO/IEC 9075-2:2023, 4.27, Candidate keys
fn is_preferred_key(a []int, b []int) bool {
	if a.all(it in b) {
		return true
	}
	if b.all(it in a) {
		return false
	}

	// Neither is a subset of the other, so they're different before the end of
	// the shorter one.
	mut i := 0
	for a[i] == b[i] {
		i++
	}

	return a[i] < b[i]
}
