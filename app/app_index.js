// app_index.js is embedded in the page of "vsql app" after app_schema.js.
// Create index in the menu of a table opens a popup to choose the columns of
// the index (in the order they're chosen), each ASC or DESC, and its name, with
// the CREATE INDEX that's run in the file of the catalog. Until the name is
// changed, it's made from the names of the table and the columns (other
// characters are replaced with _).

{
	const dialog = document.querySelector('dialog.create-index');
	const input = dialog.querySelector('.index-name input');
	const list = dialog.querySelector('.index-columns ul');
	const create = dialog.querySelector('button.create');
	let table = '', tableName = '', chosen = [], nameChanged = false;
	const update = () => {
		const rows = [...list.children];
		chosen = chosen.filter(row => row.querySelector('input').checked);
		rows.forEach(row => {
			const position = chosen.indexOf(row);
			row.querySelector('.position').textContent = position < 0 ? '' : position + 1;
			row.querySelector('select').disabled = position < 0;
		});
		if (!nameChanged) {
			input.value = chosen.length === 0 ? '' : [tableName, ...chosen.map(row => row.dataset.name)].join('_').replace(/[^A-Za-z0-9_]+/g, '_');
		}
		const columns = chosen.map(row => row.dataset.sql + (row.querySelector('select').value === 'DESC' ? ' DESC' : ''));
		const sql = 'CREATE INDEX ' + toName(input.value) + ' ON ' + table + ' (' + columns.join(', ') + ')';
		dialog.querySelector('pre').innerHTML = toHtml(sql);
		dialog.querySelector('[name="create_index"]').value = sql;
		create.disabled = input.value.trim() === '' || chosen.length === 0;
	};
	input.addEventListener('input', () => { nameChanged = true; update(); });
	list.addEventListener('change', e => {
		const row = e.target.closest('li');
		if (e.target.type === 'checkbox' && e.target.checked) chosen.push(row);
		update();
	});
	document.querySelectorAll('button.create-index').forEach(button => button.addEventListener('click', () => {
		dialog.querySelector('[name="create_index_catalog"]').value = button.dataset.catalog;
		dialog.querySelector('.confirm-file').textContent = button.dataset.catalog;
		table = button.dataset.table;
		tableName = button.dataset.tableName;
		chosen = [];
		nameChanged = false;
		list.replaceChildren(...JSON.parse(button.dataset.columns).map(([name, sql]) => {
			const row = document.createElement('li');
			row.dataset.name = name;
			row.dataset.sql = sql;
			row.innerHTML = '<span class="position"></span><label><input type="checkbox"> <span class="name"></span></label><select aria-label="Order"><option>ASC</option><option>DESC</option></select>';
			row.querySelector('.name').textContent = name;
			row.querySelector('select').setAttribute('aria-label', 'Order of ' + name);
			return row;
		}));
		update();
		button.closest('details.menu').open = false;
		dialog.showModal();
		list.querySelector('input')?.focus();
	}));
	dialog.querySelector('button.keep').addEventListener('click', () => dialog.close());
}
