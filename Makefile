.PHONY: build build-release test bundle clean install uninstall archive

# Default target
build:
	swift build

# Build release version
build-release:
	swift build -c release

# Run tests (requires Xcode)
test:
	swift test

# Create app bundle
bundle: build-release
	./bundle_pingbar_app.sh

# Clean build artifacts
clean:
	swift package clean
	rm -rf PingBar.app
	rm -rf *.tar.gz

# Install to /Applications (requires bundle)
install: bundle
	cp -r PingBar.app /Applications/

# Uninstall from /Applications
uninstall:
	rm -rf /Applications/PingBar.app

# Create release archive for Homebrew
archive: bundle
	tar -czf pingbar-$(shell grep -A1 "CFBundleShortVersionString" Info.plist | grep -o '[0-9.]*').tar.gz PingBar.app

# Help target
help:
	@echo "Available targets:"
	@echo "  build         - Build debug version"
	@echo "  build-release - Build release version"
	@echo "  test          - Run tests (requires Xcode)"
	@echo "  bundle        - Create PingBar.app bundle"
	@echo "  clean         - Clean build artifacts"
	@echo "  install       - Install to /Applications"
	@echo "  uninstall     - Remove from /Applications"
	@echo "  archive       - Create release archive"
	@echo "  help          - Show this help message"