module main

import cli
import vsql

fn register_out_command(mut cmd cli.Command) {
	mut out_cmd := cli.Command{
		name: 'out'
		usage: '<file>'
		required_args: 1
		description: 'Export schema and data'
		execute: out_command
	}

	out_cmd.add_flag(cli.Flag{
		flag: .bool
		name: 'create-public-schema'
		description: 'Include "CREATE SCHEMA PUBLIC"'
	})

	cmd.add_command(out_cmd)
}

fn out_command(cmd cli.Command) ! {
	mut db := vsql.open(cmd.args[0]) or { return err }

	// To make the output more deterministic the schemas and tables will ordered
	// by name. This is not true for the records however, which can potentially
	// come out in any order.
	mut schemas := db.schemas() or { return err }

	schemas.sort(a.name > b.name)

	for _, schema in schemas {
		// We avoid "CREATE SCHEMA PUBLIC;" because it would break the import.
		// Although, `-create-public-schema` can be used to enable it when
		// dealing with other databases.
		if schema.name == 'PUBLIC' && cmd.flags.get_bool('create-public-schema') or { false } {
			println('${schema}\n')
		}

		mut tables := db.schema_tables(schema.name) or { return err }

		tables.sort(a.name > b.name)

		for _, table in tables {
			println('${table}\n')

			for row in db.query('SELECT * FROM ${table.name}')! {
				mut data := []string{}
				for col in table.column_names() {
					data << (row.get(col)!).str()
				}

				println('INSERT INTO ${table.name} (${table.column_names().join(', ')}) VALUES (${data.join(', ')});')
			}

			println('')
		}
	}
}
