// app_create_table.js is embedded in the page of "vsql app" for a CREATE_TABLE
// tab (see create_table.v), after app_columns.js. It builds the schema, table
// name and columns from the payload, and the CREATE TABLE from them as they
// change, which Create table runs.

{
	const root = document.querySelector('.create-table');
	const state = JSON.parse(root.dataset.payload);
	const schemaInput = root.querySelector('.table-schema input');
	const nameInput = root.querySelector('.table-name input');

	function toSql() {
		const lines = state.columns.map(column => '  ' + columnSql(column));
		const key = state.columns.filter(column => column.primary_key).map(column => toName(column.name));
		if (key.length) lines.push('  PRIMARY KEY (' + key.join(', ') + ')');
		return 'CREATE TABLE ' + toName(state.schema) + '.' + toName(state.name) + ' (\n' + lines.join(',\n') + '\n)';
	}

	// A table needs a schema, a name, and at least one column.
	const update = tableEditor(root, state, {
		toSql,
		posted: sql => ({ create_sql: sql, created_table: toName(state.schema) + '.' + toName(state.name) }),
		ready: () => state.schema.trim() !== '' && state.name.trim() !== '' && state.columns.length > 0,
	});

	schemaInput.value = state.schema;
	schemaInput.addEventListener('input', () => { state.schema = schemaInput.value; update(); });
	nameInput.value = state.name;
	nameInput.addEventListener('input', () => { state.name = nameInput.value; update(); });
}
