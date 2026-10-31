// app_highlight.js is embedded in the page of "vsql app" first (reservedWords
// is set before it). toHtml highlights SQL, for the editor (see app.js) and the
// SQL in popups and tabs. toName is a name that's entered as it's used in SQL.

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

// toName is a name (as it's entered) in SQL. A name in double quotes (such
// as "foo") is used as it is, so it keeps its case. Otherwise it's upper
// case, like a regular identifier, and quoted if it's a reserved word or
// has other characters.
function toName(name) {
	if (name.length > 1 && name.startsWith('"') && name.endsWith('"')) return name;
	const upper = name.toUpperCase();
	return /^[A-Z_][A-Z0-9_]*$/.test(upper) && !reservedWords.has(upper)
		? upper : '"' + upper.replace(/"/g, '""') + '"';
}
