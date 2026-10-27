# Specification

GitBar is a menu bar companion for working with local Git repositories.

## Behavior

- Shows local branches, worktrees, and stashes for the selected repository.
- Lists GitHub pull requests for the repository when GitHub CLI is installed and authenticated.
- Supports common branch, worktree, stash, and pull request actions from the menu bar popover.
- Saves repository selection and display preferences in UserDefaults.
- Offers Sparkle updates for direct downloads. Homebrew installs are directed to Homebrew for updates.

## Scope and limits

GitBar operates on repositories on the current Mac. Git is required. GitHub CLI is optional and its permissions follow the account configured in `gh`. The app does not host repositories, replace Git, or provide a GitHub account. macOS 14.6 or later is required.

Homebrew and signed direct downloads remain unavailable until a signed and notarized release is published. The currently published v0.1.2 release predates this distribution setup.
