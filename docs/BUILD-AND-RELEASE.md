# Build and release

## Toolchain

- macOS 14.6 or later to run GitBar.
- Xcode 26.6 or newer with the macOS platform. The current project uses Xcode's build system and its bundled Swift toolchain in Swift 5 language mode.
- Git for source work and repository operations.
- GitHub CLI (`gh`) is optional at runtime and required only for the pull request view. Install it with Homebrew and authenticate using `gh auth login`.
- Homebrew is optional for development and distribution.
- Sparkle 2.10.1 is pinned in `GitBar.xcodeproj`; `make setup` resolves it.

The app bundle is universal (`arm64` and `x86_64`). Its minimum system version is 14.6. Release signing uses the `YW25U2BJ23` Developer ID team.

The original Icon Composer source, optional generator, and packaged asset check are documented in [App icon](ICONS.md).

## Build system

Xcode is the only app build system. SwiftPM is useful for portable libraries and command-line builds, but it does not own these apps' asset catalogs, app metadata, previews, test schemes, framework embedding, or macOS signing flow. Xcode handles those in one project; SwiftPM only resolves the exact Sparkle 2.10.1 dependency. The trade-off is that app development and builds require macOS and Xcode. The Makefile gives both apps the same local and CI commands, and each checkout keeps its build products under `.build/`.

Xcode owns the app target, asset catalog, Info.plist processing, tests, previews, Sparkle embedding, and code signing. There is no SwiftPM app package or second official build path. Shared compiler, architecture, team, and deployment settings live in `Config/Project.xcconfig`; product metadata lives in `Config/App.xcconfig` and `Config/Info.plist`.

## Standard commands

```sh
make setup
make build
make run
make test
make bundle
make check
```

All of these commands work without signing or distribution credentials. `make setup` resolves the pinned Sparkle package. `make run` opens the Debug app. `make bundle` builds and checks an unsigned universal Release app in `.build/DerivedData`. `make check` is the CI command; it runs tests and validates the app bundle, icon, Info.plist, Sparkle framework, and architecture slices.

For a signed, notarized local distribution check, use an increasing numeric build number:

```sh
make release-check APP_BUILD_NUMBER=27
```

This command requires a Developer ID Application identity, Apple notary credentials, and GitBar's EdDSA private key in the local Keychain or ignored `.env`. It writes a ZIP, DMG, appcast, and validation logs under `.build/release`. It never uploads, creates, or publishes a release. See [Credentials](CREDENTIALS.md). Base64 is encoding, not encryption.

## Version and release flow

Release Please reads `.release-please-manifest.json` and `CHANGELOG.md`. Conventional Commit messages drive the next version. Its `extra-files` updater writes the same version into `Config/App.xcconfig`, which feeds Xcode and the Makefile. `make setup` fails if those values drift. `CFBundleVersion` uses the monotonically increasing workflow run number; a local `make release-check` must receive an explicit increasing number.

On `main`, Release Please opens or updates a draft version PR. When that PR is merged, the same workflow creates the GitHub draft release and tag, builds from that tag, runs `make check`, signs the app and Sparkle components, notarizes the DMG, staples the app and DMG, validates the final ZIP, and attaches the versioned ZIP, DMG, and `appcast.xml` to the draft. It does not publish. A manual workflow run can rebuild only an existing draft.

Review the draft title, notes, ZIP, DMG, and appcast before publishing it in GitHub. Draft assets are not public, and the stable `releases/latest/download/appcast.xml` feed does not change until the release is published. Do not replace assets on a published release; use a new version. The app repository workflow does not run on both tag and published-release events, preventing duplicate builds.

The signing order is Sparkle's nested updater executable and `Updater.app`, then `Sparkle.framework`, then `GitBar.app`. The script verifies Developer ID, hardened runtime, timestamps, team ID, and universal binaries. It submits the DMG to Apple, checks the accepted status and log, staples the app and DMG, and tests the app extracted from the final ZIP. The appcast's EdDSA signature and enclosure size are checked against that exact ZIP.

## Updating and Homebrew

Users who install a direct download use Sparkle's **Check for Updates…** command. Users who install through Homebrew use `brew update && brew upgrade`. The cask marks Sparkle-enabled builds as `auto_updates true` and writes an install marker in a separate UserDefaults domain. GitBar reads that marker before starting Sparkle, and the cask clears only that marker when it uninstalls the app; it does not touch repository data or app preferences.

Homebrew skips a readable self-updating app during a normal `brew upgrade` when the installed app is ahead of the cask. A named cask upgrade or a greedy upgrade can reinstall the older cask version. Use `brew update && brew upgrade`. The new tap and cask are not available yet because there is no signed public release to reference. After a stable release is published, the app workflow checks the ZIP, calculates its SHA-256, audits the cask, and pushes it to the tap. It needs `HOMEBREW_TAP_TOKEN` with write access to that tap.

The current v0.1.2 build predates Sparkle and is not notarized. It cannot self-update with Sparkle. Its custom GitHub updater may bridge existing installations to the first signed versioned ZIP, but that transition has not been exercised. Until the first signed release is published, there is no supported new-install path.

## Troubleshooting

- `make setup` reports an old Xcode: install Xcode 26.6 or newer and select it with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- Xcode cannot resolve Sparkle: check network access to GitHub, then rerun `make setup`.
- GitBar cannot find Git or `gh` from Finder: the app adds standard Homebrew, user, and system executable locations. Reinstall the missing tool into one of those paths; a shell-only PATH change is not inherited by Finder.
- The PR view is empty: confirm the selected repository has a GitHub `origin`, install `gh`, run `gh auth login`, and check account access with `gh auth status`. When `gh` is absent, GitBar shows an install hint. When unauthenticated, GitHub CLI's error is displayed and other local Git tabs continue to work.
- `make release-check` fails before signing: set the named missing credential in `.env` or install the Developer ID certificate in the login Keychain. The script fails instead of switching to a preview release.
- Apple rejects notarization: inspect `.build/release/notary-log.json`; fix the listed issue and rerun the local check.
- Sparkle rejects a feed item: confirm the app-specific public key matches the signing key and rerun `make release-check` with a new build number.
