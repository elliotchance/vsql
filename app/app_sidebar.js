// app_sidebar.js is embedded in the page of "vsql app" directly after the
// sidebar, so its width and collapsed headings and schemas are restored before the page is
// shown. Drag the resizer to change the width. They are kept in the browser.

{
	const sidebar = document.querySelector('.sidebar');
	const resizer = document.querySelector('.resizer');
	const folders = sidebar.querySelectorAll('details[data-folder]');
	const load = (key, fallback) => {
		try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch (e) { return fallback; }
	};
	const save = (key, value) => {
		try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) {}
	};

	const width = load('vsql.sidebar.width', null);
	if (width) sidebar.style.width = width + 'px';
	const collapsed = load('vsql.sidebar.collapsed', []);
	for (const details of folders) {
		if (collapsed.includes(details.dataset.folder)) details.open = false;
		details.addEventListener('toggle', () => save('vsql.sidebar.collapsed',
			[...folders].filter(d => !d.open).map(d => d.dataset.folder)));
	}

	// The width is limited by the min-width and max-width of the sidebar.
	resizer.addEventListener('pointerdown', e => {
		e.preventDefault();
		resizer.setPointerCapture(e.pointerId);
		resizer.classList.add('dragging');
		document.body.classList.add('resizing');
		const left = sidebar.getBoundingClientRect().left;
		const move = e => { sidebar.style.width = (e.clientX - left) + 'px'; };
		resizer.addEventListener('pointermove', move);
		resizer.addEventListener('pointerup', () => {
			resizer.removeEventListener('pointermove', move);
			resizer.classList.remove('dragging');
			document.body.classList.remove('resizing');
			save('vsql.sidebar.width', sidebar.getBoundingClientRect().width);
		}, { once: true });
	});
	// Double-click the resizer to go back to the default width.
	resizer.addEventListener('dblclick', () => {
		sidebar.style.width = '';
		try { localStorage.removeItem('vsql.sidebar.width'); } catch (e) {}
	});
}
