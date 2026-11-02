// app.js is embedded in the page of "vsql app" with an editor, after
// app_highlight.js. It highlights the editor and runs the query with Ctrl+Enter.

const textarea = document.querySelector('.editor textarea');
const pre = document.querySelector('.editor pre');
function highlight() {
	// A trailing newline needs a line after it to keep the same height.
	pre.innerHTML = toHtml(textarea.value) + '\n';
	pre.scrollTop = textarea.scrollTop;
}
// paramCount is the number of "?" that aren't in a comment, string or quoted name.
const paramCount = text => text.replace(/\/\*[\s\S]*?\*\/|--[^\n]*|'(?:[^']|'')*'?|"(?:[^"]|"")*"?/g, '').split('?').length - 1;
// guessType is the type of a "?" from its value, until another is chosen.
function guessType(value) {
	const text = value.trim();
	if (/^(true|false|unknown)$/i.test(text)) return 'boolean';
	if (/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(text)) return 'number';
	if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return 'date';
	if (/^\d{2}:\d{2}:\d{2}/.test(text)) return 'time';
	if (/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}/.test(text)) return 'timestamp';
	return 'text';
}
const guessedTypeNames = { text: 'Text', number: 'Number', boolean: 'Boolean', date: 'Date', time: 'Time', timestamp: 'Timestamp' };
// A type with a value needs an input, the others are the value.
const valueTypes = { text: 'Text', number: 'Number', date: 'Date', time: 'Time', timestamp: 'Timestamp' };
const fixedTypes = { true: 'TRUE', false: 'FALSE', unknown: 'UNKNOWN', null: 'NULL' };
// showParams has the type of each "?" under the editor, with an input if the
// type needs a value. A value
// and type are kept while the "?" is there, and are posted (and saved in the
// tab) with the SQL. The type is posted as "auto:" and the guess until another
// is chosen.
const params = document.querySelector('.params');
const paramValues = JSON.parse(params.dataset.values);
const paramTypes = JSON.parse(params.dataset.types);
function showParams() {
	params.querySelectorAll('label').forEach((label, i) => {
		paramValues[i] = label.querySelector('input').value;
		paramTypes[i] = label.querySelector('select').value;
	});
	const count = paramCount(textarea.value);
	params.hidden = count === 0;
	params.textContent = '';
	for (let i = 0; i < count; i++) {
		const label = document.createElement('label');
		const input = document.createElement('input');
		input.name = 'param:' + (i + 1);
		input.value = paramValues[i] ?? '';
		input.spellcheck = false;
		input.addEventListener('keydown', e => {
			if (e.key === 'Enter') { e.preventDefault(); textarea.form.submit(); }
		});
		const select = document.createElement('select');
		select.name = 'param_type:' + (i + 1);
		const auto = new Option('');
		select.add(auto);
		for (const [type, name] of Object.entries({ ...valueTypes, ...fixedTypes })) select.add(new Option(name, type));
		const guess = () => {
			const type = guessType(input.value);
			auto.value = 'auto:' + type;
			auto.text = `Auto (${guessedTypeNames[type]})`;
		};
		guess();
		const saved = paramTypes[i] ?? auto.value;
		select.value = saved.startsWith('auto:') ? auto.value : saved;
		if (select.selectedIndex < 0) select.selectedIndex = 0;
		// It's still posted when it's hidden, to keep the numbers of the others.
		const showInput = () => { input.hidden = select.value in fixedTypes; };
		showInput();
		input.addEventListener('input', () => {
			const isAuto = select.selectedIndex === 0;
			guess();
			if (isAuto) select.selectedIndex = 0;
		});
		select.addEventListener('change', showInput);
		label.append('?' + (i + 1), select, input);
		params.append(label);
	}
}
textarea.addEventListener('input', highlight);
textarea.addEventListener('input', showParams);
textarea.addEventListener('scroll', () => { pre.scrollTop = textarea.scrollTop; });
new ResizeObserver(() => { pre.style.height = textarea.offsetHeight + 'px'; }).observe(textarea);
textarea.addEventListener('keydown', e => {
	if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); textarea.form.submit(); }
});
highlight();
showParams();
