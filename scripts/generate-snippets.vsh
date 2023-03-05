#!/usr/bin/env -S v

// Run from the repo root: $ ./scripts/generate-snippets.vsh

import os

fn main() {
	root_dir := 'vsql'
	mut snippets := {
		'br': '.. |br| raw:: html

   <br>
'
	}

	mut v_files := os.walk_ext(root_dir, '.v')
	v_files.sort()
	for v_file in v_files {
		mut snippet := []string{}
		for line in os.read_lines(v_file)! {
			if line.trim_space().starts_with('//') {
				snippet << line.trim_space()[2..].trim_space()
			} else if snippet.len > 0 {
				if snippet.last().starts_with('snippet:') {
					snippet_name := snippet.last().split(':')[1].trim_space()
					middle := snippet#[0..-2].map(if it.len > 0 { it } else { '|br| |br|' })
					block := '   ' + middle.join('\n   ') + '\n'
					snippets[snippet_name] = '.. |${snippet_name}| replace::\n${block}'
				}
				snippet.clear()
			}
		}
	}

	mut names := snippets.keys()
	names.sort()
	for name in names {
		println(snippets[name])
	}
}
