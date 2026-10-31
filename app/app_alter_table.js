// app_alter_table.js is embedded in the page of "vsql app" for an ALTER_TABLE
// tab (see alter_table.v), after app_columns.js. The ALTER TABLE statements
// are what's changed from each column's original, which Alter table runs.
//
// A new column can be anything (ADD COLUMN), but only some changes can be made
// to a column that's already there: its NOT NULL removed, its DEFAULT changed,
// whether it's in the PRIMARY KEY, or it can be removed (DROP COLUMN).

{
	const root = document.querySelector('.alter-table');
	const state = JSON.parse(root.dataset.payload);
	const hasIdentity = () => state.columns.some(column => column.original?.auto_increment);

	// locked is a field of a column that can't be changed.
	const locked = (column, field) => {
		const original = column.original;
		if (!original) return field === 'auto_increment' && hasIdentity();
		switch (field) {
		case 'not_null': return !original.not_null || original.not_null_name === '';
		case 'primary_key': return false;
		case 'default': return original.auto_increment || original.generated;
		default: return true;
		}
	};

	// toSql is each change, in an order that works: the PRIMARY KEY is dropped
	// (if it's changed) before its columns, and added after the new columns.
	const toSql = () => {
		const name = column => column.original ? column.original.sql_name : toName(column.name);
		const key = state.columns.filter(column => column.primary_key).map(name);
		const keyChanged = key.join(',') !== state.primary_key.join(',');
		const changes = [];
		if (keyChanged && state.primary_key_name !== '') changes.push('DROP CONSTRAINT ' + state.primary_key_name);
		for (const column of state.columns) {
			if (column.original?.not_null && !column.not_null) changes.push('DROP CONSTRAINT ' + column.original.not_null_name);
		}
		for (const original of state.removed) changes.push('DROP COLUMN ' + original.sql_name);
		for (const column of state.columns) {
			if (!column.original || column.default === column.original.default) continue;
			changes.push('ALTER COLUMN ' + name(column) + (column.default === '' ? ' DROP DEFAULT' : ' SET DEFAULT ' + column.default));
		}
		for (const column of state.columns) {
			if (!column.original) changes.push('ADD COLUMN ' + columnSql(column));
		}
		if (keyChanged && key.length) changes.push('ADD PRIMARY KEY (' + key.join(', ') + ')');
		return changes.map(change => 'ALTER TABLE ' + state.table + ' ' + change + ';').join('\n');
	};

	tableEditor(root, state, {
		toSql,
		posted: sql => ({ alter_sql: sql }),
		ready: sql => sql !== '',
		locked,
		// A column that was already there is dropped.
		remove: i => {
			const [column] = state.columns.splice(i, 1);
			if (column.original) state.removed.push(column.original);
		},
	});
}
