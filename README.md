<img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" alt="GitBar app icon" width="160">

# GitBar

A macOS menu bar app for managing Git branches, worktrees, stashes, and GitHub pull requests.

![Screenshot placeholder: capture GitBar with a local demo repository](Screenshots/git-bar-placeholder.svg)

*Screenshot placeholder, not a product image. See [capture instructions](docs/SCREENSHOT.md).*

## Install and update

The signed download and Homebrew cask are being prepared. The published v0.1.2 app is not notarized, so it is not suitable for a new installation. After a signed release is available, download its `GitBar-<version>.zip`, move `GitBar.app` to Applications, and open it. The Homebrew install command will be added here when the cask points to a verified public release.

Direct downloads will update through Sparkle. Homebrew installations should update with `brew update && brew upgrade`. Use only the ordinary `brew upgrade` command; explicitly upgrading a named cask can reinstall an older cask version if Sparkle has already updated the app.

## First steps

Open GitBar from Applications and add a local Git repository. GitBar reads the repository's local branches, worktrees, and stashes. The pull request view uses GitHub CLI (`gh`) and the currently authenticated GitHub account.

## Requirements and limits

- macOS 14.6 or later.
- Git is required. The app searches Homebrew and standard macOS locations when launched from Finder.
- GitHub CLI is optional; install it with Homebrew and run `gh auth login` to use pull requests. GitHub access depends on the account and repository permissions configured in `gh`.
- GitBar runs Git commands against repositories you select. It does not host or synchronize repository data.
- This project is early-stage and maintained on a best-effort basis. Replies and release timing are not promised.

## Help and development

- **Questions and problems:** [GitHub Issues](https://github.com/pedrotmr/git-bar/issues)
- **Setup and development:** [Documentation index](docs/README.md), [contribution guide](CONTRIBUTING.md)
- **License:** [MIT](LICENSE) · [Third-party notices](docs/THIRD-PARTY-NOTICES.md)
