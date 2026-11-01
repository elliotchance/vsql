// app_edit.js is embedded in the page of "vsql app" after app.js and the
// result. It changes the rows of an editable result (see edit.v).
//
// The result can't be changed until Edit is chosen. Then the changes are only
// collected and shown in the table: an inserted row is green, an updated row is
// yellow and a deleted row is red. Saving runs all of them in one transaction.
//
// While editing, each cell shows its value as it's entered: empty is the DEFAULT
// (it's not set), \N is NULL and "" is an empty string.
const editable = document.querySelector('table.editable');
if (editable) {
	const editButton = document.querySelector('button.edit');
	const cancelButton = document.querySelector('button.cancel-edit');
	const hint = document.querySelector('.edit-hint');
	const nullText = '\\N', emptyText = '""';
	const tbody = editable.tBodies[0];
	const columns = [...editable.tHead.rows[0].cells].slice(1);
	let editing = false, saving = false, savedRows = '', errorMessage = null;
	// cells has the original and current text of each cell that's been looked
	// at.
	const cells = new Map();
	// openCell is the cell with an input, with close() and its td, or null.
	let openCell = null;

	const isInserted = td => td.parentElement.classList.contains('inserted');
	function cell(td) {
		if (!cells.has(td)) {
			const text = isInserted(td) ? ''
				: td.hasAttribute('data-boolean') ? td.textContent
				: td.classList.contains('null') ? nullText
				: td.textContent === '' ? emptyText
				: td.textContent;
			cells.set(td, { original: text, text });
		}
		return cells.get(td);
	}
	const isChanged = td => cell(td).text !== cell(td).original;
	// isMissing is a NOT NULL column without a DEFAULT that has no value.
	const isMissing = td => cell(td).text === '' && columns[td.cellIndex - 1].hasAttribute('data-required');
	function showCell(td) {
		const text = cell(td).text;
		td.textContent = isMissing(td) ? 'required' : text === '' ? 'DEFAULT' : text;
		td.classList.toggle('missing', isMissing(td));
		td.classList.toggle('null', text === '' || text === nullText || text === emptyText || (td.hasAttribute('data-boolean') && text === 'UNKNOWN'));
	}

	// changes is every row to change, in the order they are run: a row can be
	// deleted, and another inserted with the same key.
	function changes() {
		const found = { delete: [], update: [], insert: [] };
		for (const tr of tbody.rows) {
			const changed = [...tr.querySelectorAll('td[data-column]')].filter(isChanged);
			if (tr.classList.contains('deleted')) found.delete.push({ change: 'delete', tr, changed: [] });
			else if (tr.classList.contains('inserted')) found.insert.push({ change: 'insert', tr, changed });
			else if (changed.length > 0) found.update.push({ change: 'update', tr, changed });
		}
		return [...found.delete, ...found.update, ...found.insert];
	}
	// refresh shows what will be saved: the highlight and button of each row,
	// and the save button, so it's always correct before it's clicked. A row
	// that's changed has a yellow button to go back to how it was.
	function refresh() {
		const all = changes();
		for (const tr of tbody.rows) tr.classList.remove('updated');
		for (const { change, tr } of all) if (change === 'update') tr.classList.add('updated');
		for (const tr of tbody.rows) {
			const button = tr.querySelector('td.row-actions button');
			const undo = tr.classList.contains('deleted') || tr.classList.contains('updated');
			const inserted = tr.classList.contains('inserted');
			button.className = undo || inserted ? 'undo' : 'delete';
			button.textContent = undo ? '\u21ba' : '\u00d7';
			button.title = undo ? 'Undo' : inserted ? 'Remove' : 'Delete';
		}
		editButton.classList.toggle('save', all.length > 0);
		editButton.textContent = !editing ? 'Edit...'
			: all.length === 0 ? 'Cancel edit'
			: `Save ${all.length} ${all.length === 1 ? 'change' : 'changes'}`;
		cancelButton.hidden = all.length === 0;
		hint.hidden = !editing;
	}

	// open puts an input over a cell, so the table doesn't move. Each key
	// changes the value, Enter finishes with it and Escape puts it back. Tab
	// goes to the next cell.
	function open(td) {
		if (openCell) openCell.close();
		const c = cell(td), before = c.text;
		let control;
		if (td.hasAttribute('data-boolean')) {
			control = document.createElement('select');
			control.add(new Option('DEFAULT', ''));
			for (const value of ['UNKNOWN', 'TRUE', 'FALSE']) control.add(new Option(value));
		} else {
			control = document.createElement('input');
			control.spellcheck = false;
		}
		control.value = c.text;
		control.classList.add('cell-control');
		const showMissing = () => {
			td.classList.toggle('missing', isMissing(td));
			control.placeholder = isMissing(td) ? 'required' : 'DEFAULT';
		};
		showMissing();
		control.addEventListener('input', () => {
			c.text = control.value;
			showMissing();
			refresh();
		});
		const close = () => {
			if (openCell?.td !== td) return;
			openCell = null;
			showCell(td);
			refresh();
		};
		control.addEventListener('blur', close);
		control.addEventListener('keydown', e => {
			if (e.key === 'Enter') {
				e.preventDefault();
				close();
			} else if (e.key === 'Escape') {
				c.text = before;
				close();
			} else if (e.key === 'Tab') {
				const all = [...tbody.querySelectorAll('tr:not(.deleted) td[data-column]')];
				const next = all[all.indexOf(td) + (e.shiftKey ? -1 : 1)];
				if (next) {
					e.preventDefault();
					open(next);
				}
			}
		});
		td.append(control);
		openCell = { td, close };
		control.focus();
		if (control.select) control.select();
	}

	// addRow adds a row to be inserted. It doesn't need any values, they might
	// all be DEFAULT or generated.
	function addRow() {
		const tr = tbody.insertRow();
		tr.className = 'inserted';
		const actions = tr.insertCell();
		actions.className = 'row-actions';
		actions.innerHTML = '<button type="button" class="delete" title="Remove">&times;</button>';
		for (const th of columns) {
			const td = tr.insertCell();
			if (th.hasAttribute('data-column')) {
				td.dataset.column = th.dataset.column;
				if (th.hasAttribute('data-boolean')) td.setAttribute('data-boolean', '');
				showCell(td);
			} else {
				td.className = 'null';
				td.textContent = 'generated';
			}
		}
		const first = tr.querySelector('td[data-column]');
		if (first) open(first);
		refresh();
	}

	function showError(message) {
		if (!errorMessage) {
			errorMessage = document.createElement('p');
			errorMessage.className = 'error';
			editable.before(errorMessage);
		}
		errorMessage.textContent = message;
	}
	function clearError() {
		if (errorMessage) errorMessage.remove();
		errorMessage = null;
	}

	// save posts every change (see build_change), each with its number. If it
	// fails nothing was changed, so they are kept to try again.
	async function save() {
		if (openCell) openCell.close();
		const fields = [['tab', textarea.form.tab.value], ['catalog', editable.dataset.catalog],
			['schema', editable.dataset.schema], ['table', editable.dataset.table]];
		const all = changes();
		fields.push(['changes', all.length]);
		all.forEach(({ change, tr, changed }, i) => {
			fields.push([`${i}:change`, change]);
			if (change !== 'insert') {
				for (const [name, value] of Object.entries(JSON.parse(tr.dataset.key))) fields.push([`${i}:key:${name}`, value]);
			}
			for (const td of changed) {
				const text = cell(td).text;
				fields.push(text === nullText ? [`${i}:null:${td.dataset.column}`, '1']
					: text === '' ? [`${i}:default:${td.dataset.column}`, '1']
					: [`${i}:value:${td.dataset.column}`, text === emptyText ? '' : text]);
			}
		});

		editButton.disabled = true;
		try {
			const response = await fetch('/', { method: 'POST', body: new URLSearchParams(fields) });
			const body = await response.text();
			if (response.redirected) {
				saving = true;
				location.href = '/';
				return;
			}
			showError(response.ok
				? new DOMParser().parseFromString(body, 'text/html').querySelector('main .error')?.textContent
				: body);
		} catch (err) {
			showError(err.message);
		} finally {
			editButton.disabled = false;
		}
	}

	function cancel() {
		if (openCell) openCell.close();
		tbody.innerHTML = savedRows;
		cells.clear();
		clearError();
		editing = false;
		editable.classList.remove('editing');
		refresh();
	}

	editButton.addEventListener('click', () => {
		if (!editing) {
			savedRows = tbody.innerHTML;
			editing = true;
			editable.classList.add('editing');
			tbody.querySelectorAll('td[data-column]').forEach(showCell);
			refresh();
		} else if (changes().length === 0) {
			cancel();
		} else {
			clearError();
			save();
		}
	});
	cancelButton.addEventListener('click', cancel);
	editable.addEventListener('click', e => {
		if (!editing) return;
		if (e.target.matches('button.add')) return addRow();
		if (e.target.matches('td.row-actions button')) {
			const tr = e.target.closest('tr');
			if (openCell) openCell.close();
			if (tr.classList.contains('inserted')) {
				tr.remove();
			} else if (tr.classList.contains('updated')) {
				for (const td of tr.querySelectorAll('td[data-column]')) {
					cell(td).text = cell(td).original;
					showCell(td);
				}
			} else {
				tr.classList.toggle('deleted');
			}
			return refresh();
		}
		const td = e.target.closest('td[data-column]');
		if (td && td !== openCell?.td && !td.closest('tr.deleted')) open(td);
	});
	// Running the query or changing tabs would lose the changes.
	window.addEventListener('beforeunload', e => {
		if (!saving && changes().length > 0) e.preventDefault();
	});
}
