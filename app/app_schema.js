// app_schema.js is embedded in the page of "vsql app" after app_highlight.js.
// Create schema in the menu of a catalog opens a popup to enter the name of the
// schema, with the CREATE SCHEMA that's run in the file of the catalog.

{
	const dialog = document.querySelector('dialog.create-schema');
	const input = dialog.querySelector('.schema-name input');
	const create = dialog.querySelector('button.create');
	const update = () => {
		const sql = 'CREATE SCHEMA ' + toName(input.value);
		dialog.querySelector('pre').innerHTML = toHtml(sql);
		dialog.querySelector('[name="create_schema"]').value = sql;
		create.disabled = input.value.trim() === '';
	};
	input.addEventListener('input', update);
	document.querySelectorAll('button.create-schema').forEach(button => button.addEventListener('click', () => {
		dialog.querySelector('[name="create_schema_catalog"]').value = button.dataset.catalog;
		dialog.querySelector('.confirm-file').textContent = button.dataset.catalog;
		input.value = '';
		update();
		button.closest('details.menu').open = false;
		dialog.showModal();
		input.focus();
	}));
	dialog.querySelector('button.keep').addEventListener('click', () => dialog.close());
}
