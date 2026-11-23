module main

import cli
import compress.szip
import os
import vsql

fn register_up_command(mut cmd cli.Command) {
	mut up_cmd := cli.Command{
		name:        'up'
		description: 'Replace this vsql with the latest release'
		execute:     up_command
	}
	up_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'force'
		abbrev:      'f'
		description: "Replace it even if it's already the latest release, or isn't a release"
	})
	cmd.add_command(up_cmd)
}

// releases_url is where the releases are downloaded from. VSQL_RELEASES_URL
// replaces it for the tests (see cmd/tests/up.sh).
fn releases_url() string {
	return os.getenv_opt('VSQL_RELEASES_URL') or { 'https://github.com/elliotchance/vsql/releases' }
}

// up_command downloads the zip of the latest release for this OS and CPU (the
// same one as install.sh) with curl, and replaces the running binary with the
// one in it.
fn up_command(cmd cli.Command) ! {
	force := cmd.flags.get_bool('force') or { false }
	current := vsql.build_version()
	if current == '' && !force {
		return error('this vsql was not built for a release, use -force to replace it with the latest release')
	}

	curl := os.find_abs_path_of_executable('curl') or {
		return error('curl must be installed to download the latest release')
	}

	tmp := os.join_path(os.temp_dir(), 'vsql-up-${os.getpid()}')
	os.mkdir_all(tmp)!
	defer {
		os.rmdir_all(tmp) or {}
	}

	// The latest release redirects to its tag, such as .../releases/tag/v1.6.77.
	url := run_curl(curl, ['-fsSL', '-o', os.join_path(tmp, 'latest'), '-w', '%{url_effective}',
		'${releases_url()}/latest'])!
	version := url.all_after_last('/')
	if version == current && !force {
		println('vsql ${current} is already the latest release')
		return
	}

	name := 'vsql-${version}-${release_platform()}'
	zip := os.join_path(tmp, '${name}.zip')
	println('Downloading ${name}.zip')
	run_curl(curl, ['-fsSL', '-o', zip, '${releases_url()}/download/${version}/${name}.zip'])!
	szip.extract_zip_to_dir(zip, tmp) or { return error('cannot unzip ${name}.zip: ${err}') }

	exe := os.executable()
	file_name := $if windows { 'vsql.exe' } $else { 'vsql' }
	replace_executable(exe, os.join_path(tmp, name, 'bin', file_name))!
	println('Replaced ${exe} with vsql ${version}')
}

// release_platform is the end of the name of a release zip, such as
// "macos-arm64".
fn release_platform() string {
	os_name := $if windows {
		'windows'
	} $else $if macos {
		'macos'
	} $else {
		'linux'
	}
	arch := $if arm64 { 'arm64' } $else { 'x86-64' }

	return '${os_name}-${arch}'
}

// run_curl runs curl with args, and returns what it prints.
fn run_curl(curl string, args []string) !string {
	mut p := os.new_process(curl)
	p.set_args(args)
	p.set_redirect_stdio()
	p.wait()
	output := p.stdout_slurp()
	errors := p.stderr_slurp()
	code := p.code
	p.close()
	if code != 0 {
		return error('cannot download ${args.last()}: ${errors.trim_space()}')
	}

	return output
}

// replace_executable replaces exe with the file at path. It's copied next to
// exe first, so that the rename is on the same file system. Unix replaces exe
// in one step, and the running process keeps the old file. Windows can't
// replace a file that's running, but it can rename it, so the old one is moved
// to exe.old, which the next "vsql up" deletes.
fn replace_executable(exe string, path string) ! {
	new := '${exe}.new'
	os.cp(path, new) or { return error('cannot write ${new}: ${err}') }
	os.chmod(new, 0o755) or {}

	$if windows {
		old := '${exe}.old'
		os.rm(old) or {}
		os.rename(exe, old) or { return error('cannot replace ${exe}: ${err}') }
	}

	os.rename(new, exe) or {
		os.rm(new) or {}
		return error('cannot replace ${exe}: ${err}')
	}
}
