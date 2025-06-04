cask "pingbar" do
  version :latest
  sha256 :no_check

  url "file://#{__dir__}/../", using: :git, branch: "main"
  name "PingBar"
  desc "macOS menu bar application for network connectivity monitoring and DNS management"
  homepage "https://github.com/jedisct1/pingbar"

  depends_on formula: "swift"
  depends_on macos: ">= :monterey"

  # Build the app during installation
  preflight do
    system_command "swift",
                   args: ["build", "-c", "release", "--disable-sandbox"],
                   chdir: staged_path

    # Create the app bundle structure
    app_bundle = staged_path/"PingBar.app"
    contents_dir = app_bundle/"Contents"
    macos_dir = contents_dir/"MacOS"
    resources_dir = contents_dir/"Resources"

    # Create directories
    FileUtils.mkdir_p(macos_dir)
    FileUtils.mkdir_p(resources_dir)

    # Copy executable
    FileUtils.cp(staged_path/".build/release/PingBar", macos_dir/"PingBar")

    # Copy Info.plist
    FileUtils.cp(staged_path/"Info.plist", contents_dir/"Info.plist")

    # Copy icon if it exists
    icon_path = staged_path/"PingBar.icns"
    FileUtils.cp(icon_path, resources_dir/"PingBar.icns") if File.exist?(icon_path)

    # Make executable
    File.chmod(0755, macos_dir/"PingBar")
  end

  app "PingBar.app"

  zap trash: [
    "~/Library/Preferences/com.pingbar.app.plist",
    "~/Library/LaunchAgents/com.pingbar.app.plist",
  ]

  caveats <<~EOS
    PingBar has been installed to /Applications/PingBar.app

    To launch PingBar:
      - Open from Applications folder, Spotlight, or:
        open /Applications/PingBar.app

    On first launch:
      - Grant necessary permissions when prompted
      - DNS changes require admin privileges

    To enable launch at login:
      - Open PingBar and go to Preferences
      - Check "Launch at Login"

    Note: Requires macOS Monterey (12.0) or later.
  EOS
end