cask "pingbar" do
  version "1.1.0"
  sha256 "1efd16cc6c6071ec2a84fefb006db8ee68c4f8c06c38376ded8999301780bfd2"

  url "https://github.com/jedisct1/pingbar/releases/download/v#{version}/pingbar-#{version}.tar.gz",
      verified: "github.com/jedisct1/pingbar/"
  name "PingBar"
  desc "Menu bar app for network connectivity and DNS monitoring"
  homepage "https://github.com/jedisct1/pingbar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :monterey"

  app "PingBar.app"

  zap trash: [
    "~/Library/Preferences/com.pingbar.app.plist",
    "~/Library/LaunchAgents/com.pingbar.app.plist",
  ]

  caveats <<~EOS
    PingBar has been installed to /Applications/PingBar.app

    To launch PingBar:
      open /Applications/PingBar.app

    On first launch:
      - Grant necessary permissions when prompted
      - DNS changes require admin privileges
  EOS
end
