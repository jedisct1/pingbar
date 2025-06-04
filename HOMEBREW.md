# Homebrew Installation Guide

## Quick Installation

```bash
git clone https://github.com/jedisct1/pingbar.git
cd pingbar
brew install --cask ./Casks/pingbar.rb
open /Applications/PingBar.app
```

## What Happens During Installation

1. Homebrew clones the PingBar source code locally
2. Builds PingBar using Swift Package Manager during the `preflight` phase
3. Creates the proper app bundle structure
4. Installs PingBar.app directly to `/Applications/PingBar.app`
5. Sets proper permissions and makes the app executable

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
If you get "cask not found", ensure you're in the correct directory and using the relative path:
```bash
# Make sure you're in the pingbar directory
cd pingbar
ls Casks/pingbar.rb  # Should exist

# Use relative path to cask
brew install --cask ./Casks/pingbar.rb
```

### Build Failures
- Ensure you have Xcode Command Line Tools: `xcode-select --install`
- Check that Swift is available: `swift --version`
- Verify macOS version is Monterey (12.0) or later

### Permission Issues
- The formula requires admin privileges to install to `/Applications`
- You may be prompted for your password during installation

## Advanced Usage

### Check Cask Before Installing
```bash
brew audit --strict --cask ./Casks/pingbar.rb
```

### Force Reinstall
```bash
brew uninstall --cask pingbar
brew install --cask ./Casks/pingbar.rb
```

### View Installation Details
```bash
brew info pingbar
```

## Why Local Cask Installation?

This approach avoids the need to create and maintain a separate `homebrew-pingbar` tap repository. Users can install directly from the main PingBar repository using the included Cask file.

Benefits:
- ✅ Single repository to maintain
- ✅ Cask stays in sync with source code
- ✅ No separate tap repository needed
- ✅ Direct `/Applications` installation
- ✅ Proper app bundle management
- ✅ Clean uninstall with preferences cleanup

## Alternative: Create a Homebrew Tap

If you prefer the traditional `brew tap` approach, you would need to:

1. Create a separate `homebrew-pingbar` repository
2. Copy the Cask file to that repository
3. Users could then run: `brew tap jedisct1/pingbar && brew install --cask pingbar`

However, the local Cask approach is simpler and equally effective.