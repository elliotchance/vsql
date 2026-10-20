#!/usr/bin/env -S v

// coverage-report.vsh reads an LCOV file produced by `v cover --lcov`, removes
// the points that are marked to be ignored, writes the result to a new LCOV
// file and prints a summary of what's not covered. It fails if anything that
// isn't ignored is not covered.
//
//   v run scripts/coverage-report.vsh coverage/vsql.lcov coverage/sql.lcov
//
// A `// coverage:ignore` comment ignores:
//
//   1. At the end of a line that opens a block, the whole block:
//
//        else { // coverage:ignore
//
//   2. On a line by itself, the next line (or the block it opens). Above a fn
//      this ignores the whole function:
//
//        // coverage:ignore
//        fn (e Foo) pstr(params map[string]Value) string {
//
//   3. At the end of any other line, just that line.
//
// A `// coverage:ignore-line` comment ignores only the line it's on, even if
// that line opens a block (such as a `for` with an `or` that can't happen).
//
// A `// coverage:ignore-file` comment anywhere in a file ignores the whole file.
import os

const marker = '// coverage:ignore'
const line_marker = '// coverage:ignore-line'
const file_marker = '// coverage:ignore-file'

struct FileCoverage {
	path string
mut:
	// hits is the hit count for each point, by line number.
	hits    map[int]int
	ignored int
}

fn (f FileCoverage) covered() int {
	return f.hits.values().filter(it > 0).len
}

fn (f FileCoverage) percent() f64 {
	if f.hits.len == 0 {
		return 100
	}

	return 100 * f64(f.covered()) / f64(f.hits.len)
}

fn relative(path string) string {
	return path.replace(os.getwd() + os.path_separator, '')
}

// code_of returns the part of a line that is code, with comments and the
// contents of string and rune literals removed so that braces can be counted.
fn code_of(line string) string {
	mut out := []u8{}
	mut quote := u8(0)
	for i := 0; i < line.len; i++ {
		c := line[i]
		if quote != 0 {
			if c == `\\` {
				i++
			} else if c == quote {
				quote = 0
			}
			continue
		}
		if c == `'` || c == `"` || c == `\`` {
			quote = c
			continue
		}
		if c == `/` && i + 1 < line.len && line[i + 1] == `/` {
			break
		}
		out << c
	}

	return out.bytestr().trim_space()
}

// ignored_lines returns the (1-based) line numbers excluded by markers.
fn ignored_lines(lines []string) map[int]bool {
	mut ignored := map[int]bool{}
	if lines.any(it.contains(file_marker)) {
		for i in 1 .. lines.len + 1 {
			ignored[i] = true
		}
		return ignored
	}

	for i, line in lines {
		if line.contains(line_marker) {
			ignored[i + 1] = true
			continue
		}
		if !line.contains(marker) {
			continue
		}

		mut start := i
		if code_of(line) == '' {
			start = i + 1
			for start < lines.len && lines[start].trim_space() == '' {
				start++
			}
		}
		if start >= lines.len {
			continue
		}

		// The block ends at the line that closes it, even if that line opens
		// another block, like "} else {".
		mut end := start
		if code_of(lines[start]).ends_with('{') {
			mut depth := 1
			outer: for end = start + 1; end < lines.len; end++ {
				for c in code_of(lines[end]) {
					if c == `{` {
						depth++
					} else if c == `}` {
						depth--
						if depth == 0 {
							break outer
						}
					}
				}
			}
		}

		for n in start .. end + 1 {
			ignored[n + 1] = true
		}
	}

	return ignored
}

fn main() {
	if os.args.len != 3 {
		eprintln('usage: coverage-report.vsh <in.lcov> <out.lcov>')
		exit(1)
	}

	mut files := []FileCoverage{}
	for line in os.read_lines(os.args[1])! {
		if line.starts_with('SF:') {
			files << FileCoverage{
				path: line[3..]
			}
		} else if line.starts_with('DA:') {
			parts := line[3..].split(',')
			files[files.len - 1].hits[parts[0].int()] = parts[1].int()
		}
	}

	mut lcov := []string{}
	mut uncovered := []string{}
	mut total_points, mut total_covered, mut total_ignored := 0, 0, 0
	for mut f in files {
		source := os.read_lines(f.path)!
		ignored := ignored_lines(source)
		for line_number in f.hits.keys() {
			if ignored[line_number] {
				f.hits.delete(line_number)
				f.ignored++
			}
		}

		mut line_numbers := f.hits.keys()
		line_numbers.sort()
		lcov << 'SF:${f.path}'
		for line_number in line_numbers {
			lcov << 'DA:${line_number},${f.hits[line_number]}'
			if f.hits[line_number] == 0 {
				uncovered << '${relative(f.path)}:${line_number}\t${source[line_number - 1].trim_space()}'
			}
		}
		lcov << 'LH:${f.covered()}'
		lcov << 'LF:${f.hits.len}'
		lcov << 'end_of_record'

		total_points += f.hits.len
		total_covered += f.covered()
		total_ignored += f.ignored
	}
	os.write_lines(os.args[2], lcov)!

	files.sort(a.percent() < b.percent())
	println('')
	for f in files {
		if f.covered() < f.hits.len {
			println('${relative(f.path):-60} ${f.covered():5}/${f.hits.len:-5} ${f.percent():6.2f}%')
		}
	}
	println('')
	println('Not covered:')
	for line in uncovered {
		println('  ${line}')
	}
	println('')
	println('${total_covered}/${total_points} points covered (${100 * f64(total_covered) / f64(total_points):.2f}%), ${total_ignored} ignored')
	println('LCOV written to ${os.args[2]}')

	if total_covered < total_points {
		exit(1)
	}
}
