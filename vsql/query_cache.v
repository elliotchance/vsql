// query_cache.v provides tooling to cache previously parsed prepared
// statements. This is becuase parsing a statement is extremely expensive with
// the current Earley implementation and many queries (excluding values) are
// used more than once.
//
// The query cache is made more useful by the fact it can turn any existing
// query into a prepared statement so that cache works in all cases.

module vsql

// A QueryCache improves the performance of parsing by caching previously cached
// statements. By default, a new QueryCache is created for each Connection.
// However, you can share a single QueryCache safely amung multiple connections
// for even better performance. See ConnectionOptions.
@[heap]
pub struct QueryCache {
mut:
	stmts map[string]Stmt
}

// Create a new query cache.
pub fn new_query_cache() &QueryCache {
	return &QueryCache{}
}

fn (q QueryCache) prepare(tokens []Token) (string, map[string]Value, []Token) {
	// It's only worth caching specific types of queries.
	match tokens[0].value {
		'SELECT', 'INSERT', 'UPDATE', 'DELETE' { return q.prepare_stmt(tokens) }
		else { return '', map[string]Value{}, tokens }
	}
}

fn (q QueryCache) prepare_stmt(tokens []Token) (string, map[string]Value, []Token) {
	mut key := ''
	mut i := 0
	mut params := map[string]Value{}

	// TODO(elliotchance): It's not efficient to expand the number of tokens
	//  like this. Perhaps the parser should just understand a new type of
	//  placeholder so it can be replaced in place?
	mut new_tokens := []Token{cap: tokens.len}

	mut j := 0
	for j < tokens.len {
		token := tokens[j]

		// Special handling for named literals.
		if j < tokens.len - 1 && token.kind == .keyword
			&& (token.value == 'TIMESTAMP' || token.value == 'TIME' || token.value == 'DATE')
			&& tokens[j + 1].kind == .literal_string {
			v := match token.value {
				'DATE' {
					new_date_value(tokens[j + 1].value) or { panic(err) }
				}
				'TIME' {
					new_time_value(tokens[j + 1].value) or { panic(err) }
				}
				'TIMESTAMP' {
					new_timestamp_value(tokens[j + 1].value) or { panic(err) }
				}
				else {
					panic(token.value)
				}
			}
			params['P${i}'] = v

			key += ':P${i} '
			new_tokens << Token{.colon, ':'}
			new_tokens << Token{.literal_identifier, 'P${i}'}
			i++

			j += 2
			continue
		}

		// Do not replace numbers that appear in types. Such as 'VARCHAR(10)'.
		if token.kind == .keyword && (token.value == 'VARCHAR'
			|| token.value == 'CHAR' || token.value == 'VARYING'
			|| token.value == 'DECIMAL' || token.value == 'NUMERIC'
			|| token.value == 'TIMESTAMP' || token.value == 'TIME') && tokens[j + 1].value == '(' {
			key += tokens[j].value.to_upper() + ' '
			key += tokens[j + 1].value.to_upper() + ' '
			key += tokens[j + 2].value.to_upper() + ' '
			key += tokens[j + 3].value.to_upper() + ' '
			new_tokens << tokens[j..j + 4]
			j += 4
			continue
		}

		match token.kind {
			.literal_number {
				mut numeric_tokens := ''
				// Numeric values with a decimal and approximate literals (1e2) are
				// actually multiple tokens like [number, '.' number] or
				// [number, 'E', number] so we need to be careful to consume all.
				for j < tokens.len && (tokens[j].kind == .literal_number
					|| tokens[j].kind == .period || tokens[j].value == 'E') {
					numeric_tokens += tokens[j].value
					j++
				}

				// This should never fail as the value is already well formed, but we
				// have to satisfy the compiler with an "or".
				v := numeric_literal(numeric_tokens) or { panic(numeric_tokens) }
				params['P${i}'] = v

				key += ':P${i} '
				new_tokens << Token{.colon, ':'}
				new_tokens << Token{.literal_identifier, 'P${i}'}
				i++
				// j++
				continue
			}
			.literal_string {
				key += ':P${i} '
				params['P${i}'] = new_varchar_value(token.value)
				new_tokens << Token{.colon, ':'}
				new_tokens << Token{.literal_identifier, 'P${i}'}
				i++
				j++
				continue
			}
			else {}
		}

		key += token.value.to_upper() + ' '
		new_tokens << token
		j++
	}

	return key, params, new_tokens
}

fn (mut q QueryCache) parse(query string) !(Stmt, map[string]Value, bool) {
	mut tokens := tokenize(query)

	// EXPLAIN is super helpful, but not part of the SQL standard so we only
	// treat it as a prefix that is trimmed off before parsing.
	mut explain := false
	if tokens[0].value.to_upper() == 'EXPLAIN' {
		explain = true
		tokens = tokens[1..].clone()
	}

	key, params, new_tokens := q.prepare(tokens)
	if key == '' {
		stmt := parse(new_tokens)!
		return stmt, map[string]Value{}, explain
	}

	if key !in q.stmts {
		q.stmts[key] = parse(new_tokens)!
	}

	return q.stmts[key] or { panic('impossible') }, params, explain
}
