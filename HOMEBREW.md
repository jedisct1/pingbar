# Homebrew Installation Guide

## Quick Installation

```bash
brew tap jedisct1/pingbar
brew install --cask pingbar
open /Applications/PingBar.app
```

This installs from the PingBar tap. It does not mean PingBar is already in the official `homebrew/homebrew-cask` repository.

## What Happens During Installation

1. Homebrew downloads the pre-built universal release archive from GitHub Releases
2. Extracts the `PingBar.app` bundle
3. Installs PingBar.app to `/Applications/PingBar.app`

No compilation required -- the binary is ready to run immediately.

## Updating

```bash
brew upgrade --cask pingbar
```

## After Installation

- **Location**: `/Applications/PingBar.app`
- **Launch**: Use Spotlight, Applications folder, or `open /Applications/PingBar.app`
- **Permissions**: Grant admin privileges when prompted for DNS management features

## Uninstallation

```bash
brew uninstall --cask pingbar
```

The Cask uninstall automatically removes the app from `/Applications` and can clean up preferences.

## Troubleshooting

### Cask Not Found

Make sure you've tapped the repository first:
```bash
brew tap jedisct1/pingbar
```

### Download Failures

If the download fails, check that:
- You have a working internet connection
- GitHub is accessible from your network
- Try `brew update` first to refresh Homebrew metadata

### Permission Issues

- The formula requires admin privileges to install to `/Applications`
- You may be prompted for your password during installation

## Advanced Usage

### Force Reinstall

```bash
brew reinstall --cask pingbar
```

### View Installation Details

```bash
brew info --cask pingbar
```

### Build from Source Instead

If you prefer to build from source rather than using the pre-built binary:

```bash
git clone https://github.com/jedisct1/pingbar.git
cd pingbar
make install
```

See [INSTALL.md](INSTALL.md) for more build options.

## Official Homebrew Cask

This repository also contains an official-cask candidate at `Casks/pingbar.rb` and a submission checklist under `docs/homebrew-cask-pr-checklist.md`.
Acceptance into `homebrew/homebrew-cask` is reviewed by Homebrew maintainers and is not automatic.
