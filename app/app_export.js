// app_export.js is embedded in the page of an EXPORT tab of "vsql app". The
// server builds the command of "vsql out" (see export.v), so it's asked again when
// anything changes.

{
	const root = document.querySelector('.export');
	const form = root.closest('form');
	const command = root.querySelector('.export-command pre');
	const file = root.querySelector('[name="export_file"]');
	const params = root.querySelector('.export-params');

	// Only the options of the chosen format are shown.
	const showFormat = () => {
		const format = root.querySelector('[name="export_format"]:checked').value;
		root.querySelectorAll('[data-formats]').forEach(section => {
			section.hidden = !section.dataset.formats.split(' ').includes(format);
		});
	};

	// Only vsql can have the PUBLIC schema created.
	const compat = root.querySelector('[name="export_compat"]');
	const createPublic = root.querySelector('[name="export_create_public_schema"]');
	const showCompat = () => {
		if (compat) createPublic.disabled = compat.value !== '';
	};

	// Each schema has a checkbox for all of its objects.
	const showSchemas = () => {
		root.querySelectorAll('.export-schema').forEach(schema => {
			const all = schema.querySelector('input.all');
			if (!all) return;
			const objects = [...schema.querySelectorAll('ul input')];
			const chosen = objects.filter(input => input.checked).length;
			all.checked = chosen === objects.length;
			all.indeterminate = chosen > 0 && chosen < objects.length;
		});
	};
	root.querySelectorAll('input.all').forEach(all => all.addEventListener('change', () => {
		all.closest('.export-schema').querySelectorAll('ul input').forEach(input => {
			input.checked = all.checked;
		});
	}));

	// There's an input for each "?", which the server counts.
	const showParams = count => {
		while (params.children.length > count) params.lastElementChild.remove();
		while (params.children.length < count) {
			const number = params.children.length + 1;
			const label = document.createElement('label');
			label.className = 'export-param';
			label.append(`P${number} `);
			const input = document.createElement('input');
			input.name = `export_param:${number}`;
			input.spellcheck = false;
			input.placeholder = 'empty, or \\N for NULL';
			label.append(input);
			params.append(label);
		}
	};

	// The server also saves what's posted, so only one is sent at a time. Otherwise
	// an earlier one could finish last and replace what was typed after it.
	let sending = false;
	let changed = false;
	let updates = 0;
	const update = async () => {
		changed = true;
		if (sending) return;
		sending = true;
		try {
			while (changed) {
				changed = false;
				const body = new URLSearchParams(new FormData(form));
				body.set('export_command', '1');
				const response = await fetch('/', { method: 'POST', body });
				if (changed || !response.ok) continue;
				const preview = await response.json();
				if (changed) continue;
				command.textContent = preview.command;
				if (document.activeElement !== file) file.value = preview.file;
				showParams(preview.param_count);
				root.dataset.updated = String(++updates);
			}
		} finally {
			sending = false;
		}
	};

	root.addEventListener('input', () => {
		showFormat();
		showCompat();
		showSchemas();
		update();
	});

	// Enter would otherwise be the first button of the form, which is a tab.
	root.addEventListener('keydown', e => {
		if (e.key === 'Enter' && e.target.tagName === 'INPUT') e.preventDefault();
	});

	root.querySelector('.copy-command').addEventListener('click', () => {
		navigator.clipboard.writeText(command.textContent);
	});

	showFormat();
	showCompat();
	showSchemas();
}
