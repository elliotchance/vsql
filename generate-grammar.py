import re
import sys

# type RuleOrString = EarleyRule | string

class EarleyProduction(object):
    # terms []RuleOrString

    def __init__(self, terms):
        assert isinstance(terms, list)
        if len(terms) > 0:
            assert isinstance(terms[0], str) or isinstance(terms[0], EarleyRule)

        self.terms = terms

    def index(self):
        return ','.join([t.__str__() for t in self.terms])

class EarleyRule(object):
    # name        string
    # productions []EarleyProduction

    def __init__(self, name, productions):
        assert isinstance(name, str)
        assert isinstance(productions, list)
        if len(productions) > 0:
            assert isinstance(productions[0], EarleyProduction)

        self.name = name
        self.productions = productions

    def __str__(self):
        return self.name

    # def __repr__(self):
    #     return "%s ::= %s" % (self.name, " | ".join(repr(p) for p in self.productions))

class EarleyState(object):
    # name         string
    # production   EarleyProduction
    # dot_index    int
    # start_column EarleyColumn
    # rules        []EarleyRule

    def __init__(self, name, production, dot_index, start_column):
        assert isinstance(name, str)
        assert isinstance(production, EarleyProduction)
        assert isinstance(dot_index, int)
        assert isinstance(start_column, EarleyColumn)

        self.name = name
        self.production = production
        self.start_column = start_column
        self.dot_index = dot_index

        rules = []
        for t in production.terms:
            if isinstance(t, EarleyRule):
                rules.append(t)

        self.rules = rules

    def __repr__(self):
        terms = []
        for p in self.production.terms:
            terms.append(p.__str__())
        
        terms.insert(self.dot_index, "$")

        return f'{self.name} -> {" ".join(terms)} [{self.start_column}-{self.end_column}]'
    
    def eq(self, other):
        return self.name == other.name and self.production == other.production \
            and self.dot_index == other.dot_index and self.start_column == other.start_column
    
    def index(self):
        return f'{self.name} {self.production.index()} {self.dot_index} {self.start_column}'
    
    def completed(self):
        return self.dot_index >= len(self.production.terms)
    
    def next_term(self):
        if self.completed():
            return ''
        
        return self.production.terms[self.dot_index]

class Set(object):
    def __init__(self):
        self.elems = {}

    def exists(self, v):
        return v.index() in self.elems
        # for elem in self.elems:
        #     if elem.eq(v):
        #         return True

        # return False
        
    def add(self, v):
        if self.exists(v):
            return
        
        self.elems[v.index()] = v
        # self.elems.append(v)

class EarleyColumn(object):
    # index  int
    # token  string
    # value  string
    # states []EarleyState
    # unique Set<EarleyState>

    def __init__(self, index, token, value):
        assert isinstance(index, int)
        assert isinstance(token, str)
        assert isinstance(value, str)

        self.index = index
        self.token = token
        self.value = value
        self.states = []
        self.unique = Set()

    def __str__(self):
        return f'{self.index}'

    def __repr__(self):
        return f'{self.token}:{self.value}'

    def add(self, state):
        if not self.unique.exists(state):
            self.unique.add(state)
            state.end_column = self
            self.states.append(state)
            return True

        return False

    def print(self, completedOnly = False):
        print(f'[{self.index}] {self.token.__repr__()}')
        print("=" * 35)
        for s in self.states:
            if completedOnly and not s.completed():
                continue
            print(repr(s))
        print()

class EarleyNode(object):
    # value    EarleyState
    # children []EarleyNode

    def __init__(self, value, children):
        assert isinstance(value, EarleyState)
        assert isinstance(children, list)
        if len(children) > 0:
            assert isinstance(children[0], EarleyNode)

        self.value = value
        self.children = children

    def print(self, level):
        print("  " * level + str(self.value))
        for child in self.children:
            child.print(level + 1)

    def max(self):
        max = 0
        for child in self.children:
            child_max = child.max()
            if child_max > max:
                max = child_max

        if self.value.end_column.index > max:
            max = self.value.end_column.index

        return max

