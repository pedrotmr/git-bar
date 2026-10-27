# AGENTS.md

## Project

GitBar is a macOS menu bar app for local Git branches, worktrees, stashes, and GitHub pull requests. The app's product identity and preferences domain are compatibility requirements: `GitBar`, `GitBar.app`, and `com.GitBar.app`.

## Structure

- `Sources/GitBar/`: app source grouped by `App/`, `Models/`, `Services/`, and `Views/`.
- `Tests/GitBarTests/`: focused behavior tests.
- `Config/`: shared build settings and the app's `Info.plist`.
- `Resources/`: icon sources, asset catalog, and bundled license notices.
- `scripts/`: setup, bundle checks, and local release checks.
- `docs/`: specification, credentials, build, and distribution details.

## Build and verification

Use Xcode 26.6 or newer and the Makefile interface. Xcode is the only app build system; Swift Package Manager is used by Xcode to resolve the pinned Sparkle dependency.

```sh
make setup
make build
make run
make test
make bundle
make check
make release-check APP_BUILD_NUMBER=<new-increasing-number>
```

The first six commands need no credentials. `make release-check` requires a Developer ID Application identity, Apple notarization credentials, and this app's Sparkle EdDSA private key. It may create `.env`, writes build products under `.build/DerivedData`, writes release files under `.build/release`, and never publishes a release.

## Compatibility and behavior

- Preserve the bundle identifier and existing UserDefaults keys. The app migrates settings from the older `pedrotmr.GitBar` domain without deleting the old values.
- Keep Git and GitHub CLI optional failures clear. A Finder-launched app cannot rely on an interactive shell's PATH.
- Sparkle and its private key are app-specific. Do not reuse another product's key.
- Keep network and filesystem operations off the main actor where practical; keep user interface state on the main actor.

## Scope

Prefer small, tested changes. Add tests for critical new behavior and use `make check` before pull requests. Do not add a second build system or copy personal paths, credentials, private repository data, or real user data into examples.
