# Specification

GitBar is a menu bar companion for working with local Git repositories.

## Behavior

- Shows local branches, worktrees, and stashes for the selected repository.
- Lists GitHub pull requests for the repository when GitHub CLI is installed and authenticated.
- Supports common branch, worktree, stash, and pull request actions from the menu bar popover.
- Saves repository selection and display preferences in UserDefaults.
- Offers Sparkle updates for direct downloads. Homebrew installs check the Sparkle feed on request and can choose an in-app update or copy the Homebrew command when an update is available.

## Scope and limits

GitBar operates on repositories on the current Mac. Git is required. GitHub CLI is optional and its permissions follow the account configured in `gh`. The app does not host repositories, replace Git, or provide a GitHub account. macOS 14.6 or later is required.

## Distribution

- Stable releases provide signed and notarized downloads on GitHub Releases.
- The `pedrotmr/homebrew-git-bar` tap provides a Homebrew cask.
- Direct downloads use Sparkle for updates. Homebrew installs can use Sparkle in-app or Homebrew for updates.
