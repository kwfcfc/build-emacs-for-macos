# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

macOS Emacs building system with Ruby and Go components:

- **Ruby script** (`build-emacs-for-macos`): Main build script for creating
  self-contained Emacs.app bundles
- **Go CLI tool** (`emacs-builder`): Packaging, signing, notarization, and
  release management
- **Dual dependency management**: Nix (preferred) or Homebrew

## Common Commands

```bash
# Environment setup (Nix preferred)
nix develop                       # Default macOS 26 SDK
nix develop .#macos{14,15,26}     # Target specific SDK version

# Go development
make build                        # Build emacs-builder CLI
make test                         # Run tests with race detection
make lint                         # Run golangci-lint
make format                       # Format with gofumpt

# Ruby development
bundle exec rubocop               # Lint (with development group)

# Build Emacs
./build-emacs-for-macos           # Build from master
./build-emacs-for-macos emacs-29.4
```

## Architecture

### Ruby Build Script (`build-emacs-for-macos`)

Ruby build script (~2500 lines), with small supporting classes in `lib/`, that:

- Downloads source tarballs from emacs-mirror/emacs on GitHub
- Configures and compiles Emacs with native-comp, tree-sitter support
- Creates self-contained .app bundles by embedding/relinking dependencies
- Uses `ruby-macho` gem for Mach-O binary manipulation (RPATH handling)
- Adds the privacy descriptions defined in `lib/privacy_usage_descriptions.rb`
  before self-signing. Keep this step before all signing, and keep
  legacy/current key pairs together so the default macOS 11.3+ deployment
  range remains covered.
- Resolve the Emacs major version from the extracted source tree's
  `configure.ac` for all builds. When no source tree is available, such as for
  `--info`, fetch `configure.ac` through the GitHub API. Do not infer the source
  version from the ref name. Patch and Tree-sitter selection must follow the
  resolved source version.

### Go CLI (`cmd/emacs-builder/`)

Uses `urfave/cli/v2` framework. Key packages in `pkg/`:

- `cli/`: Commands (plan, sign, sign-files, notarize, package, release, cask)
- `sign/`: macOS code signing via `codesign`
  - Keep Hardened Runtime resource entitlements aligned with the corresponding
    privacy usage descriptions. Developer ID-signed builds need both to request
    access to audio input, camera, contacts, calendars, location, and Photos.
- `notarize/`: Apple notarization workflow via `notarytool`
- `release/`: GitHub release management
- `dmgbuild/`: DMG creation using Python dmgbuild
- `plan/`: Build plan JSON parsing and management

### Nix Environment (`flake.nix`)

- Multi-SDK support: macOS 14, 15, 26 via `.#macos{14,15,26}`
- Excludes ncurses intentionally (links against system version for TUI)
- Sets `MACOSX_DEPLOYMENT_TARGET`, `DEVELOPER_DIR`, `NIX_LIBGCCJIT_*`
- Provides the Nixpkgs Tree-sitter runtime for Emacs 29/30 and a project-local Tree-sitter
  0.27 C runtime for Emacs 31+. The toolchain is pinned to Nixpkgs 26.05;
  dependencies require macOS 14 or later, and the default shell targets macOS 26.
- Keep the full host Command Line Tools SDK out of the Nix build-time
  `LIBRARY_PATH`; expose only the sanitized system ncurses stub. Nix supplies
  the remaining libraries matched to its linker, while newer host SDK stubs
  may be incompatible with that toolchain.

## Testing

```bash
make test                         # All Go and Ruby tests
make test-go                      # Go tests
make test-ruby                    # Privacy usage-description Ruby tests
go test ./pkg/release/...         # Single package
go test -run TestName ./pkg/...   # Single test
```

Go tests use `_test.go` suffix alongside source files. Ruby specs live in
`spec/` and run with RSpec.

Keep GitHub Actions dependencies pinned to full commit SHAs with version
comments. Update and verify them with `pinact run -update`.

## Emacs-IGC Local Builds

`scripts/igc/emacs-igc` builds, verifies, installs, and rolls back
`/Applications/Emacs-IGC.app` from `emacs-mirror/emacs` `feature/igc3`.
Treat `Contents/Resources/igc-source-commit.txt` as the installed source commit;
`emacs-repository-version` reports this repository's HEAD instead.

`.github/workflows/emacs-igc.yml` runs the same `emacs-igc build` and `dmg`
commands on a `macos-26` runner and publishes `emacs-igc-<sha7>` releases;
`emacs-igc install <file>.dmg` installs one. Keep the runner's macOS and
`IGC_NIX_SHELL` aligned, since the build runs the new Emacs. Linux CI agents
cannot build it.

## Working Directories

- `sources/`: Downloaded/extracted Emacs source (gitignored)
- `builds/`: Build outputs and .app bundles (gitignored)
- `patches/`: Emacs patches applied during build
- `bin/`: Built Go binaries (gitignored)
