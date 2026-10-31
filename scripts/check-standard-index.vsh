#!/usr/bin/env -S v

// check-standard-index.vsh checks the SQL standard index in docs/standard/
// (see docs/standard-index.rst) and every citation of the standard in the
// code. A citation looks like:
//
//   ISO/IEC 9075-2:2016(E), 8.8, <null predicate>, General Rules, 2.a
//
// The edition must be the one in docs/standard/editions.txt, the Subclause
// and its title must be in the index, and so must each rule. The title and
// rules are optional. Several rules are written "2, 4 and 5" or "2-4".
//
// With --citations, it prints each citation (file:line, edition and row ID)
// instead, which is used by "scripts/standard-index.py show".
import os

const statuses = ['todo', 'implemented', 'untested', 'partial', 'missing', 'deviates', 'n/a',
	'definition', 'container', 'impl-defined', 'untestable', 'unclear']

const sections = {
	'Syntax Rules':      'SR'
	'Access Rules':      'AR'
	'General Rules':     'GR'
	'Conformance Rules': 'CR'
	'Description':       'DE'
}

// The directories with code that may cite the standard.
const code_dirs = ['cmd', 'examples', 'libvsql', 'scripts', 'tests', 'vorm', 'vsql']

const code_exts = ['.v', '.vsh', '.c', '.h', '.y', '.sql']

struct Row {
	path   string
	line   int
	status string
	code   []string
	tests  []string
	note   string
}

struct Index {
mut:
	// citation is "ISO/IEC 9075-2:2016(E)" for part "2".
	citation map[string]string
	// rows is by part, then row ID.
	rows map[string]map[string]Row
	// titles is by part, then Subclause.
	titles map[string]map[string]string
}

struct Citation {
	path string
	line int
	part string
	// edition is ":2016(E)", or empty when it's missing.
	edition string
	ids     []string
}

fn main() {
	mut errors := []string{}
	index := read_index(mut errors)
	citations := find_citations(mut errors)

	if '--citations' in os.args {
		for c in citations {
			for id in c.ids {
				println('${c.path}:${c.line}\tISO/IEC 9075-${c.part}${c.edition}\t${id}')
			}
		}
		return
	}

	check_citations(index, citations, mut errors)
	check_rows(index, citations, mut errors)

	for e in errors {
		println(e)
	}
	if errors.len > 0 {
		println('${errors.len} errors (see docs/standard-index.rst)')
		exit(1)
	}
}

fn read_index(mut errors []string) Index {
	mut index := Index{}
	for line in os.read_lines('docs/standard/editions.txt') or { panic(err) } {
		if line.starts_with('#') || line.trim_space() == '' {
			continue
		}
		fields := line.split('\t')
		index.citation[fields[0]] = fields[1]
		index.rows[fields[0]] = map[string]Row{}
		index.titles[fields[0]] = map[string]string{}
	}

	for part, citation in index.citation {
		mut paths := os.glob('docs/standard/part${part}/*.txt') or { panic(err) }
		paths.sort()
		for path in paths {
			lines := os.read_lines(path) or { panic(err) }
			if lines.len == 0 || lines[0] != '# ${citation}' {
				errors << '${path}:1: the first line must be "# ${citation}"'
			}
			for i, line in lines {
				if line.starts_with('# ') && i > 1 {
					// "# 8.8, <null predicate>"
					number := line[2..].all_before(',')
					index.titles[part][number] = line.all_after(', ')
					continue
				}
				if line.starts_with('#') || line.trim_space() == '' {
					continue
				}
				fields := line.fields()
				if fields.len < 4 {
					errors << '${path}:${i + 1}: a row must have an id, status, code and tests'
					continue
				}
				id := fields[0]
				if id in index.rows[part] {
					errors << '${path}:${i + 1}: ${id} is a duplicate'
				}
				index.rows[part][id] = Row{
					path:   path
					line:   i + 1
					status: fields[1]
					code:   list(fields[2])
					tests:  list(fields[3])
					note:   fields[4..].join(' ')
				}
			}
		}
	}

	return index
}

fn list(field string) []string {
	if field == '-' {
		return []
	}

	return field.split(',')
}

// find_citations returns every citation in a comment of the code. Comments
// over several lines are joined, so that a citation can be wrapped.
fn find_citations(mut errors []string) []Citation {
	mut citations := []Citation{}
	for dir in code_dirs {
		for path in os.walk_ext(dir, '') {
			if os.file_ext(path) !in code_exts || path in ['vsql/y.v', 'vsql/y.y'] {
				continue
			}
			lines := os.read_lines(path) or { panic(err) }
			mut text := ''
			// starts[i] is the offset of the i-th joined line in text.
			mut starts := []int{}
			mut first := 0
			for i, line in lines {
				comment := comment_text(line, os.file_ext(path)) or {
					if text != '' {
						citations << parse_citations(path, text, starts, first, mut errors)
						text = ''
						starts = []
					}
					continue
				}
				if text == '' {
					first = i + 1
				}
				starts << text.len
				text += comment + ' '
			}
			if text != '' {
				citations << parse_citations(path, text, starts, first, mut errors)
			}
		}
	}

	return citations
}

