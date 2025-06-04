# Installation Guide

## Homebrew Installation (Recommended)

### Install from Official Tap

```bash
# Add the PingBar tap
brew tap jedisct1/pingbar

# Install PingBar (automatically installs to /Applications)
brew install pingbar

# Launch PingBar
open /Applications/PingBar.app
```

**One-command installation:**
```bash
brew tap jedisct1/pingbar && brew install pingbar && open /Applications/PingBar.app
```

### Alternative: Install from Local Formula

If you want to build from source locally:

1. Clone this repository:
   ```bash
   git clone https://github.com/jedisct1/pingbar.git
   cd pingbar
   ```

2. Install using the local formula:
   ```bash
   brew install --build-from-source ./Formula/pingbar.rb
   ```

3. The app will be installed to `/Applications/PingBar.app`

4. Launch PingBar from Applications or Spotlight

## Manual Installation

### Prerequisites

- macOS Monterey (12.0) or later
- Xcode Command Line Tools or Xcode
- Swift 5.9 or later

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/jedisct1/pingbar.git
   cd pingbar
   ```

2. Build and create app bundle:
   ```bash
   make bundle
   ```

3. Install to Applications:
   ```bash
   make install
   ```

   Or manually copy:
   ```bash
   cp -r PingBar.app /Applications/
   ```

4. Launch PingBar from Applications or Spotlight

## Development Installation

For developers who want to work on PingBar:

1. Clone and build:
   ```bash
   git clone https://github.com/jedisct1/pingbar.git
   cd pingbar
   make build
   ```

2. Create a development link:
   ```bash
   ./bundle_pingbar_app.sh --link
   ```

3. Run tests (requires Xcode):
   ```bash
   make test
   ```

## First Launch

1. **Grant Permissions**: On first launch, macOS may ask for permissions
2. **DNS Management**: For DNS switching features, you'll need to enter your admin password
3. **Launch at Login**: Enable in Preferences if desired

## Uninstallation

### Homebrew
```bash
brew uninstall pingbar
brew untap jedisct1/pingbar  # Optional: remove the tap
rm -rf /Applications/PingBar.app
```

### Manual
```bash
make uninstall
# Or manually:
rm -rf /Applications/PingBar.app
```

## Troubleshooting

- **"PingBar can't be opened"**: Right-click → Open, then click "Open" again
- **DNS changes not working**: Ensure you're entering the correct admin password
- **App not starting**: Check Console.app for error messages
- **Build issues**: Ensure you have Xcode Command Line Tools: `xcode-select --install`

## Build Options

| Command              | Description               |
| -------------------- | ------------------------- |
| `make build`         | Debug build               |
| `make build-release` | Release build             |
| `make bundle`        | Create app bundle         |
| `make test`          | Run tests                 |
| `make clean`         | Clean build artifacts     |
| `make install`       | Install to /Applications  |
| `make uninstall`     | Remove from /Applications |
| `make archive`       | Create release archive    |