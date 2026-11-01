// app_history.js is embedded in the page of "vsql app" after app_highlight.js and
// the result. It highlights the queries in the history.
document.querySelectorAll('.history-list pre').forEach(sql => { sql.innerHTML = toHtml(sql.textContent); });

// The history tab and popup are searched as it's typed, in the SQL and its
// outcome.
document.querySelectorAll('.history-search').forEach(search => {
	const parent = search.parentElement;
	const entries = parent.querySelectorAll('.history-list li');
	search.addEventListener('input', () => {
		const text = search.value.trim().toLowerCase();
		let shown = 0;
		entries.forEach(entry => {
			entry.hidden = !entry.textContent.toLowerCase().includes(text);
			if (!entry.hidden) shown++;
		});
		parent.querySelector('.history-no-match').hidden = shown > 0;
	});
});

// The history is a popup of the queries run in the tab, the latest first.
// Choosing one puts it in the editor without running it.
const historyDialog = document.querySelector('dialog.history');
if (historyDialog) {
	// It opens with all of the queries, ready to search.
	document.querySelector('button.show-history').addEventListener('click', () => {
		const search = historyDialog.querySelector('.history-search');
		search.value = '';
		search.dispatchEvent(new Event('input'));
		historyDialog.showModal();
		search.focus();
	});
	historyDialog.querySelector('.close').addEventListener('click', () => historyDialog.close());
	historyDialog.querySelectorAll('li button').forEach(button => {
		const text = button.querySelector('pre').textContent;
		button.addEventListener('click', () => {
			textarea.value = text;
			textarea.dispatchEvent(new Event('input'));
			historyDialog.close();
			textarea.focus();
		});
	});
}
