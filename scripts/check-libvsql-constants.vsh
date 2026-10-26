#!/usr/bin/env -S v

// check-libvsql-constants.vsh checks that each constant in libvsql/libvsql.h
// (#define SQL_...) has a constant with the same value in libvsql/*.v
// (const sql_...), and the other way around, since C programs only see the
// header.
import os

fn main() {
	mut c_consts := map[string]string{}
	for line in os.read_lines('libvsql/libvsql.h')! {
		if line.starts_with('#define SQL_') {
			fields := line.fields()
			c_consts[fields[1].to_lower()] = fields[2].trim('()').trim_right('L')
		}
	}

	mut v_consts := map[string]string{}
	for path in os.glob('libvsql/*.v')! {
		for line in os.read_lines(path)! {
			if line.starts_with('const sql_') {
				name := line.all_after('const ').all_before(' ')
				v_consts[name] = line.all_after('= ').trim_string_left('i16(').trim_right(')')
			}
		}
	}

	mut errors := 0
	for name, value in v_consts {
		if name !in c_consts {
			println('${name.to_upper()} is missing from libvsql.h')
			errors++
		} else if c_consts[name] != value {
			println('${name.to_upper()} is ${c_consts[name]} in libvsql.h, but ${value} in V')
			errors++
		}
	}
	for name, _ in c_consts {
		if name !in v_consts {
			println('${name.to_upper()} is missing from libvsql/*.v')
			errors++
		}
	}

	println('${c_consts.len} constants, ${errors} errors')
	if errors > 0 {
		exit(1)
	}
}
