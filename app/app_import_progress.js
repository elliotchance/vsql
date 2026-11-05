// app_import_progress.js is embedded in the page of an IMPORT tab of "vsql app"
// while it's importing a file, which runs in the background. The page is loaded
// again once it's finished, to show what happened.

{
	const root = document.querySelector('.import-running');
	const form = root.closest('form');
	const status = root.querySelector('.import-status');
	const bar = root.querySelector('.import-bar');
	const percent = root.querySelector('.import-percent');
	const operations = root.querySelector('.import-operations');
	const messages = root.querySelector('.import-messages');
	const cancel = root.querySelector('.import-cancel');
	const tab = form.querySelector('[name="tab"]').value;

	// size is a number of bytes, such as 123 KB or 1.4 MB.
	const size = bytes => {
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
		if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
		return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
	};

	const show = job => {
		const { done, total } = job.progress;
		// Until then, the bar shows that it's busy reading the file.
		if (total > 0 && done > 0) {
			bar.max = total;
			bar.value = done;
			percent.textContent = `${size(done)} / ${size(total)} (${Math.floor(100 * done / total)}%)`;
		}
		operations.replaceChildren();
		(job.progress.operations || []).forEach(operation => {
			const row = operations.insertRow();
			row.insertCell().textContent = operation.name;
			row.insertCell().textContent = operation.count;
		});
		operations.hidden = operations.rows.length === 0;
		// The messages are only added to, so that the list stays where it's scrolled to.
		(job.progress.messages || []).slice(messages.children.length).forEach(message => {
			const item = document.createElement('li');
			item.className = `import-${message.kind}`;
			if (message.line > 0) {
				const line = document.createElement('strong');
				line.textContent = `Line ${message.line}`;
				item.append(line, ' ');
			}
			const kind = document.createElement('span');
			kind.className = 'kind';
			kind.textContent = `${message.kind.toUpperCase()} ${message.sqlstate}`;
			item.append(kind, ` ${message.message}`);
			messages.append(item);
		});
		messages.hidden = messages.children.length === 0;
		if (job.cancelled) {
			status.textContent = 'Cancelling...';
			cancel.disabled = true;
		}
	};

	const poll = async () => {
		try {
			const body = new URLSearchParams({ tab, import_status: '1' });
			const response = await fetch('/', { method: 'POST', body });
			const job = await response.json();
			if (!job.running) {
				location.href = '/';
				return;
			}
			show(job);
		} catch {
			// It's tried again.
		}
		setTimeout(poll, 500);
	};
	poll();
}
