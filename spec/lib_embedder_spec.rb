# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'

load File.expand_path('../build-emacs-for-macos', __dir__) unless defined?(Build)

RSpec.describe LibEmbedder do
  it 'preserves incompatible same-name libraries for Emacs and its helpers' do
    skip 'requires macOS Mach-O tools' unless RUBY_PLATFORM.include?('darwin')

    Dir.mktmpdir('emacs-library-collision') do |root|
      root = File.realpath(root)
      dependencies = File.join(root, 'dependencies')
      app = File.join(root, 'Emacs.app')
      binaries = File.join(app, 'Contents', 'MacOS')
      FileUtils.mkdir_p(File.join(binaries, 'bin'))
      FileUtils.mkdir_p(File.join(app, 'Contents', 'Frameworks'))

      libraries = %w[apple gnu].map.with_index do |provider, index|
        directory = File.join(dependencies, provider)
        FileUtils.mkdir_p(directory)
        source = File.join(directory, 'library.c')
        library = File.join(directory, 'libsame.1.dylib')
        File.write(source, "int #{provider}_value(void) { return #{index + 1}; }")
        run_tool('/usr/bin/clang', '-dynamiclib', source, '-o', library,
                 '-Wl,-headerpad_max_install_names', '-install_name', library)
        library
      end

      source = File.join(root, 'main.c')
      File.write(source, <<~C)
        int apple_value(void);
        int gnu_value(void);
        int main(void) { return apple_value() + gnu_value() == 3 ? 0 : 1; }
      C
      main = File.join(binaries, 'Emacs')
      helper = File.join(binaries, 'bin', 'emacsclient')
      run_tool('/usr/bin/clang', source, *libraries, '-o', main,
               '-Wl,-headerpad_max_install_names')
      FileUtils.cp(main, helper)

      described_class.new(app, [dependencies]).embed
      run_tool('/usr/bin/codesign', '--force', '--sign', '-', main)
      run_tool('/usr/bin/codesign', '--force', '--sign', '-', helper)
      Dir[File.join(app, 'Contents', 'Frameworks', '*.dylib')].each do |library|
        run_tool('/usr/bin/codesign', '--force', '--sign', '-', library)
      end
      FileUtils.mv(dependencies, "#{dependencies}-hidden")

      run_tool(main)
      run_tool(helper)
    end
  end

  def run_tool(*arguments)
    stdout, stderr, status = Open3.capture3(*arguments)
    expect(status.success?).to be(true), "#{arguments.inspect}\n#{stdout}\n#{stderr}"
  end
end
