#!/usr/bin/env -S v

// rewrite_casts replaces each `$1.v as Type` in the grammar actions with
// `yy_as[Type]($1.v)` (see lexer.v). V3 expands every `as` on a sum type into a
// check of each variant (there are about 90), which made the generated parser
// 8.5 MB of C, and slow to compile. A type that is not one of the variants of
// YYSym is too big to be one, so it is kept in a YYBox and read with
// `yy_unbox[Type]($1.v)` instead.
fn rewrite_casts(s string, variants map[string]bool) string {
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
					typ := s[type_start..k]
					f := if typ in variants { 'yy_as' } else { 'yy_unbox' }
					out << '${f}[${typ}](${s[i..j]}.v)'.bytes()
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

// yysym_variants returns the types of the YYSym sum type in lexer.v.
fn yysym_variants(lexer_path string) map[string]bool {
	content := read_file(lexer_path) or {
		eprintln('error: unable to open file ${lexer_path}: ${err}')
		exit(1)
	}
	mut variants := map[string]bool{}
	mut in_type := false
	for line in content.split_into_lines() {
		if line.starts_with('type YYSym = ') {
			in_type = true
			variants[line.all_after('type YYSym = ').trim_space()] = true
			continue
		}
		if in_type {
			if !line.trim_space().starts_with('|') {
				break
			}
			variants[line.trim_space().trim_left('|').trim_space()] = true
		}
	}

	return variants
}

path := abs_path('vsql')
variants := yysym_variants(join_path_single(path, 'lexer.v'))
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
output.writeln(rewrite_casts(middle.trim_space(), variants))!
output.writeln('%%')!
output.write_string(bottom.trim_space())!
output.flush()
output.close()
