# Homebrew

The public tap `pedrotmr/homebrew-git-bar` is being prepared. It has no cask yet because the only stable GitBar release, v0.1.2, is not notarized. Do not treat a Homebrew install command as available until a cask points to a signed, notarized, public release and passes `brew audit --cask --strict`.

After a Sparkle-enabled release is published, the tap sync workflow will poll GitHub's latest stable release every six hours, download `GitBar-<version>.zip`, verify the bundle version, icon, Developer ID signature, notarization ticket, and Gatekeeper result, calculate SHA-256, audit the generated cask, and commit the cask update. Polling avoids a cross-repository token; drafts and prereleases are excluded because the workflow reads GitHub's latest stable release endpoint.

The cask will set `auto_updates true` only when its app contains Sparkle. Its postflight marker lives in the separate `com.GitBar.app.homebrew` defaults domain. Uninstall clears only that marker and preserves GitBar preferences and all repository data.

Update Homebrew installations with `brew update && brew upgrade`. In Homebrew 7.0.11, ordinary `brew upgrade` skips a readable self-updating app when the installed app is newer than the cask. `brew upgrade --cask pedrotmr-git-bar`, `--greedy`, and `--greedy-auto-updates` may reinstall the older cask version and downgrade the app. Use the ordinary `brew upgrade` form.

The appcast uses `https://github.com/pedrotmr/git-bar/releases/latest/download/appcast.xml`. GitHub drafts do not become the latest public release, so uploading a draft appcast cannot change the stable feed. A tap cask must never use a draft URL or a placeholder checksum.
