#!/usr/bin/env -S v

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
output.writeln(middle.trim_space())!
output.writeln('%%')!
output.write_string(bottom.trim_space())!
output.flush()
output.close()
