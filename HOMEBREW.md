# Homebrew Installation Guide

## Quick Installation

```bash
git clone https://github.com/jedisct1/pingbar.git
cd pingbar
brew install --build-from-source ./Formula/pingbar.rb
open /Applications/PingBar.app
```

## What Happens During Installation

1. Homebrew downloads the PingBar source code
2. Builds PingBar using Swift Package Manager
3. Creates the app bundle structure
4. Installs PingBar.app directly to `/Applications/PingBar.app`
5. Sets proper permissions and makes the app executable

## After Installation

- **Location**: `/Applications/PingBar.app`
- **Launch**: Use Spotlight, Applications folder, or `open /Applications/PingBar.app`
- **Permissions**: Grant admin privileges when prompted for DNS management features

## Uninstallation

```bash
brew uninstall pingbar
```

This automatically removes PingBar from `/Applications`.

## Troubleshooting

### Formula Not Found
If you get "formula not found", ensure you're in the correct directory and using the relative path:
```bash
# Make sure you're in the pingbar directory
cd pingbar
ls Formula/pingbar.rb  # Should exist

# Use relative path to formula
brew install --build-from-source ./Formula/pingbar.rb
```

### Build Failures
- Ensure you have Xcode Command Line Tools: `xcode-select --install`
- Check that Swift is available: `swift --version`
- Verify macOS version is Monterey (12.0) or later

### Permission Issues
- The formula requires admin privileges to install to `/Applications`
- You may be prompted for your password during installation

## Advanced Usage

### Check Formula Before Installing
```bash
brew audit --strict ./Formula/pingbar.rb
```

### Force Reinstall
```bash
brew uninstall pingbar
brew install --build-from-source ./Formula/pingbar.rb
```

### View Installation Details
```bash
brew info pingbar
```

## Why Local Formula Installation?

This approach avoids the need to create and maintain a separate `homebrew-pingbar` tap repository. Users can install directly from the main PingBar repository using the included formula file.

Benefits:
- ✅ Single repository to maintain
- ✅ Formula stays in sync with source code
- ✅ No separate tap repository needed
- ✅ Still gets all Homebrew benefits (dependency management, uninstall, etc.)
- ✅ Works around Homebrew's URL installation restrictions

## Alternative: Create a Homebrew Tap

If you prefer the traditional `brew tap` approach, you would need to:

1. Create a separate `homebrew-pingbar` repository
2. Copy the formula files to that repository
3. Users could then run: `brew tap jedisct1/pingbar && brew install pingbar`

However, the local formula approach is simpler and equally effective.