// earley.v is an implementation of an Earley parser that was heavily adapted
// from: https://github.com/tomerfiliba/tau/blob/master/earley3.py.

module vsql

import strings

@[heap]
struct EarleyRuleOrString {
	rule &EarleyRule
	str  string
}

fn (o &EarleyRuleOrString) str() string {
	if unsafe { o.rule != 0 } {
		return (*o.rule).str()
	}

	return o.str
}

@[heap]
struct EarleyProduction {
	terms []&EarleyRuleOrString
}

fn (prod &EarleyProduction) index() string {
	mut elems := []string{}
	for t in prod.terms {
		elems << t.str()
	}
	return elems.join(',')
}

@[heap]
struct EarleyRule {
	name string
mut:
	productions []&EarleyProduction
}

fn (rule &EarleyRule) str() string {
	return rule.name
}

@[heap]
struct EarleyState {
	name         string
	production   &EarleyProduction
	dot_index    int
	start_column &EarleyColumn
mut:
	end_column &EarleyColumn
	rules      []&EarleyRule
}

fn new_earley_state(name string, production &EarleyProduction, dot_index int, start_column &EarleyColumn) &EarleyState {
	mut rules := []&EarleyRule{}
	for t in production.terms {
		if unsafe { t.rule != 0 } {
			rules << t.rule
		}
	}

	return &EarleyState{
		name:         name
		production:   production
		start_column: start_column
		dot_index:    dot_index
		rules:        rules
		end_column:   unsafe { 0 }
	}
}

fn (state &EarleyState) index() string {
	return '${state.name} ${state.production.index()} ${state.dot_index} ${state.start_column}'
}

fn (state &EarleyState) str() string {
	mut terms := []string{}
	for p in state.production.terms {
		terms << p.str()
	}

	terms.insert(state.dot_index, '$')

	return '${state.name} -> ${terms.join(' ')} [${state.start_column}-${state.end_column}]'
}

fn (state &EarleyState) eq(other &EarleyState) bool {
	return state.name == other.name && state.production == other.production
		&& state.dot_index == other.dot_index && state.start_column == other.start_column
}

fn (state &EarleyState) completed() bool {
	return state.dot_index >= state.production.terms.len
}

fn (state &EarleyState) next_term() &EarleyRuleOrString {
	if state.completed() {
		return &EarleyRuleOrString{
			rule: unsafe { 0 }
		}
	}

	return state.production.terms[state.dot_index]
}

@[heap]
struct Set {
mut:
	elems map[string]bool
}

fn (s &Set) exists(v string) bool {
	return v in s.elems
}

fn (mut s Set) add(v string) {
	if s.exists(v) {
		return
	}

	s.elems[v] = true
}

@[heap]
struct EarleyColumn {
	index int
	token string
	value string
mut:
	states []&EarleyState
	unique &Set
}

fn new_earley_column(index int, token string, value string) &EarleyColumn {
	return &EarleyColumn{
		index:  index
		token:  token
		value:  value
		unique: &Set{}
	}
}

fn (col &EarleyColumn) str() string {
	return '${col.index}'
}

fn (col &EarleyColumn) repr() string {
	return '${col.token}:${col.value}'
}

fn (mut col EarleyColumn) add(mut state EarleyState) bool {
	if !col.unique.exists(state.index()) {
		col.unique.add(state.index())
		state.end_column = col
		col.states << state

		return true
	}

	return false
}

fn (col &EarleyColumn) print() {
	println('[${col.index}] ${col.token}')
	println(strings.repeat_string('=', 35))
	for s in col.states {
		println(s.str())
	}
	println('')
}

@[heap]
struct EarleyNode {
	value    &EarleyState
	children []&EarleyNode
}

fn (node &EarleyNode) print(level int) {
	println(strings.repeat_string('  ', level) + node.value.str())
	for child in node.children {
		child.print(level + 1)
	}
}

fn (node &EarleyNode) max() int {
	mut max := 0
	for child in node.children {
		child_max := child.max()
		if child_max > max {
			max = child_max
		}
	}

	if node.value.end_column.index > max {
		max = node.value.end_column.index
	}

	return max
}

fn predict(mut col EarleyColumn, rule &EarleyRule) {
	for prod in rule.productions {
		col.add(mut new_earley_state(rule.name, prod, 0, col))
	}
}