// comment_text is the text of the comment on the line, if any.
fn comment_text(line string, ext string) ?string {
	s := line.trim_space()
	for marker in ['//', '/*', '*/', '*', '--', '#'] {
		if s.starts_with(marker) {
			if marker == '#' && ext !in ['.vsh'] {
				continue
			}
			if marker == '--' && ext != '.sql' {
				continue
			}
			return s[marker.len..].trim_right('*/').trim_space()
		}
	}
	if line.contains(' // ') {
		return line.all_after(' // ').trim_space()
	}

	return none
}

fn parse_citations(path string, text string, starts []int, first int, mut errors []string) []Citation {
	mut citations := []Citation{}
	mut pos := 0
	for {
		i := text.index_after('ISO/IEC 9075-', pos) or { break }
		pos = i + 1
		mut line := first
		for j, start in starts {
			if start <= i {
				line = first + j
			}
		}
		c := parse_citation(path, line, text[i..], mut errors) or { continue }
		citations << c
	}

	return citations
}

// parse_citation parses a citation at the start of s.
fn parse_citation(path string, line int, s string, mut errors []string) ?Citation {
	mut rest := s['ISO/IEC 9075-'.len..]
	part := take_while(rest, '0123456789')
	rest = rest[part.len..]
	mut edition := ''
	if rest.starts_with(':') {
		edition = rest.all_before(',').all_before(' ')
		rest = rest[edition.len..]
	}
	if !rest.starts_with(', ') {
		// Such as "(ISO/IEC 9075-3)": the part, without a Subclause.
		return Citation{path, line, part, edition, []}
	}
	rest = rest[2..]
	number := take_while(rest, '0123456789.').trim_right('.')
	if number == '' {
		return Citation{path, line, part, edition, []}
	}
	rest = rest[number.len..]
	mut ids := [number]

	// The title, if any.
	mut title := ''
	if rest.starts_with(', ') && !starts_with_section(rest[2..]) {
		after := rest[2..]
		if after.starts_with('<') {
			title = after.all_before('>') + '>'
		} else {
			title = after
			// A blank line in the comment (two spaces) also ends it.
			for stop in [',', ')', '. ', ':', ';', ' (', '"', '  ', ' ISO/IEC'] {
				title = title.all_before(stop)
			}
			title = title.trim_space().trim_right('.')
		}
		rest = after[title.len..]
	}
	if title != '' {
		ids << 'title:' + title
	}

	// The rules, if any.
	if rest.starts_with(', ') && starts_with_section(rest[2..]) {
		rest = rest[2..]
		for name, abbr in sections {
			if rest.starts_with(name) {
				rest = rest[name.len..]
				if !rest.starts_with(', ') {
					errors << '${path}:${line}: "${name}" must be followed by ", " and the rules'
					break
				}
				rest = rest[2..]
				for rule in parse_rules(rest) {
					ids << '${number}/${abbr}/${rule}'
				}
				break
			}
		}
	} else if rest.starts_with(', ') {
		for singular in ['Syntax Rule ', 'General Rule ', 'Access Rule ', 'Conformance Rule '] {
			if rest[2..].starts_with(singular) {
				errors << '${path}:${line}: use "${singular.trim_space()}s, " for "${s.limit(100)}"'
			}
		}
	}

	return Citation{path, line, part, edition, ids}
}

// starts_with_section is true if s starts with the name of a section and then
// the rules, so that a title like "Description of CLI item descriptor areas"
// isn't a section.
fn starts_with_section(s string) bool {
	for name, _ in sections {
		if s.starts_with(name) {
			rest := s[name.len..]
			if rest.starts_with(',') || (rest.len > 1 && rest[0] == ` ` && rest[1].is_digit()) {
				return true
			}
		}
	}

	return false
}

fn take_while(s string, chars string) string {
	mut n := 0
	for n < s.len && chars.contains(s[n..n + 1]) {
		n++
	}

	return s[..n]
}

