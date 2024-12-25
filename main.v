module main

import vsql

fn main() {
	vsql.main_() or { panic(err) }
}
