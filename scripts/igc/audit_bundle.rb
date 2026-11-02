# frozen_string_literal: true

# Report non-system dylib dependencies that do not resolve inside an app
# bundle. Prints JSON and exits 1 when any dependency is unresolved.
#
# Usage (needs the ruby-macho gem, e.g. inside `nix develop`):
#   ruby audit_bundle.rb path/to/Emacs-IGC.app

require 'macho'
require 'json'

MACHO_MAGICS = %w[cffaedfe cefaedfe feedfacf feedface cafebabe bebafeca].freeze

root = File.expand_path(ARGV.fetch(0))
contents_macos = File.join(root, 'Contents/MacOS')
issues = []
count = 0

Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each do |path|
  next unless File.file?(path)
  next if File.symlink?(path)

  magic = File.binread(path, 4)
  next unless magic && MACHO_MAGICS.include?(magic.unpack1('H*'))

  macho = MachO.open(path)
  count += 1
  macho.linked_dylibs.each do |dependency|
    next if dependency.start_with?('/usr/lib/', '/System/Library/')

    if dependency.start_with?('@loader_path/')
      resolved = dependency.sub('@loader_path', File.dirname(path))
      next if File.exist?(resolved)
    elsif dependency.start_with?('@executable_path/')
      resolved = dependency.sub('@executable_path', contents_macos)
      next if File.exist?(resolved)
    elsif dependency.start_with?('@rpath/')
      # Libraries loaded by the main executable also search its rpath.
      rpaths = macho.rpaths + ['@executable_path/../Frameworks']
      next if rpaths.any? do |rpath|
        prefix = rpath.sub('@loader_path', File.dirname(path))
                      .sub('@executable_path', contents_macos)
        File.exist?(dependency.sub('@rpath', prefix))
      end
    end
    issues << { file: path.delete_prefix("#{root}/"), dependency: dependency }
  end
end

puts JSON.pretty_generate(macho_files: count, unresolved_dependencies: issues)
exit(issues.empty? ? 0 : 1)