def predict(col, rule):
    assert isinstance(rule, EarleyRule)

    for prod in rule.productions:
        col.add(EarleyState(rule.name, prod, 0, col))

def scan(col, state, token):
    assert isinstance(state, EarleyState)
    assert isinstance(token, str)

    if token != col.token:
        return

    col.add(EarleyState(state.name, state.production, state.dot_index + 1, state.start_column))

def complete(col, state):
    assert isinstance(state, EarleyState)

    if not state.completed():
        return

    for st in state.start_column.states:
        term = st.next_term()
        if not isinstance(term, EarleyRule):
            continue
        if term.name == state.name:
            col.add(EarleyState(st.name, st.production, st.dot_index + 1, st.start_column))

def parse3(rule, table):
    assert isinstance(rule, EarleyRule)
    assert isinstance(table, list)
    if len(table) > 0:
        assert isinstance(table[0], EarleyColumn)

    table[0].add(EarleyState("start", EarleyProduction([rule]), 0, table[0]))

    for i, col in enumerate(table):
        for j, state in enumerate(col.states):
            if state.completed():
                complete(col, state)
            else:
                term = state.next_term()
                if isinstance(term, EarleyRule):
                    predict(col, term)
                elif i + 1 < len(table):
                    scan(table[i+1], state, term)
        
        #col.print(completedOnly = True)

    # find gamma rule in last table column (otherwise fail)
    for st in table[len(table)-1].states:
        if st.name == "start" and st.completed():
            return st

    max = 0
    for col in table:
        for st in col.states:
            t = build_trees(st)
            if len(t) > 0:
                m = t[0].max()
                if m > max:
                    max = m

    if max+1 >= len(table):
        max = len(table)-2
    
    raise ValueError("syntax error at " + table[max+1].value)

def build_trees(state):
    assert isinstance(state, EarleyState)

    return build_trees_helper([], state, len(state.rules) - 1, state.end_column)

def build_trees_helper(children, state, rule_index, end_column):
    assert isinstance(children, list)
    if len(children) > 0:
        assert isinstance(children[0], EarleyNode)
    assert isinstance(state, EarleyState)
    assert isinstance(rule_index, int)
    assert isinstance(end_column, EarleyColumn)

    start_column = EarleyColumn(-1, '', '')
    if rule_index < 0:
        return [EarleyNode(state, children)]
    elif rule_index == 0:
        start_column = state.start_column
    
    rule = state.rules[rule_index]
    outputs = []
    for st in end_column.states:
        if st is state:
            break
        if st is state or not st.completed() or st.name != rule.name:
            continue
        if start_column.index >= 0 and st.start_column != start_column:
            continue
        for sub_tree in build_trees(st):
            new_children = [sub_tree]
            for child in children:
                new_children.append(child)

            for node in build_trees_helper(new_children, state, rule_index - 1, st.start_column):
                outputs.append(node)

    return outputs

