<div align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" alt="GitBar app icon" width="128">
  <h1>GitBar</h1>
  <p>A macOS menu bar app for managing Git branches, worktrees, stashes, and GitHub pull requests.</p>
  <p>
    <a href="https://github.com/pedrotmr/git-bar/releases/latest"><img src="https://img.shields.io/github/v/release/pedrotmr/git-bar?label=latest%20release" alt="Latest release"></a>
    <a href="https://github.com/pedrotmr/git-bar/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/pedrotmr/git-bar/ci.yml?label=checks" alt="Build and test status"></a>
    <a href="LICENSE"><img src="https://img.shields.io/github/license/pedrotmr/git-bar" alt="MIT license"></a>
  </p>
</div>

## GitBar in action

<video src="Media/git-bar-demo.mp4" controls width="640" aria-label="GitBar demo"></video>

[Watch or download the GitBar demo](Media/git-bar-demo.mp4).

## ✨ Features

- 🌱 Manage branches, worktrees, and stashes in your local repositories.
- 🔀 View GitHub pull requests with the optional GitHub CLI (`gh`).

## 📦 Install

Choose one installation method:

### Option 1: Homebrew

```sh
brew install --cask pedrotmr/git-bar/pedrotmr-git-bar
```

Homebrew manages updates for this copy. To update only GitBar:

```sh
brew update
brew upgrade --cask --greedy-auto-updates pedrotmr/git-bar/pedrotmr-git-bar
```

### Option 2: Direct download

1. Download the latest stable [DMG or ZIP from GitHub Releases](https://github.com/pedrotmr/git-bar/releases/latest).
2. If you downloaded the DMG, open it. If you downloaded the ZIP, extract it.
3. Drag `GitBar.app` to your Applications folder.

To update a direct download, choose **Check for Updates…** in the app. Version 0.2.0 was the first Sparkle release. For a predictable upgrade from v0.1.x, install the current release manually once.

## 🚀 First launch

1. Make sure Git is installed.
2. Open GitBar from Applications and add a local Git repository.
3. To view pull requests, install GitHub CLI and sign in with `gh auth login`.

## ⚙️ Requirements and limits

- Requires macOS 14.6 or later and Git.
- GitBar searches Homebrew and standard macOS locations for Git when you open it from Finder.
- GitHub CLI is optional. Your signed-in account must have access to each repository.
- GitBar runs Git commands on repositories you select. It does not host or sync repository data.

## 🛠 Development

Use Xcode 26.6 or later. These commands do not need signing or release credentials:

```sh
make setup
make run
make check
```

See the [documentation index](docs/README.md), [contribution guide](CONTRIBUTING.md), and [build guide](docs/BUILD-AND-RELEASE.md).

> Maintenance is best-effort. Issues and pull requests are welcome, but replies and release dates are not promised.

## Links

- 🐛 **Support:** [Report a problem](https://github.com/pedrotmr/git-bar/issues)
- 📚 **Documentation:** [Read the guides](docs/README.md)
- 🤝 **Contribute:** [Contribution guide](CONTRIBUTING.md)
- ⚖️ **License:** [MIT](LICENSE) · [Third-party notices](docs/THIRD-PARTY-NOTICES.md)
