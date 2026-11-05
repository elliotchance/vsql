// app_result.js is embedded in the page of "vsql app" after app.js and the result,
// and before app_edit.js. It shows a long value and sorts the rows of a result.

const maxCellLength = 50;
const resultTable = document.querySelector('table.result');
// editCell reads and changes the text of a cell while the rows are being edited
// (see app_edit.js), otherwise it's null.
let editCell = null;

// showCellText shows a value in a cell. If it's long, it's the start of the value
// with a button to see all of it.
function showCellText(td, text) {
	const chars = [...text];
	if (chars.length <= maxCellLength) {
		td.textContent = text;
		return;
	}
	td.textContent = chars.slice(0, maxCellLength).join('') + '...';
	const button = document.createElement('button');
	button.type = 'button';
	button.className = 'expand';
	button.title = 'Show the full value';
	button.setAttribute('aria-label', 'Show the full value');
	button.innerHTML = '&#128269;';
	td.append(button);
}

if (resultTable) {
	const dialog = document.querySelector('dialog.cell-value');
	const area = dialog.querySelector('textarea');
	const copy = dialog.querySelector('button.copy');
	const done = dialog.querySelector('button.create');
	const close = dialog.querySelector('button.keep');
	let valueCell = null;

	resultTable.querySelectorAll('td[data-full]').forEach(td => showCellText(td, td.dataset.full));

	// The value can always be selected and copied. It can only be changed while
	// editing, and only if the cell can be edited.
	function showValue(td) {
		valueCell = td;
		const canChange = editCell && td.hasAttribute('data-column') && !td.closest('tr.deleted');
		area.value = editCell && td.hasAttribute('data-column') ? editCell.text(td) : td.dataset.full;
		area.readOnly = !canChange;
		done.hidden = !canChange;
		close.textContent = canChange ? 'Cancel' : 'Close';
		copy.textContent = 'Copy';
		const th = resultTable.tHead.rows[0].cells[td.cellIndex];
		dialog.querySelector('.confirm-file').textContent = th.querySelector('.name').textContent;
		dialog.showModal();
		area.focus();
	}
	copy.addEventListener('click', async () => {
		// The clipboard API is only there for localhost and https.
		area.focus();
		area.select();
		if (navigator.clipboard) await navigator.clipboard.writeText(area.value);
		else document.execCommand('copy');
		copy.textContent = 'Copied';
	});
	done.addEventListener('click', () => {
		editCell.change(valueCell, area.value);
		dialog.close();
	});
	close.addEventListener('click', () => dialog.close());
	resultTable.addEventListener('click', e => {
		const button = e.target.closest('button.expand');
		if (button) showValue(button.closest('td'));
	});

	// Clicking a column sorts by it, then the other way, then back to the order
	// of the query. Only the rows of the result are sorted, not the table, and
	// NULLs are always last. The order is kept on each row, because the rows are
	// put back from their HTML when editing is cancelled.
	const tbody = resultTable.tBodies[0];
	[...tbody.rows].forEach((tr, i) => { tr.dataset.order = i; });
	const sortValue = (td, isNumber) => {
		if (td.classList.contains('null')) return null;
		const text = td.dataset.full ?? td.textContent;
		return isNumber ? Number(text) : text;
	};
	resultTable.tHead.addEventListener('click', e => {
		const th = e.target.closest('th');
		if (!th || th.classList.contains('row-actions') || resultTable.classList.contains('editing')) return;
		const before = th.getAttribute('aria-sort');
		const direction = before === null ? 'ascending' : before === 'ascending' ? 'descending' : null;
		for (const other of th.parentElement.cells) other.removeAttribute('aria-sort');
		const rows = [...tbody.rows];
		if (direction === null) {
			rows.sort((a, b) => a.dataset.order - b.dataset.order);
		} else {
			th.setAttribute('aria-sort', direction);
			const isNumber = th.classList.contains('number');
			const sign = direction === 'ascending' ? 1 : -1;
			const values = new Map(rows.map(tr => [tr, sortValue(tr.cells[th.cellIndex], isNumber)]));
			rows.sort((a, b) => {
				const x = values.get(a), y = values.get(b);
				if (x === null || y === null) return (x === null) - (y === null);
				return x < y ? -sign : x > y ? sign : 0;
			});
		}
		tbody.append(...rows);
	});
}
