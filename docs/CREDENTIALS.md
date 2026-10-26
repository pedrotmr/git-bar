# Release credentials

## What you need

GitBar needs four GitHub secrets and two GitHub variables. The ignored `.env` file is the local copy. Fill it first, then copy each value to GitHub.

| Name | GitHub type | Where it comes from | Shared with AeroSpace Tabs? |
| --- | --- | --- | --- |
| `DEVELOPER_ID_CERTIFICATE_P12_BASE64` | Secret | Base64 text from your Developer ID `.p12` file | Yes |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Secret | The password you set when you export the `.p12` file | Yes |
| `APPLE_NOTARY_KEY_P8_BASE64` | Secret | Base64 text from an App Store Connect Team API `.p8` file | Yes |
| `SPARKLE_PRIVATE_KEY` | Secret | GitBar's Sparkle key, saved in this `.env` file | No |
| `APPLE_NOTARY_KEY_ID` | Variable | App Store Connect Team API key page | Yes |
| `APPLE_NOTARY_ISSUER_ID` | Variable | App Store Connect Team API key page | Yes |

Across both apps, the three Apple secrets and two Apple IDs are shared. Each app has a different Sparkle key. That is five unique secret values and two shared public IDs.

## Fill the Apple settings

The two local `.env` files now contain a password-protected export of your valid Developer ID certificate. The export came from your Keychain. You do not need a new certificate.

A local `Apple Auth Key.p8` file was found. Its Base64 copy is now in both `.env` files. In App Store Connect, check that the file belongs to a **Team API key**. A Team key works with Apple's notarization tool; an individual key does not. If this is not a Team key, create one under **Users and Access → Integrations → App Store Connect API → Team Keys**. An Account Holder or Admin may need to create it. The Account Holder must request access if API access is off. Download the Team `.p8` file once and keep a safe backup. See [Apple API key help](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).

Copy the matching Key ID to `APPLE_NOTARY_KEY_ID`. Copy the Issuer ID shown near the top of **Users and Access → Integrations → App Store Connect API** to `APPLE_NOTARY_ISSUER_ID`. Use the same two IDs in both apps.

Apple's notarization tool needs a Team API key. An individual API key does not work. An Account Holder or Admin may need to create the key. See [Apple API key help](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/) and [Developer ID certificate help](https://developer.apple.com/help/account/certificates/certificates-overview/).

To make Base64 text without printing it in Terminal:

```sh
base64 -i /private/path/file.p12 | tr -d '\n' > /private/path/file.p12.base64
```

Use the same command for the `.p8` file. Open the `.base64` file and copy its text into `.env`.

## GitBar's Sparkle key

A new GitBar-only key is saved in this ignored `.env` file and in your Keychain under `git-bar`. The public key in `Config/App.xcconfig` matches it. Do not use AeroSpace Tabs' key here.

GitHub hides the value of its current `SPARKLE_PRIVATE_KEY` secret. Replace it with the value from this `.env` before the first Sparkle release. Current GitBar releases did not use Sparkle, so this key does not need to support an older Sparkle installation.

See [Sparkle's publishing guide](https://sparkle-project.org/documentation/publishing/).

## Add the values to GitHub

Open **Settings → Secrets and variables → Actions** in this repository.

Add these four items under **Secrets**:

- `DEVELOPER_ID_CERTIFICATE_P12_BASE64`
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_NOTARY_KEY_P8_BASE64`
- `SPARKLE_PRIVATE_KEY`

Add these two items under **Variables**:

- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_ISSUER_ID`

## Keep the files safe

`.env` is plain text. It is ignored by Git and has file permission `600`. Keep it on this Mac and keep a separate encrypted backup of the original `.p12`, `.p8`, passwords, and private keys. Base64 does not protect a secret.

The Apple values are shared between both app repositories. The Sparkle private keys are different. If you replace an Apple key or certificate, update both repositories. If you replace a Sparkle key, update only GitBar's private key and `Config/App.xcconfig` public key.

`GITHUB_TOKEN` is supplied by GitHub Actions. Do not add it. `CODESIGN_IDENTITY` is optional for local work. It is not a GitHub setting.

## Check the settings

Before a signed check, confirm that all six values are set in `.env`. The Key ID must belong to the `.p8` file. If both apps use the same Team API key, use the same Key ID and Issuer ID in both repositories.

`make check` does not need release credentials. `make release-check APP_BUILD_NUMBER=<new-number>` signs a test build and sends it to Apple for notarization. It checks the Sparkle feed and does not publish a release.

Check setting names without viewing secret values:

```sh
gh secret list --repo pedrotmr/git-bar
gh variable list --repo pedrotmr/git-bar
```
