// app_highlight.js is embedded in the page of "vsql app" first (reservedWords
// is set before it). toHtml highlights SQL, for the editor (see app.js) and the
// change to be confirmed (see app_confirm.js).

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