def parse_grammar(grammar):
    grammar_rules = {
        '^identifier': EarleyRule("^identifier", [EarleyProduction(["^identifier"])]),
        '^integer': EarleyRule("^integer", [EarleyProduction(["^integer"])]),
        '^string': EarleyRule("^string", [EarleyProduction(["^string"])]),
    }
    lines = []
    parse_functions = {}
    grammar_types = {}

    full_line = ''
    for line in grammar.split("\n"):
        if '/*' in line and '::=' in line:
            parts = line.split('/*')
            full_line += parts[0] + "::= "
            grammar_types[parts[0].strip()] = parts[1].split('*/')[0].strip()
        elif '/*' in line:
            continue
        elif line == '':
            if full_line != '':
                lines.append(full_line.strip())
                full_line = ''
        else:
            full_line += ' ' + line

    # First parse to collect empty rules by name
    for line_number, line in enumerate(lines):
        name, raw_rules = line.split(' ::=')

        if '"' in raw_rules:
            grammar_rules[name] = EarleyRule(name, [EarleyProduction(re.findall('"(.+)"', raw_rules))])
            continue

        grammar_rule = EarleyRule(name, [])
        grammar_rules[name] = grammar_rule
        rules = raw_rules.split(' | ')
        for rule_number, rule in enumerate(rules):
            # If there is a parsing function we replace the current rule with a
            # subrule:
            #
            #   <term> /* Expr */ ::=
            #       <factor>
            #     | <term> <asterisk> <factor>   -> binary_expr
            #     | <term> <solidus> <factor>    -> binary_expr
            #
            # Becomes:
            #
            #   <term> ::=
            #       <factor>
            #     | <term: 2>
            #     | <term: 3>
            #
            #   <term: 2> ::= <term> <asterisk> <factor>
            #
            #   <term: 3> ::= <term> <solidus> <factor>
            #
            # The subrule is important becuase it creates a single node that we
            # can capture all the children and invoke the parsing function.
            if '->' in rule:
                rule, parse_function = rule.split(' -> ')
                new_rule = name[:-1] + ': ' + str(rule_number + 1) + '>'
                lines.append(new_rule + ' ::= ' + rule)
                rules[rule_number] = new_rule
                parse_functions[new_rule] = (parse_function.strip(), re.findall('(<.*?>|[^\s]+)', rule))

            for token in re.findall('(<.*?>|[^\s]+)', rule):
                if token.isupper():
                    grammar_rules[token] = EarleyRule(token, [EarleyProduction([token])])
                    grammar_types[token] = ''

        lines[line_number] = name + ' ::= ' + ' | '.join(rules)

        grammar_rules[name] = grammar_rule

    # Second parse to add the productions for rules
    for line in lines:
        name, raw_rules = line.split(' ::= ')

        if '"' in raw_rules:
            continue

        rules = raw_rules.split(' | ')
        for rule in rules:
            actual_rule = []
            for token in re.findall('(<.*?>|[^\s]+)', rule):
                actual_rule.append(grammar_rules[token])
            grammar_rules[name].productions.append(EarleyProduction(actual_rule))

    return grammar_rules, parse_functions, grammar_types

grammar_file = open('grammar.bnf', mode='r')
grammar, parse_functions, grammar_types = parse_grammar(grammar_file.read())
grammar_file.close()

def rule_name(name):
    if isinstance(name, EarleyRule):
        return name.name

    return name

def var_name(name):
    return "rule_" + rule_name(name).lower().replace('<', '').replace(':', '').replace('>', '_').replace(' ', '_').replace('^', '_')

# Generate grammar file
grammar_file = open('vsql/grammar.v', mode='w')

grammar_file.write('// grammar.v is generated. DO NOT EDIT.\n')
grammar_file.write('// It can be regenerated from the grammar.bnf with:\n')
grammar_file.write('//   python generate-grammar.py\n\n')
grammar_file.write('module vsql\n\n')

grammar_file.write('type EarleyValue = ')
grammar_file.write(' | '.join(sorted(set([g for g in grammar_types.values() if g]))))
grammar_file.write('\n\n')

grammar_file.write('fn get_grammar() map[string]EarleyRule {\n')
grammar_file.write('\tmut rules := map[string]EarleyRule{}\n\n')

for gr in sorted(grammar.keys(), key=lambda s: s.lower()):
    grammar_file.write('\tmut ' + var_name(gr) + ' := &EarleyRule{name: "' + gr + '"}\n')

grammar_file.write('\n')

for gr in sorted(grammar.keys(), key=lambda s: s.lower()):
    for production in grammar[gr].productions:
        grammar_file.write('\t' + var_name(gr) + '.productions << EarleyProduction{[\n')
        for term in production.terms:
            if isinstance(term, str):
                grammar_file.write("\t\tEarleyRuleOrString{str: '" + rule_name(term) + "', rule: 0},\n")
            else:
               grammar_file.write("\t\tEarleyRuleOrString{rule: " + var_name(term) + "},\n")
        grammar_file.write('\t]}\n')
    grammar_file.write('\n')

