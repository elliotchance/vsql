// app_edit.js is embedded in the page of "vsql app" after app.js and the
// result. It changes the rows of an editable result (see edit.v).

// A change to a row is posted with the table, and the primary key of the row
// (data-key) for an update or delete. The server shows the statement to be
// confirmed before it's run.
const editable = document.querySelector('table.editable');
function postChange(change, fields) {
	const form = document.createElement('form');
	form.method = 'post';
	form.action = '/';
	const all = [['tab', textarea.form.tab.value], ['change', change],
		['catalog', editable.dataset.catalog], ['schema', editable.dataset.schema], ['table', editable.dataset.table], ...fields];
	for (const [name, value] of all) {
		const input = document.createElement('input');
		input.type = 'hidden';
		input.name = name;
		input.value = value;
		form.appendChild(input);
	}
	document.body.appendChild(form);
	form.submit();
}
const keyFields = tr => Object.entries(JSON.parse(tr.dataset.key)).map(([k, v]) => ['key:' + k, v]);
// editing is the row being updated, with confirm() and cancel(), or null.
let editing = null;
// editRow makes every column of a row that can be changed an input (a BOOLEAN
// is chosen from its values), and the buttons on the left confirm or cancel.
// Only the columns that are changed are updated. NULL sets a column to NULL,
// until something is typed.
function editRow(tr, focusTd) {
	if (editing) editing.cancel();
	const cells = [...tr.children], saved = cells.map(td => td.innerHTML);
	const fields = [];
	for (const td of tr.querySelectorAll('td[data-column]')) {
		const column = td.dataset.column, text = td.textContent, wasNull = td.classList.contains('null');
		if (td.hasAttribute('data-boolean')) {
			const select = document.createElement('select');
			for (const value of ['UNKNOWN', 'TRUE', 'FALSE']) select.add(new Option(value));
			select.value = text;
			td.textContent = '';
			td.append(select);
			fields.push({ td, control: select, changed: () => select.value !== text,
				entry: () => ['value:' + column, select.value] });
			continue;
		}
		let isNull = wasNull;
		const input = document.createElement('input');
		input.value = wasNull ? '' : text;
		input.placeholder = wasNull ? 'NULL' : '';
		input.spellcheck = false;
		input.addEventListener('input', () => {
			if (isNull && input.value !== '') { isNull = false; input.placeholder = ''; }
		});
		const setNull = document.createElement('button');
		setNull.type = 'button';
		setNull.className = 'null';
		setNull.textContent = 'NULL';
		setNull.title = 'Set to NULL';
		setNull.addEventListener('click', () => {
			isNull = true;
			input.value = '';
			input.placeholder = 'NULL';
			input.focus();
		});
		td.textContent = '';
		td.append(input, setNull);
		fields.push({ td, control: input, changed: () => isNull !== wasNull || (!isNull && input.value !== text),
			entry: () => isNull ? ['null:' + column, '1'] : ['value:' + column, input.value] });
	}
	const actions = tr.querySelector('td.row-actions');
	actions.innerHTML = '<button type="button" class="confirm-row" title="Confirm (Enter)">&#10003;</button>' +
		'<button type="button" class="cancel-row" title="Cancel (Escape)">&times;</button>';
	tr.classList.add('editing');
	editing = {
		tr,
		cancel() {
			cells.forEach((td, i) => { td.innerHTML = saved[i]; });
			tr.classList.remove('editing');
			editing = null;
		},
		// Nothing changed is the same as cancel.
		confirm() {
			const changed = fields.filter(field => field.changed());
			if (changed.length === 0) return this.cancel();
			postChange('update', [...keyFields(tr), ...changed.map(field => field.entry())]);
		},
	};
	const field = fields.find(field => field.td === focusTd) || fields[0];
	field.control.focus();
	if (field.control.select) field.control.select();
}
if (editable) {
	// Double-click a row to update it, then Enter (or the confirm button) to
	// update it or Escape (or the cancel button) to cancel.
	editable.addEventListener('dblclick', e => {
		const tr = e.target.closest('tbody tr[data-key]');
		if (!tr || tr === editing?.tr) return;
		editRow(tr, e.target.closest('td[data-column]'));
	});
	editable.addEventListener('keydown', e => {
		if (!editing || !editing.tr.contains(e.target)) return;
		if (e.key === 'Enter') { e.preventDefault(); editing.confirm(); }
		else if (e.key === 'Escape') editing.cancel();
	});
	editable.addEventListener('click', e => {
		if (e.target.matches('button.delete')) postChange('delete', keyFields(e.target.closest('tr')));
		else if (e.target.matches('button.confirm-row')) editing.confirm();
		else if (e.target.matches('button.cancel-row')) editing.cancel();
	});
	// A column that's left empty (or DEFAULT) is not inserted, so it gets its
	// DEFAULT.
	const insert = () => postChange('insert', [...editable.querySelectorAll('tfoot [data-column]')]
		.filter(input => input.value !== '').map(input => ['value:' + input.dataset.column, input.value]));
	editable.querySelector('button.add').addEventListener('click', insert);
	editable.querySelectorAll('tfoot [data-column]').forEach(input => input.addEventListener('keydown', e => {
		if (e.key === 'Enter') insert();
	}));
}
