The tap has a cask for the latest stable release: `pedrotmr/git-bar/pedrotmr-git-bar`.

# Homebrew

The Homebrew workflow runs after a stable release is published. It skips drafts and prereleases. It checks the release ZIP, calculates its SHA-256, creates the cask, runs Homebrew's strict audit, then pushes the cask to `pedrotmr/homebrew-git-bar`.

Before publishing a stable release:

1. Add `HOMEBREW_TAP_TOKEN` to this app repository. Follow [the credential guide](CREDENTIALS.md).
2. The workflow will create the cask in the existing tap.

The cask uses a versioned ZIP URL and its real SHA-256. Do not use a draft URL or a made-up checksum. The cask does not delete app settings, files, or user repositories when it uninstalls.

The cask marks the app as Homebrew-managed and clears only that marker when removed. Direct downloads use Sparkle.

The cask checks for macOS 14.6 or later before it installs GitBar. The app bundle and Sparkle feed carry the same minimum.

On a Homebrew install, GitBar checks the Sparkle feed quietly in the background when Sparkle automatic checks are enabled. When an installable update is available, an **Update to…** action appears. Choose it to install with Sparkle or copy the Homebrew command. If Sparkle cannot complete an update, its error alert offers the Homebrew command. Copying the command does not skip the release in Sparkle. In-app updates keep the Homebrew marker. The command below targets the version currently available in Homebrew's local tap, so use it after the tap contains the release you want.

To update only this cask, run:

```sh
brew upgrade --cask pedrotmr/git-bar/pedrotmr-git-bar
```

Direct downloads use Sparkle. Do not use the Homebrew command to update a direct download.