for gr in sorted(grammar.keys(), key=lambda s: s.lower()):
    grammar_file.write('\trules[\'' + rule_name(gr) + '\'] = ' + var_name(gr) + '\n')

grammar_file.write('\n\treturn rules\n')
grammar_file.write('}\n\n')

grammar_file.write("""fn parse_ast(node EarleyNode) ?[]EarleyValue {
    if node.children.len == 0 {
        match node.value.name {
            '^integer' {
                return [EarleyValue(new_integer_value(node.value.end_column.value.int()))]
            }
            '^identifier' {
                return [EarleyValue(Identifier{node.value.end_column.value})]
            }
            '^string' {
                return [EarleyValue(new_varchar_value(node.value.end_column.value, 0))]
            }
            else {
                if node.value.name[0] == `<` {
                    return [EarleyValue(node.value.end_column.value)]
                }

                if node.value.name.is_upper() {
                    return [EarleyValue(node.value.name)]
                }

                panic(node.value.name)
                return []EarleyValue{}
            }
        }
    }

    mut children := []EarleyValue{}
    for child in node.children {
        for result in parse_ast(child) ? {
            children << result
        }
    }
    
    match node.value.name {
""")

for rule in sorted(parse_functions.keys(), key=lambda s: s.lower()):
    grammar_file.write("\t\t'" + rule + "' {\n")
    function_name, terms = parse_functions[rule]
    grammar_file.write("\t\t\tchildren = [EarleyValue(parse_" + function_name + "(")
    grammar_file.write(', '.join([
        'children[' + str(i) + '] as ' + grammar_types[t]
        for i, t in enumerate(terms)
        if t in grammar_types and grammar_types[t] != '']) + ") ?)]\n")
    
    grammar_file.write("\t\t}\n")

grammar_file.write("""\t\telse {}
    }

    return children
}
""")

grammar_file.close()

def parse_tree(text):
    tokens = [''] + text.split(' ')
    table = []
    for i, token in enumerate(tokens):
        if token == '(' or token == ')' or token == ',' or token == '.' or \
            token == '+' or token == '-' or token == '||' or token == ':':
            table.append(EarleyColumn(i, token, token))
        elif token == '' or token.isupper():
            table.append(EarleyColumn(i, token, token))
        elif token[0] == "'":
            table.append(EarleyColumn(i, '^string', token[1:-1]))
        elif token.isdigit():
            table.append(EarleyColumn(i, '^integer', token))
        else:
            table.append(EarleyColumn(i, '^identifier', token))

    q0 = parse3(grammar['<preparable statement>'], table)
    build_trees(q0)[0].print(0)

# Here are some examples you can enable for testing and debugging.

# parse_tree("DROP TABLE foo")
# parse_tree("SELECT 1 + 2 FROM t")
# parse_tree("INSERT INTO foo ( a , b ) VALUES ( 123 , 'bar' )")
# parse_tree("CREATE TABLE foo ( x INT NOT NULL )")
# parse_tree("INSERT INTO t ( x ) VALUES ( 0 )")
# parse_tree("SELECT ABS ( 1 . 2 ) , ABS ( - 1 . 23 ) FROM t")
# parse_tree("SELECT FLOOR ( 3 . 7 ) , FLOOR ( 3 . 3 ) , FLOOR ( - 3 . 7 ) , FLOOR ( - 3 . 3 ) FROM t")
# parse_tree("CREATE TABLE ABS (x INT)")
# parse_tree("SELECT 'foo' || 'bar' AS Str FROM t")
# parse_tree("SELECT TRUE AND TRUE FROM t")
# parse_tree("SELECT * FROM t OFFSET 0 ROWS")
# parse_tree("SELECT * FROM t FETCH FIRST 1 ROW ONLY")
# parse_tree("SELECT product_name , no_pennies ( price ) AS total FROM products")

for arg in sys.argv[1:]:
    print(arg)
    parse_tree(arg)
