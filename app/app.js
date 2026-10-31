// app.js is embedded in the page of "vsql app" with a tab, after
// app_highlight.js. It highlights the editor and runs the query with
// Ctrl+Enter.

const textarea = document.querySelector('.editor textarea');
const pre = document.querySelector('.editor pre');
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
