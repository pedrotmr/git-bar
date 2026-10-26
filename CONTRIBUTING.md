# Contributing

Report problems in [GitHub Issues](https://github.com/pedrotmr/git-bar/issues). Include macOS version, Git version, steps to reproduce, and sanitized error text. Remove private paths, repository names, and personal data before sharing logs or screenshots.

Install Xcode 26.6 or newer with the macOS platform. Git is required to build and for the app's repository features. GitHub CLI is optional for pull requests. Homebrew is optional. Run `make setup` to resolve the pinned Sparkle 2.10.1 dependency.

Run the commands used by CI:

```sh
make setup
make build
make run
make test
make bundle
make check
```

`make check` runs focused tests and verifies a universal app bundle, including metadata, icon, and Sparkle components. These commands need no signing credentials. Release signing and notarization are documented in [Build and release](docs/BUILD-AND-RELEASE.md). `make release-check` creates local files and does not upload or publish a release.

Open a pull request against `main`, describe the user-visible change, and list the commands you ran. Use fictional local data for UI screenshots. Keep changes focused on GitBar's repository management features.