// parse_rules parses "2", "2.a.i", "2, 4 and 5" and "2-4" (the last is 2, 3
// and 4). Anything else ends the list. A range is only expanded for the last
// level, such as "2.a-c".
fn parse_rules(s string) []string {
	mut rules := []string{}
	mut rest := s
	for {
		rule := take_while(rest, '0123456789.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ').trim_right('.')
		if rule == '' || !rule[0].is_digit() && rules.len == 0 {
			break
		}
		if !rule[0].is_digit() {
			// "b" in "2.a and b" is a sibling of the previous rule. A word
			// (such as "General") ends the list.
			if rule.len > 4 {
				break
			}
			prev := rules.last()
			if prev.contains('.') {
				rules << prev.all_before_last('.') + '.' + rule
			}
		} else {
			rules << rule
		}
		rest = rest[rule.len..]
		if rest.starts_with('-') {
			end := take_while(rest[1..], '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
			start := rules.last()
			last := start.all_after_last('.')
			prefix := if start.contains('.') { start.all_before_last('.') + '.' } else { '' }
			if last.is_int() && end.is_int() {
				for n in last.int() + 1 .. end.int() + 1 {
					rules << '${prefix}${n}'
				}
			} else if last.len == 1 && end.len == 1 {
				for c := last[0] + 1; c <= end[0]; c++ {
					rules << '${prefix}${[c].bytestr()}'
				}
			}
			rest = rest[1 + end.len..]
		}
		if rest.starts_with(', ') {
			rest = rest[2..]
		} else if rest.starts_with(' and ') {
			rest = rest[5..]
		} else {
			break
		}
	}

	return rules
}

fn check_citations(index Index, citations []Citation, mut errors []string) {
	for c in citations {
		citation := index.citation[c.part] or {
			if c.ids.len > 0 {
				errors << '${c.path}:${c.line}: ISO/IEC 9075-${c.part} is not in docs/standard/editions.txt'
			}
			continue
		}
		if c.ids.len == 0 {
			continue
		}
		if 'ISO/IEC 9075-${c.part}${c.edition}' != citation {
			errors << '${c.path}:${c.line}: ISO/IEC 9075-${c.part}${c.edition} must be ${citation}'
		}
		number := c.ids[0]
		if number !in index.rows[c.part] {
			errors << '${c.path}:${c.line}: ${citation}, ${number} is not a Subclause'
			continue
		}
		for id in c.ids[1..] {
			if id.starts_with('title:') {
				title := id.all_after('title:')
				// A <...> title can be one of the names in the title, such as
				// <token> for "<token> and <separator>".
				want := squash(index.titles[c.part][number])
				if squash(title) != want && !(title.starts_with('<') && want.contains(squash(title))) {
					errors << '${c.path}:${c.line}: ${citation}, ${number} is "${index.titles[c.part][number]}", not "${title}"'
				}
				continue
			}
			if id !in index.rows[c.part] {
				errors << '${c.path}:${c.line}: ${citation}, ${id} is not a rule'
			}
		}
	}
}

fn squash(s string) string {
	return s.replace(' ', '').replace('’', "'").to_lower()
}

fn check_rows(index Index, citations []Citation, mut errors []string) {
	// cited is the row IDs cited by each file.
	mut cited := map[string][]string{}
	for c in citations {
		for id in c.ids {
			if !id.starts_with('title:') {
				cited[c.path] << '${c.part}:${id}'
			}
		}
	}

	for part, rows in index.rows {
		for id, row in rows {
			at := '${row.path}:${row.line}: ${id}'
			if row.status !in statuses {
				errors << '${at}: unknown status "${row.status}"'
				continue
			}
			if row.status in ['implemented', 'partial'] && (row.code.len == 0 || row.tests.len == 0) {
				errors << '${at}: ${row.status} needs code and tests'
			}
			if row.status == 'untested' && row.code.len == 0 {
				errors << '${at}: untested needs code'
			}
			if row.status in ['missing', 'deviates'] && !row.note.contains('#') {
				errors << '${at}: ${row.status} needs an issue (#123) in the note'
			}
			if row.status in ['n/a', 'unclear', 'impl-defined'] && row.note == '' {
				errors << '${at}: ${row.status} needs a note'
			}
			for path in row.code {
				if !os.exists(path) {
					errors << '${at}: ${path} does not exist'
				} else if !cites(cited[path], '${part}:${id}') {
					errors << '${at}: ${path} does not cite it'
				}
			}
			for path in row.tests {
				if !os.exists(path) {
					errors << '${at}: ${path} does not exist'
				}
			}
		}
	}
}

// cites is true if one of the ids is the id, or one of its parents or
// children (since a citation of "General Rules, 2" covers 2.a).
fn cites(ids []string, id string) bool {
	for cited in ids {
		if cited == id || id.starts_with(cited + '.') || cited.starts_with(id + '.')
			|| id.starts_with(cited + '/') || cited.starts_with(id + '/') {
			return true
		}
	}

	return false
}
