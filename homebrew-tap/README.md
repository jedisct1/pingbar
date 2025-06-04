# Homebrew Tap for PingBar

This is the official Homebrew tap for [PingBar](https://github.com/jedisct1/pingbar), a macOS menu bar application for network connectivity monitoring and DNS management.

## Installation

### Add the Tap and Install

```bash
brew tap jedisct1/pingbar
brew install pingbar
```

PingBar will be automatically installed to `/Applications/PingBar.app`.

### Launch PingBar

Launch PingBar from Applications, Spotlight, or the command line:

```bash
open /Applications/PingBar.app
```

## One-Command Installation

```bash
brew tap jedisct1/pingbar && brew install pingbar && open /Applications/PingBar.app
```

## Uninstallation

```bash
brew uninstall pingbar
brew untap jedisct1/pingbar
rm -rf /Applications/PingBar.app
```

## Requirements

- macOS Monterey (12.0) or later
- Homebrew

## Available Formulas

- **pingbar** - macOS menu bar application for network connectivity monitoring and DNS management

## Development

This tap installs PingBar by building it from source using Swift Package Manager.

## Issues

If you encounter any issues with the Homebrew installation, please report them at:
- [PingBar Issues](https://github.com/jedisct1/pingbar/issues)
- [Tap Issues](https://github.com/jedisct1/homebrew-pingbar/issues)

## Contributing

Contributions to improve the tap are welcome! Please submit pull requests to the [homebrew-pingbar repository](https://github.com/jedisct1/homebrew-pingbar).