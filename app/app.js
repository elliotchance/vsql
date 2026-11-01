// app.js is embedded in the page of "vsql app". It highlights the editor
// (reservedWords is set before it) and runs the query with Ctrl+Enter.

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
