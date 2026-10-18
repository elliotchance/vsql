#!/usr/bin/env -S v

// rewrite_casts replaces each `$1.v as Type` in the grammar actions with
// `yy_as[Type]($1.v)` (see lexer.v). V3 expands every `as` on a sum type into a
// check of each variant (there are about 90), which made the generated parser
// 8.5 MB of C, and slow to compile.
fn rewrite_casts(s string) string {
	mut out := []u8{cap: s.len}
	mut i := 0
	for i < s.len {
		if s[i] == `$` && i + 1 < s.len && s[i + 1].is_digit() {
			mut j := i + 1
			for j < s.len && s[j].is_digit() {
				j++
			}
			if s[j..].starts_with('.v as ') {
				mut k := j + '.v as '.len
				type_start := k
				// The type may be an array, like []Identifier.
				for s[k..].starts_with('[]') {
					k += 2
				}
				for k < s.len && (s[k].is_letter() || s[k].is_digit() || s[k] == `_`) {
					k++
				}
				if k > type_start {
					out << 'yy_as[${s[type_start..k]}](${s[i..j]}.v)'.bytes()
					i = k
					continue
				}
			}
		}
		out << s[i]
		i++
	}

	return out.bytestr()
}

path := abs_path('vsql')
output_filename := join_path_single(path, 'y.y')
files := glob(join_path_single(path, '*.y')) or { [] }

mut top := ''
mut middle := ''
mut bottom := ''

for file_path in files {
	if is_dir(file_path) {
		continue
	}
	content := read_file(file_path) or {
		eprintln('error: unable to open file ${file_path}: ${err}')
		exit(1)
	}
	parts := content.split('%%')
	if parts.len != 3 {
		eprintln('${file_path}: wrong number of parts (${parts.len})')
		exit(1)
	}
	top += parts[0]
	middle += parts[1]
	bottom += parts[2]
}

mut output := open_file(output_filename, 'w') or {
	eprintln('error: unable to open file to write')
	exit(1)
}

output.writeln(top.trim_space())!
output.writeln('%%')!
output.writeln(rewrite_casts(middle.trim_space()))!
output.writeln('%%')!
output.write_string(bottom.trim_space())!
output.flush()
output.close()
