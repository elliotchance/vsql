// query_cache.v provides tooling to cache previously parsed prepared
// statements. This is becuase parsing a statement is extremely expensive with
// the current Earley implementation and many queries (excluding values) are
// used more than once.
//
// The query cache is made more useful by the fact it can turn any existing
// query into a prepared statement so that cache works in all cases.

module vsql

[heap]
struct QueryCache {
mut:
	stmts map[string]Stmt
}

fn new_query_cache() &QueryCache {
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

	for j, token in tokens {
		mut ignore := false

		// Do not replace with placeholders for parts of a number.
		//
		// TODO(elliotchance): This should actually replace the exact decimal
		//  number with a placeholder instead of ignoring.
		if j < tokens.len - 1 && tokens[j + 1].kind == .period {
			ignore = true
		}
		if j > 0 && tokens[j - 1].kind == .period {
			ignore = true
		}

		if !ignore {
			match token.kind {
				.literal_number {
					key += ':p$i '
					if token.value.f64() == token.value.int() {
						params['p$i'] = new_integer_value(token.value.int())
					} else {
						params['p$i'] = new_double_precision_value(token.value.f64())
					}
					new_tokens << Token{.colon, ':'}
					new_tokens << Token{.literal_identifier, 'p$i'}
					i++
					continue
				}
				.literal_string {
					key += ':p$i '
					params['p$i'] = new_varchar_value(token.value, 0)
					new_tokens << Token{.colon, ':'}
					new_tokens << Token{.literal_identifier, 'p$i'}
					i++
					continue
				}
				else {}
			}
		}

		key += token.value.to_upper() + ' '
		new_tokens << token
	}

	return key, params, new_tokens
}

fn (mut q QueryCache) parse(query string) ?(Stmt, map[string]Value, bool) {
	mut tokens := tokenize(query)

	// EXPLAIN is super helpful, but not part of the SQL standard so we only
	// treat it as a prefix that is trimmed off before parsing.
	mut explain := false
	if tokens[0].value.to_upper() == 'EXPLAIN' {
		explain = true
		tokens = tokens[1..]
	}

	key, params, new_tokens := q.prepare(tokens)
	if key == '' {
		stmt := parse(new_tokens) ?
		return stmt, map[string]Value{}, explain
	}

	if key !in q.stmts {
		q.stmts[key] = parse(new_tokens) ?
	}

	return q.stmts[key] or { panic('impossible') }, params, explain
}
