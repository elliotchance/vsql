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
	// of the query. It's the query that's sorted, not the rows that are shown:
	// the ORDER BY at the end of the query is changed, and it's run again. A query
	// that has its own ORDER BY, FETCH, OFFSET or LIMIT is sorted as a subquery,
	// which is taken away again when it's back to its own order. A column
	// without a name (such as COL1) can't be sorted, since ORDER BY can't refer
	// to it.
	const editor = document.querySelector('.editor textarea');
	const sortClause = /\s+ORDER\s+BY\s+("(?:[^"]|"")+")(\s+DESC)?$/i;
	const subquery = /^SELECT \* FROM \(\n([\s\S]*)\n\) AS sorted$/;
	const quote = name => '"' + name.replace(/"/g, '""') + '"';
	// sortedBy is the column and direction of the ORDER BY at the end of sql,
	// if it's one that clicking a column makes.
	const sortedBy = sql => {
		const match = sql.match(sortClause);
		return match && { name: match[1].slice(1, -1).replace(/""/g, '"'), desc: match[2] !== undefined };
	};
	// hasOwnOrder is true if sql (without its strings and comments) has an
	// ORDER BY, FETCH, OFFSET or LIMIT, which another ORDER BY can't follow.
	const hasOwnOrder = sql => /\b(ORDER\s+BY|FETCH|OFFSET|LIMIT)\b/i.test(
		sql.replace(/'(?:[^']|'')*'|"(?:[^"]|"")*"|--[^\n]*|\/\*[\s\S]*?\*\//g, ' '));
	const query = () => editor.value.replace(/[\s;]+$/, '');
	const current = sortedBy(query());
	if (current) {
		for (const th of resultTable.tHead.rows[0].cells) {
			const name = th.querySelector('.name');
			if (name && name.textContent === current.name) th.setAttribute('aria-sort', current.desc ? 'descending' : 'ascending');
		}
	}
	resultTable.tHead.addEventListener('click', e => {
		const th = e.target.closest('th');
		if (!th || th.classList.contains('row-actions') || th.hasAttribute('data-unnamed') || resultTable.classList.contains('editing')) return;
		const name = th.querySelector('.name').textContent;
		let sql = query();
		const sorted = sortedBy(sql);
		if (sorted) {
			sql = sql.replace(sortClause, '');
		} else if (hasOwnOrder(sql)) {
			sql = `SELECT * FROM (\n${sql}\n) AS sorted`;
		}
		if (!sorted || sorted.name !== name) {
			sql += ` ORDER BY ${quote(name)}`;
		} else if (!sorted.desc) {
			sql += ` ORDER BY ${quote(name)} DESC`;
		} else {
			sql = sql.replace(subquery, '$1');
		}
		editor.value = sql;
		editor.form.submit();
	});
}
