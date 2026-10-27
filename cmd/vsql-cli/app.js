// app.js is embedded in the page of "vsql app". It highlights the editor
// (reservedWords is set before it), runs the query with Ctrl+Enter, and changes
// the rows of an editable result (see app_edit.v).

const textarea = document.querySelector('.editor textarea');
const pre = document.querySelector('.editor pre');
const escape = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const tokens = /(--[^\n]*)|('(?:[^']|'')*'?)|("(?:[^"]|"")*"?)|(\b\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)|([A-Za-z_][A-Za-z0-9_]*)/g;
function toHtml(text) {
	let html = '', last = 0, m;
	tokens.lastIndex = 0;
	while ((m = tokens.exec(text)) !== null) {
		html += escape(text.slice(last, m.index));
		const t = escape(m[0]);
		if (m[1]) html += '<span class=com>' + t + '</span>';
		else if (m[2]) html += '<span class=str>' + t + '</span>';
		else if (m[4]) html += '<span class=num>' + t + '</span>';
		else if (m[5] && reservedWords.has(m[5].toUpperCase())) html += '<span class=kw>' + t + '</span>';
		else html += t;
		last = tokens.lastIndex;
	}
	return html + escape(text.slice(last));
}
function highlight() {
	// A trailing newline needs a line after it to keep the same height.
	pre.innerHTML = toHtml(textarea.value) + '\n';
	pre.scrollTop = textarea.scrollTop;
}
textarea.addEventListener('input', highlight);
textarea.addEventListener('scroll', () => { pre.scrollTop = textarea.scrollTop; });
new ResizeObserver(() => { pre.style.height = textarea.offsetHeight + 'px'; }).observe(textarea);
textarea.addEventListener('keydown', e => {
	if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); textarea.form.submit(); }
});
highlight();

// The change to be confirmed.
const confirmSql = document.querySelector('.confirm pre');
if (confirmSql) confirmSql.innerHTML = toHtml(confirmSql.textContent);

// A change to a row is posted with the table, and the primary key of the row
// (data-key) for an update or delete. The server shows the statement to be
// confirmed before it's run.
const editable = document.querySelector('table.editable');
function postChange(change, fields) {
	const form = document.createElement('form');
	form.method = 'post';
	form.action = '/';
	const all = [['tab', textarea.form.tab.value], ['change', change],
		['schema', editable.dataset.schema], ['table', editable.dataset.table], ...fields];
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
if (editable) {
	// Double-click a cell to edit it, then Enter to update it (or the NULL
	// button) or Escape to cancel. A BOOLEAN is chosen from its values.
	editable.addEventListener('dblclick', e => {
		const td = e.target.closest('td[data-column]');
		if (!td || td.querySelector('input, select')) return;
		const html = td.innerHTML, column = td.dataset.column, tr = td.parentElement;
		const cancel = () => { td.innerHTML = html; };
		if (td.hasAttribute('data-boolean')) {
			const select = document.createElement('select');
			for (const value of ['UNKNOWN', 'TRUE', 'FALSE']) select.add(new Option(value));
			select.value = ['TRUE', 'FALSE'].includes(td.textContent) ? td.textContent : 'UNKNOWN';
			select.addEventListener('change', () => postChange('update', [...keyFields(tr), ['value:' + column, select.value]]));
			select.addEventListener('keydown', e => { if (e.key === 'Escape') cancel(); });
			select.addEventListener('blur', cancel);
			td.textContent = '';
			td.append(select);
			select.focus();
			return;
		}
		const input = document.createElement('input');
		input.value = td.classList.contains('null') ? '' : td.textContent;
		input.spellcheck = false;
		const setNull = document.createElement('button');
		setNull.type = 'button';
		setNull.className = 'null';
		setNull.textContent = 'NULL';
		setNull.title = 'Set to NULL';
		setNull.addEventListener('mousedown', e => e.preventDefault());
		setNull.addEventListener('click', () => postChange('update', [...keyFields(tr), ['null:' + column, '1']]));
		input.addEventListener('keydown', e => {
			if (e.key === 'Enter') postChange('update', [...keyFields(tr), ['value:' + column, input.value]]);
			else if (e.key === 'Escape') cancel();
		});
		input.addEventListener('blur', cancel);
		td.textContent = '';
		td.append(input, setNull);
		input.focus();
		input.select();
	});
	editable.addEventListener('click', e => {
		if (e.target.matches('button.delete')) postChange('delete', keyFields(e.target.closest('tr')));
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
