// app_schema.js is embedded in the page of "vsql app" after app_highlight.js.
// Create schema in the menu of a catalog opens a popup to enter the name of the
// schema, with the CREATE SCHEMA (in the catalog, with more than one) that's
// run.

{
	const dialog = document.querySelector('dialog.create-schema');
	const input = dialog.querySelector('.schema-name input');
	const create = dialog.querySelector('button.create');
	let prefix = '';
	const update = () => {
		const sql = 'CREATE SCHEMA ' + prefix + toName(input.value);
		dialog.querySelector('pre').innerHTML = toHtml(sql);
		dialog.querySelector('[name="create_schema"]').value = sql;
		create.disabled = input.value.trim() === '';
	};
	input.addEventListener('input', update);
	document.querySelectorAll('button.create-schema').forEach(button => button.addEventListener('click', () => {
		prefix = button.dataset.prefix;
		input.value = '';
		update();
		button.closest('details.menu').open = false;
		dialog.showModal();
		input.focus();
	}));
	dialog.querySelector('button.keep').addEventListener('click', () => dialog.close());
}
