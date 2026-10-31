// app_confirm.js is embedded in the page of "vsql app" when there's a change
// to be confirmed (see Confirm), after app_highlight.js. It's a popup, Escape
// closes it without running it.

{
	const dialog = document.querySelector('dialog.confirm');
	const sql = dialog.querySelector('pre');
	sql.innerHTML = toHtml(sql.textContent);
	dialog.showModal();
}
