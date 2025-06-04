# Setting Up the PingBar Homebrew Tap

This guide explains how to set up and maintain the PingBar Homebrew tap.

## Initial Setup

### 1. Create the Tap Repository

Create a new GitHub repository named `homebrew-pingbar` (the `homebrew-` prefix is required):

```bash
# Create and clone the tap repository
git clone https://github.com/jedisct1/homebrew-pingbar.git
cd homebrew-pingbar
```

### 2. Copy Tap Files

Copy the tap files from your PingBar project:

```bash
# From your pingbar project directory
cp -r homebrew-tap/* /path/to/homebrew-pingbar/

# Or if you're in the tap repo:
cp -r /path/to/pingbar/homebrew-tap/* .
```

### 3. Initial Commit

```bash
git add .
git commit -m "Initial PingBar tap setup"
git push origin main
```

## Repository Structure

Your `homebrew-pingbar` repository should have this structure:

```
homebrew-pingbar/
├── README.md
├── SETUP.md (this file)
└── Formula/
    └── pingbar.rb
```

## Formula Configuration

### For Development/HEAD Builds

The current formula is configured to build from the `main` branch:

```ruby
head "https://github.com/jedisct1/pingbar.git", branch: "main"
```

### For Stable Releases

When you create releases, update the formula:

```ruby
url "https://github.com/jedisct1/pingbar/archive/refs/tags/v1.0.0.tar.gz"
sha256 "YOUR_SHA256_HERE"
version "1.0.0"
```

To generate the SHA256:
```bash
curl -L https://github.com/jedisct1/pingbar/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
```

## Testing the Tap

### Local Testing

```bash
# Test the formula syntax
brew audit --strict Formula/pingbar.rb

# Test installation locally
brew install --build-from-source Formula/pingbar.rb

# Test uninstallation
brew uninstall pingbar
```

### Test Installation from GitHub

```bash
# Test the tap installation
brew tap jedisct1/pingbar https://github.com/jedisct1/homebrew-pingbar.git
brew install pingbar
```

## Publishing Updates

### 1. Update the Formula

Edit `Formula/pingbar.rb` as needed for new versions or fixes.

### 2. Test Changes

```bash
brew audit --strict Formula/pingbar.rb
brew install --build-from-source Formula/pingbar.rb
```

### 3. Commit and Push

```bash
git add Formula/pingbar.rb
git commit -m "Update pingbar to version X.Y.Z"
git push origin main
```

### 4. Update Users

Users will automatically get updates when they run:
```bash
brew update
brew upgrade pingbar
```

## Release Workflow

### 1. Tag a Release in Main Repository

```bash
cd /path/to/pingbar
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### 2. Create GitHub Release

Create a release on GitHub for the tag, which will generate the archive URL.

### 3. Update Tap Formula

```bash
cd /path/to/homebrew-pingbar

# Calculate SHA256
curl -L https://github.com/jedisct1/pingbar/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256

# Update Formula/pingbar.rb with new URL, version, and SHA256
# Commit and push the changes
```

## Maintenance

### Version Updates

1. Update the main PingBar repository
2. Create a new release/tag
3. Update the tap formula with new version and SHA256
4. Test the installation
5. Push the tap updates

### Formula Validation

Regularly run:
```bash
brew audit --strict Formula/pingbar.rb
brew style Formula/pingbar.rb
```

## Troubleshooting

### Common Issues

1. **Build failures**: Check Swift version requirements and dependencies
2. **Missing files**: Ensure all required files are included in the source
3. **Permission issues**: Verify app bundle permissions are set correctly

### Testing Locally

```bash
# Remove any existing installation
brew uninstall pingbar 2>/dev/null || true
brew untap jedisct1/pingbar 2>/dev/null || true

# Fresh install test
brew tap jedisct1/pingbar
brew install pingbar
```

## Best Practices

1. **Test thoroughly** before pushing updates
2. **Use semantic versioning** for releases
3. **Document changes** in commit messages
4. **Keep formula simple** and focused
5. **Monitor issues** on both repositories

## Support

- [Homebrew Documentation](https://docs.brew.sh/)
- [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Tap Documentation](https://docs.brew.sh/Taps)