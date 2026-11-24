#!/usr/bin/env -S v

// check-function-index.vsh checks that the table of docs/functions-index.rst
// has one row for each function of the docs/functions-*.rst pages (each
// heading underlined with ^), and the other way around. Each row must link to the function's heading, have a
// description, have the category of its page (the page's title without
// " Functions"), and be in alphabetical order.
import os

struct Row {
	name        string
	page        string
	description string
	category    string
}

fn main() {
	// The functions of each page, and the category of each page.
	mut functions := map[string]string{} // name -> page
	mut categories := map[string]string{} // page -> category
	for path in os.glob('docs/functions-*.rst')! {
		page := os.file_name(path).all_before_last('.rst')
		if page == 'functions-index' {
			continue
		}
		lines := os.read_lines(path)!
		categories[page] = lines[0].trim_string_right(' Functions')
		for i := 0; i + 1 < lines.len; i++ {
			if is_name(lines[i]) && lines[i + 1].len > 0 && lines[i + 1].trim('^') == '' {
				functions[lines[i]] = page
			}
		}
	}

	mut rows := []Row{}
	lines := os.read_lines('docs/functions-index.rst')!
	for i, line in lines {
		if line.starts_with('   * - :ref:`') {
			target := line.all_after('`').all_before_last('`')
			rows << Row{
				name:        target.all_before(' <')
				page:        target.all_after('<').all_before(':')
				description: if i + 1 < lines.len {
					lines[i + 1].trim_string_left('     - ')
				} else {
					''
				}
				category:    if i + 2 < lines.len {
					lines[i + 2].trim_string_left('     - ')
				} else {
					''
				}
			}
		}
	}

	mut errors := []string{}
	mut seen := map[string]bool{}
	for i, row in rows {
		if row.name in seen {
			errors << '${row.name} is in the table more than once'
		}
		seen[row.name] = true
		if row.name !in functions {
			errors << '${row.name} is in the table, but has no heading in docs/functions-*.rst'
			continue
		}
		page := functions[row.name]
		if row.page != page {
			errors << '${row.name} links to ${row.page}, but its heading is in ${page}'
		}
		if row.description == '' || row.description.starts_with('* - ') {
			errors << '${row.name} has no description'
		}
		if row.category != categories[page] {
			errors << '${row.name} has the category "${row.category}", but ${page} is "${categories[page]}"'
		}
		if i > 0 && rows[i - 1].name >= row.name {
			errors << '${row.name} is not in alphabetical order (after ${rows[i - 1].name})'
		}
	}
	mut names := functions.keys()
	names.sort()
	for name in names {
		if name !in seen {
			errors << '${name} (${functions[name]}) is missing from docs/functions-index.rst'
		}
	}

	for e in errors {
		println(e)
	}
	if errors.len > 0 {
		exit(1)
	}
	println('${rows.len} functions')
}

// is_name is a function heading, such as ABS or LOG10.
fn is_name(s string) bool {
	if s.len == 0 || !s[0].is_capital() {
		return false
	}
	for c in s {
		if !c.is_capital() && !c.is_digit() && c != `_` {
			return false
		}
	}
	return true
}
