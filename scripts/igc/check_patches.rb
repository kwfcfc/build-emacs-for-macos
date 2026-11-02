# frozen_string_literal: true

# Check that every remote patch build-emacs-for-macos would apply for a ref
# and set of build options can still be downloaded, without fetching the
# source tarball. Follows emacs-plus symlinked patches the way the build
# does. Exits 1 when any patch is unavailable.
#
# Usage (inside `nix develop`):
#   ruby check_patches.rb path/to/build-emacs-for-macos REF [build options...]

require 'open3'
require 'uri'

def fetch(url)
  body, status = Open3.capture2('curl', '-fsSL', url)
  body if status.success?
end

script, ref, *args = ARGV
load File.expand_path(script)

options = CLIOptions.parse(args)
Output.log_level = options.delete(:log_level)
work_dir = options.delete(:work_dir)

begin
  patches = Build.new(work_dir, ref, options).send(:build_patches)
rescue Error => e
  warn "ERROR: #{e.message}"
  exit 1
end

failed = false
patches.each do |patch|
  next unless patch[:url]

  url = patch[:url]
  body = fetch(url)
  # GitHub serves a symlinked patch as a single line naming its target.
  if body && body.lines.size == 1
    url = URI.join(url, body.strip).to_s
    body = fetch(url)
  end
  failed = true if body.nil?
  warn "    #{(body ? 'ok' : 'FAIL').ljust(4)} #{url}"
end

exit(failed ? 1 : 0)
