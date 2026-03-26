cask "pingbar" do
  version "1.2.0"
  sha256 "5cc1bfad28f1c54d9db57b95378eb08b5a74f9a493c8490d802f278a24293f75"

  url "https://github.com/jedisct1/pingbar/releases/download/v#{version}/PingBar.zip",
      verified: "github.com/jedisct1/pingbar/"
  name "PingBar"
  desc "macOS menu bar application for network connectivity monitoring and DNS management"
  homepage "https://github.com/jedisct1/pingbar"

  depends_on macos: ">= :monterey"

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
