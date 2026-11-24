module main

import cli
import compress.szip
import json2
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

// releases_api_url lists the releases, newest first, with the zips of each one.
// VSQL_RELEASES_API_URL replaces it for the tests (see cmd/tests/up.sh).
fn releases_api_url() string {
	return os.getenv_opt('VSQL_RELEASES_API_URL') or {
		'https://api.github.com/repos/elliotchance/vsql/releases?per_page=100'
	}
}

// A Release is the part of a release in the GitHub API that's needed to find
// its zip.
struct Release {
	tag_name string
	assets   []ReleaseAsset
}

struct ReleaseAsset {
	name                 string
	browser_download_url string
}

// latest_release returns the version and the zip URL of the newest release
// that has a zip for this OS and CPU. A release is published as soon as its tag
// is pushed, and its zips are added when they're built (which can take a while,
// or fail), so the latest release may not have one yet.
fn latest_release(curl string, tmp string) !(string, string) {
	path := os.join_path(tmp, 'releases.json')
	run_curl(curl, ['-fsSL', '-o', path, releases_api_url()])!
	text := os.read_file(path)!
	releases := json2.decode[[]Release](text) or {
		return error('cannot read the releases: ${err}')
	}
	for release in releases {
		name := 'vsql-${release.tag_name}-${release_platform()}.zip'
		for asset in release.assets {
			if asset.name == name {
				return release.tag_name, asset.browser_download_url
			}
		}
	}

	return error("there's no release with a zip for ${release_platform()} yet")
}

// up_command downloads the zip of the latest release for this OS and CPU (the
// same one as install.sh, see latest_release) with curl, and replaces the
// running binary with the one in it.
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

	version, url := latest_release(curl, tmp)!
	if version == current && !force {
		println('vsql ${current} is already the latest release')
		return
	}

	name := 'vsql-${version}-${release_platform()}'
	zip := os.join_path(tmp, '${name}.zip')
	println('Downloading ${name}.zip')
	run_curl(curl, ['-fsSL', '-o', zip, url])!
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