fn scan(mut col EarleyColumn, state &EarleyState, token string) {
	if token != col.token {
		return
	}

	col.add(mut new_earley_state(state.name, state.production, state.dot_index + 1, state.start_column))
}

fn complete(mut col EarleyColumn, state &EarleyState) {
	if !state.completed() {
		return
	}

	for st in state.start_column.states {
		term := st.next_term()

		if unsafe { term.rule == 0 } {
			continue
		}

		if term.rule.name == state.name {
			col.add(mut new_earley_state(st.name, st.production, st.dot_index + 1, st.start_column))
		}
	}
}

fn parse(tokens []Token) !Stmt {
	mut columns := tokenize_earley_columns(tokens)
	mut grammar := get_grammar()

	q0 := parse_earley(unsafe { grammar['<preparable statement>'] }, mut columns)!

	trees := build_trees(q0)
	if trees.len == 0 {
		panic(q0.end_column)
	}

	// This is helpful for debugging. Enable it to see the tree (or at least the
	// first resolved tree since there could be multiple solutions in an
	// ambiguous grammar)
	//
	//   trees[0].print(0)

	return (parse_ast(trees[0])!)[0] as Stmt
}

fn parse_earley(rule &EarleyRule, mut table []&EarleyColumn) !&EarleyState {
	table[0].add(mut new_earley_state('start', &EarleyProduction{[
		&EarleyRuleOrString{ rule: rule },
	]}, 0, table[0]))

	for i, mut col in table {
		for state in col.states {
			if state.completed() {
				complete(mut *col, state)
			} else {
				term := state.next_term()
				if unsafe { term.rule != 0 } {
					predict(mut *col, term.rule)
				} else if i + 1 < table.len {
					scan(mut table[i + 1], state, term.str)
				}
			}
		}
	}

	// find gamma rule in last table column (otherwise fail)
	for st in table[table.len - 1].states {
		if st.name == 'start' && st.completed() {
			return st
		}
	}

	// Find the deepest resolved path which is our best guess of where the
	// syntax error is located.
	mut max := 0
	for col in table {
		for st in col.states {
			t := build_trees(st)
			if t.len > 0 {
				m := t[0].max()
				if m > max {
					max = m
				}
			}
		}
	}

	if max + 1 >= table.len {
		max = table.len - 2
	}

	// +1 here because we add an empty token at the start of the stream.
	return sqlstate_42601('near "${table[max + 1].value}"')
}

fn build_trees(state &EarleyState) []&EarleyNode {
	return build_trees_helper([]&EarleyNode{}, state, state.rules.len - 1, state.end_column)
}

fn build_trees_helper(children []&EarleyNode, state &EarleyState, rule_index int, end_column &EarleyColumn) []&EarleyNode {
	mut start_column := new_earley_column(0, '', '')
	if rule_index < 0 {
		return [&EarleyNode{state, children}]
	} else if rule_index == 0 {
		start_column = state.start_column
	}

	rule := state.rules[rule_index]
	mut outputs := []&EarleyNode{}
	for st in end_column.states {
		if st.eq(state) || !st.completed() || st.name != rule.name {
			continue
		}
		if start_column.index != 0 && st.start_column != start_column {
			continue
		}
		for sub_tree in build_trees(st) {
			mut new_children := [sub_tree]
			for child in children {
				new_children << child
			}

			for node in build_trees_helper(new_children, state, rule_index - 1, st.start_column) {
				outputs << node
			}
		}
	}

	return outputs
}

fn tokenize_earley_columns(tokens []Token) []&EarleyColumn {
	mut table := [new_earley_column(0, '', '')]

	for i, token in tokens {
		v := token.value

		if tokens[i].kind == .literal_string {
			table << new_earley_column(i + 1, '^string', v)
		} else if tokens[i].kind == .keyword {
			table << new_earley_column(i + 1, v, v)
		} else if v[0].is_digit() {
			table << new_earley_column(i + 1, '^integer', v)
		} else if v == '(' || v == ')' || v == ',' || v == '=' || v == '<>' || v == '.' || v == '+'
			|| v == '-' || v == '*' || v == '/' || v == '>' || v == '<' || v == '>=' || v == '<='
			|| v == '||' || v == ':' {
			table << new_earley_column(i + 1, v, v)
		} else {
			table << new_earley_column(i + 1, '^identifier', v)
		}
	}

	return table
}
