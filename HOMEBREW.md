# Homebrew Installation Guide

## Quick Installation

Install PingBar from a tap that includes `Casks/pingbar.rb`:

```bash
brew tap jedisct1/pingbar https://github.com/jedisct1/pingbar
brew install --cask jedisct1/pingbar/pingbar
open /Applications/PingBar.app
```

If you do not want to use Homebrew, you can also download the notarized app bundle directly from the [GitHub Releases](https://github.com/jedisct1/pingbar/releases) page.

## What Happens During Installation

1. Homebrew downloads the published `PingBar.zip` binary from the latest tagged release
2. Verifies the release checksum declared in `Casks/pingbar.rb`
3. Installs `PingBar.app` directly to `/Applications/PingBar.app`
4. Leaves build tools like Swift out of the installation path

## After Installation

- **Location**: `/Applications/PingBar.app`
- **Launch**: Use Spotlight, Applications folder, or `open /Applications/PingBar.app`
- **Permissions**: Grant admin privileges when prompted for DNS management features

## Uninstallation

```bash
brew uninstall --cask pingbar
```

The Cask installation automatically removes the app from `/Applications` and can clean up preferences.

## Troubleshooting

### Cask Not Found
If Homebrew cannot find the cask, make sure the tap is added and then install the fully-qualified cask name:

```bash
brew tap jedisct1/pingbar https://github.com/jedisct1/pingbar
brew install --cask jedisct1/pingbar/pingbar
```

### Download or Checksum Failures
- Run `brew update` to refresh tap metadata
- Confirm the latest GitHub release includes `PingBar.zip`
- Verify the `version` and `sha256` values in `Casks/pingbar.rb` match the published release asset

### Permission Issues
- Homebrew may prompt for your password to install to `/Applications`
- DNS changes inside PingBar still require admin privileges on first use

## Advanced Usage

### Check Cask Before Installing
```bash
brew audit --strict --cask jedisct1/pingbar/pingbar
```

### Force Reinstall
```bash
brew uninstall --cask pingbar
brew install --cask jedisct1/pingbar/pingbar
```

### View Installation Details
```bash
brew info jedisct1/pingbar/pingbar
```

## Why a Binary Cask?

Homebrew does not support arbitrary local-path cask installation as a general distribution mechanism. Using the published release binary keeps installs predictable and closer to standard Homebrew practice.

Benefits:
- Downloads the exact notarized release build
- Avoids requiring Swift or Xcode tools during installation
- Keeps install behavior consistent across machines
- Still allows the cask to live in the main repository or a dedicated tap

## Tap Layout

If you publish this cask through a dedicated tap, keep `pingbar.rb` under a top-level `Casks/` directory. Users can then install it with either:

```bash
brew install --cask jedisct1/pingbar/pingbar
```

or, after tapping first:

```bash
brew tap jedisct1/pingbar https://github.com/jedisct1/pingbar
brew install --cask pingbar
```
