// app_demo.js is embedded in the page of "vsql app" while it's choosing demo data.
// Choosing what to load shows its description and its schema name. Load downloads
// the file, which is then posted like a file on an IMPORT tab.

{
	const root = document.querySelector('.demo-data');
	const form = root.closest('form');
	const select = root.querySelector('[name="demo"]');
	const schema = root.querySelector('[name="demo_schema"]');
	const text = root.querySelector('[name="demo_text"]');
	const message = root.querySelector('.demo-message');
	const load = root.querySelector('.demo-load');
	const label = load.textContent;
	const update = () => {
		load.disabled = !/^[A-Za-z_][A-Za-z0-9_]*$/.test(schema.value.trim());
	};
	select.addEventListener('change', () => {
		root.querySelectorAll('[data-demo]').forEach(description => {
			description.hidden = description.dataset.demo !== select.value;
		});
		schema.value = select.selectedOptions[0].dataset.schema;
		update();
	});
	schema.addEventListener('input', update);
	// Enter would otherwise be the first button of the form, which is a tab.
	schema.addEventListener('keydown', e => {
		if (e.key === 'Enter') e.preventDefault();
	});

	// download is the text of the file, and shows how much has arrived.
	const download = async url => {
		const response = await fetch(url);
		if (!response.ok) throw new Error(`HTTP ${response.status}`);
		const decoder = new TextDecoder();
		const reader = response.body.getReader();
		let result = '';
		let bytes = 0;
		for (;;) {
			const { done, value } = await reader.read();
			if (done) return result + decoder.decode();
			result += decoder.decode(value, { stream: true });
			bytes += value.length;
			load.textContent = `Downloading... ${Math.round(bytes / 1024)} KB`;
		}
	};

	let downloaded = false;
	form.addEventListener('submit', async e => {
		if (e.submitter !== load || downloaded) return;
		e.preventDefault();
		const url = select.selectedOptions[0].dataset.url;
		message.hidden = true;
		load.disabled = true;
		load.textContent = 'Downloading...';
		try {
			text.value = (await download(url)).replace(/^\uFEFF/, '');
		} catch (error) {
			message.textContent = `${url} could not be downloaded: ${error.message}`;
			message.hidden = false;
			load.textContent = label;
			update();
			return;
		}
		text.disabled = false;
		downloaded = true;
		form.requestSubmit(load);
	});
	update();
}
