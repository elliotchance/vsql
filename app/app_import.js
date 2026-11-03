// app_import.js is embedded in the page of an IMPORT tab of "vsql app". Choosing a
// file shows an estimate of what's in it (these are just counts of the text, it's
// not parsed), the options for its type and the command of "vsql in". For a new
// table, the columns and types are guessed from the first rows of the file, and can
// be changed. The file is posted by Import.

{
	const root = document.querySelector('.import');
	const form = root.closest('form');
	const schemas = JSON.parse(root.dataset.schemas);
	const fileInput = root.querySelector('.import-file');
	const message = root.querySelector('.import-message');
	const stats = root.querySelector('.import-stats');
	const options = root.querySelector('.import-options');
	const schemaSelect = root.querySelector('[name="import_schema"]');
	const tableSelect = root.querySelector('[name="import_table"]');
	const nameLabel = root.querySelector('.import-new');
	const nameInput = nameLabel.querySelector('input');
	const mapBody = root.querySelector('.import-map tbody');
	const commandBox = root.querySelector('.import-command');
	const command = commandBox.querySelector('pre');
	const submit = root.querySelector('.import-run');
	const field = name => root.querySelector(`[name="${name}"]`);

	let file = null;
	let text = '';
	let format = '';
	let fields = [];
	let types = [];

	const sqlKinds = ['CREATE SCHEMA', 'CREATE TABLE', 'CREATE SEQUENCE', 'CREATE INDEX', 'CREATE UNIQUE INDEX',
		'CREATE VIEW', 'CREATE TRIGGER', 'ALTER TABLE', 'DROP TABLE',
		'INSERT', 'UPDATE', 'DELETE', 'SELECT', 'START TRANSACTION', 'COMMIT', 'ROLLBACK'];

	// sqlCount is how many times a statement seems to start: at the start of a line,
	// or after a semicolon.
	const sqlCount = kind => {
		const pattern = new RegExp(`(?:^|;)\\s*${kind.replace(' ', '\\s+')}\\b`, 'gim');
		return (text.match(pattern) || []).length;
	};

	// sampleRows is how many rows of a file are used to guess the types of a new table.
	const sampleRows = 100;

	// sampleRecords is the values of the first lines of a CSV or TSV file (each can
	// have a line break in quotes), and the first line is the names of the columns.
	// A value is null if it's empty and not quoted, like it is when it's imported.
	const sampleRecords = separator => {
		const records = [];
		let record = [];
		let value = '';
		let quoted = false;
		let wasQuoted = false;
		const endValue = () => {
			record.push(value === '' && !wasQuoted ? null : value);
			value = '';
			wasQuoted = false;
		};
		const endRecord = () => {
			if (record.length > 0 || value !== '' || wasQuoted) {
				endValue();
				if (record.length > 1 || record[0] !== null) records.push(record);
			}
			record = [];
		};
		for (let i = 0; i < text.length && records.length <= sampleRows; i++) {
			const c = text[i];
			if (quoted) {
				if (c === '"' && text[i + 1] === '"') {
					value += '"';
					i++;
				} else if (c === '"') {
					quoted = false;
				} else {
					value += c;
				}
			} else if (c === '"' && value === '') {
				quoted = true;
				wasQuoted = true;
			} else if (c === separator) {
				endValue();
			} else if (c === '\n') {
				endRecord();
			} else if (c !== '\r') {
				value += c;
			}
		}
		if (records.length <= sampleRows) endRecord();
		return records;
	};

	// jsonRows is the objects of an array. If the file can't be read, the server says
	// why when it's imported.
	const jsonRows = () => {
		try {
			const rows = JSON.parse(text);
			return Array.isArray(rows) ? rows.filter(row => row !== null && typeof row === 'object') : [];
		} catch {
			return [];
		}
	};

	const isInteger = s => /^-?(0|[1-9][0-9]*)$/.test(s);
	const isDecimal = s => /^-?(0|[1-9][0-9]*)\.[0-9]+$/.test(s);
	const isNumber = s => isInteger(s) || isDecimal(s) || /^-?[0-9.]+[eE][-+]?[0-9]+$/.test(s);
	const fits = (s, max) => {
		const digits = s.replace(/^-/, '');
		return digits.length < max.length || (digits.length === max.length && digits <= max);
	};

	// guessType is the type of a new column for what's in the first rows of the file,
	// which are strings. A number in JSON can be any number type, and a string in
	// JSON can't be. A value with a leading zero (such as a zip code) stays text.
	const guessType = (values, kinds) => {
		const text255 = `VARCHAR(${Math.max(255, ...values.map(value => [...value].length))})`;
		if (values.length === 0) return text255;
		if (kinds.every(kind => kind !== 'string' && kind !== 'number') && values.every(value => /^(true|false)$/i.test(value))) return 'BOOLEAN';
		if (kinds.every(kind => kind !== 'string' && kind !== 'boolean')) {
			if (values.every(isInteger)) {
				if (values.every(value => fits(value, '2147483647'))) return 'INTEGER';
				if (values.every(value => fits(value, '9223372036854775807'))) return 'BIGINT';
			}
			if (values.every(value => isInteger(value) || isDecimal(value))) {
				const parts = values.map(value => value.replace(/^-/, '').split('.'));
				const whole = Math.max(1, ...parts.map(part => part[0].length));
				const scale = Math.max(0, ...parts.map(part => (part[1] || '').length));
				if (whole + scale <= 38) return `DECIMAL(${whole + scale}, ${scale})`;
			}
			if (values.every(isNumber)) return 'DOUBLE PRECISION';
		}
		if (kinds.every(kind => kind === 'text' || kind === 'string')) {
			if (values.every(value => /^\d{4}-\d{2}-\d{2}$/.test(value))) return 'DATE';
			if (values.every(value => /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d+)?$/.test(value))) return 'TIMESTAMP';
		}
		return text255;
	};

	// readSample finds the fields of the file and the type that's guessed for each.
	const readSample = () => {
		if (format === 'json') {
			const rows = jsonRows();
			fields = [...new Set(rows.flatMap(row => Object.keys(row)))];
			types = fields.map(name => {
				const values = rows.slice(0, sampleRows).map(row => row[name]).filter(value => value !== null && value !== undefined);
				return guessType(values.map(String), values.map(value => typeof value === 'object' ? 'string' : typeof value));
			});
			return rows.length;
		}
		const records = sampleRecords(format === 'csv' ? ',' : '\t');
		fields = (records[0] || []).map(name => (name || '').trim());
		types = fields.map((_, i) => {
			const values = records.slice(1).map(record => record[i]).filter(value => value !== null && value !== undefined);
			return guessType(values, values.map(() => 'text'));
		});
		return text.split('\n').filter(line => line.trim() !== '').length - 1;
	};

	const showStats = counts => {
		stats.replaceChildren();
		const shown = counts.filter(([, count]) => count > 0);
		shown.forEach(([name, count]) => {
			const row = stats.insertRow();
			row.insertCell().textContent = name;
			row.insertCell().textContent = '~' + count;
		});
		stats.hidden = shown.length === 0;
	};

	const addOption = (select, value, label) => {
		const option = document.createElement('option');
		option.value = value;
		option.textContent = label;
		select.append(option);
		return option;
	};

	const showTables = chosen => {
		tableSelect.replaceChildren();
		addOption(tableSelect, '', 'New table');
		const schema = schemas.find(s => s.name === schemaSelect.value);
		(schema ? schema.tables : []).forEach(table => {
			addOption(tableSelect, table.name, table.name).selected = table.name === chosen;
		});
	};

	const tableColumns = () => {
		const schema = schemas.find(s => s.name === schemaSelect.value);
		const table = schema && schema.tables.find(t => t.name === tableSelect.value);
		return table ? table.columns : [];
	};

	// showMap has each field of the file with where it goes: a column of the table,
	// which is the one with the same name to start with, or a name for a new table.
	const showMap = () => {
		mapBody.replaceChildren();
		const isNew = tableSelect.value === '';
		nameLabel.hidden = !isNew;
		root.querySelector('.import-type').hidden = !isNew;
		fields.forEach((name, i) => {
			const row = mapBody.insertRow();
			row.insertCell().textContent = name;
			let target;
			if (isNew) {
				target = document.createElement('input');
				target.spellcheck = false;
				target.value = name;
				target.placeholder = 'Skip';
			} else {
				target = document.createElement('select');
				addOption(target, '', 'Skip');
				tableColumns().forEach(column => {
					addOption(target, column, column).selected = column.toUpperCase() === name.toUpperCase();
				});
			}
			target.dataset.field = name;
			target.setAttribute('aria-label', `Column for ${name}`);
			row.insertCell().append(target);
			if (isNew) {
				const type = document.createElement('input');
				type.spellcheck = false;
				type.value = types[i];
				type.className = 'import-column-type';
				type.dataset.type = name;
				type.setAttribute('list', 'import-types');
				type.setAttribute('aria-label', `Type of ${name}`);
				row.insertCell().append(type);
			}
		});
		update();
	};

	// newColumns is the column and type of each field that isn't skipped, for a new
	// table.
	const newColumns = () => [...mapBody.querySelectorAll('[data-type]')]
		.map(type => [type.closest('tr').querySelector('[data-field]').value.trim(), type.value.trim()])
		.filter(([column]) => column !== '');

	// mapping has each field and its column, which is empty to skip it.
	const mapping = () => [...mapBody.querySelectorAll('[data-field]')]
		.map(target => [target.dataset.field, target.value.trim()]);

	// The server builds the command of "vsql in" (see import.v), and also saves what's
	// posted, so only one is sent at a time. Otherwise an earlier one could finish
	// last and replace what was chosen after it.
	let sending = false;
	let changed = false;
	let updates = 0;
	const showCommand = async () => {
		changed = true;
		if (sending) return;
		sending = true;
		try {
			while (changed) {
				changed = false;
				const body = new URLSearchParams(new FormData(form));
				body.set('import_command', '1');
				const response = await fetch('/', { method: 'POST', body });
				if (changed || !response.ok) continue;
				const preview = await response.json();
				if (changed) continue;
				command.textContent = preview.command;
				commandBox.hidden = false;
				root.dataset.updated = String(++updates);
			}
		} finally {
			sending = false;
		}
	};

	const update = () => {
		const isSql = format === 'sql';
		root.querySelectorAll('[data-formats]').forEach(section => {
			section.hidden = !section.dataset.formats.split(' ').includes(format);
		});
		const isNew = tableSelect.value === '';
		submit.disabled = !isSql && ((isNew && (nameInput.value.trim() === '' || newColumns().length === 0
			|| newColumns().some(([, type]) => type === '')))
			|| (fields.length > 0 && mapping().every(([, column]) => column === '')));
		if (!file || options.hidden) return;
		field('import_format').value = format;
		field('import_file').value = file.name;
		field('import_mapping').value = JSON.stringify(mapping());
		field('import_columns').value = JSON.stringify(newColumns());
		showCommand();
	};

	fileInput.addEventListener('change', async () => {
		file = fileInput.files[0] || null;
		// What happened is for the file before this one.
		document.querySelectorAll('main > .notice, main > .error, .import-report').forEach(e => e.remove());
		options.hidden = true;
		stats.hidden = true;
		message.hidden = true;
		commandBox.hidden = true;
		if (!file) return;

		format = file.name.includes('.') ? file.name.split('.').pop().toLowerCase() : '';
		if (!fileInput.accept.split(',').includes('.' + format)) {
			message.textContent = `${file.name} cannot be imported, it must be ${fileInput.accept}`;
			message.hidden = false;
			return;
		}

		text = (await file.text()).replace(/^﻿/, '');
		if (format === 'sql') {
			fields = [];
			showStats(sqlKinds.map(kind => [kind, sqlCount(kind)]));
		} else {
			const rows = readSample();
			showStats([['Rows', Math.max(rows, 0)], ['Fields', fields.length]]);
		}
		nameInput.value = file.name.replace(/\.[^.]*$/, '');
		options.hidden = false;
		showMap();
	});

	schemaSelect.addEventListener('change', () => {
		showTables('');
		showMap();
	});
	tableSelect.addEventListener('change', showMap);
	root.addEventListener('input', e => {
		if (e.target !== fileInput) update();
	});
	root.querySelector('.copy-command').addEventListener('click', () => {
		navigator.clipboard.writeText(command.textContent);
	});

	// Enter would otherwise be the first button of the form, which is a tab.
	root.addEventListener('keydown', e => {
		if (e.key === 'Enter' && e.target.tagName === 'INPUT') e.preventDefault();
	});

	// The file is only posted by Import, not when going to another tab. A big file
	// can take a while, and it can only be imported once.
	form.addEventListener('submit', e => {
		if (e.submitter !== submit) return;
		field('import_text').disabled = false;
		field('import_text').value = text;
		submit.disabled = true;
		submit.textContent = 'Importing...';
	});

	root.querySelector('#import-types').append(...['INTEGER', 'BIGINT', 'SMALLINT', 'DECIMAL(10, 2)', 'DOUBLE PRECISION', 'BOOLEAN',
		'VARCHAR(255)', 'CHAR(10)', 'DATE', 'TIME', 'TIMESTAMP'].map(type => new Option(type)));
	showTables(root.dataset.table);
}
