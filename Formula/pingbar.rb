class Pingbar < Formula
  desc "macOS menu bar application for network connectivity monitoring and DNS management"
  homepage "https://github.com/jedisct1/pingbar"
  url "https://github.com/jedisct1/pingbar/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "YOUR_SHA256_HERE"
  license "MIT"

  depends_on "swift" => :build
  depends_on :macos => :monterey

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    
    # Create the app bundle structure in Applications
    app_bundle = "/Applications/PingBar.app"
    contents_dir = "#{app_bundle}/Contents"
    macos_dir = "#{contents_dir}/MacOS"
    resources_dir = "#{contents_dir}/Resources"
    
    # Create directories
    mkdir_p macos_dir
    mkdir_p resources_dir
    
    # Copy executable
    cp ".build/release/PingBar", "#{macos_dir}/PingBar"
    
    # Copy Info.plist
    cp "Info.plist", "#{contents_dir}/Info.plist"
    
    # Copy icon if it exists
    cp "PingBar.icns", "#{resources_dir}/PingBar.icns" if File.exist?("PingBar.icns")
    
    # Make executable
    chmod "+x", "#{macos_dir}/PingBar"
  end

  def caveats
    <<~EOS
      PingBar has been installed to:
        /Applications/PingBar.app

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

  test do
    # Verify the app bundle was created correctly
    assert_predicate Pathname.new("/Applications/PingBar.app"), :exist?
    assert_predicate Pathname.new("/Applications/PingBar.app/Contents/MacOS/PingBar"), :exist?
    assert_predicate Pathname.new("/Applications/PingBar.app/Contents/MacOS/PingBar"), :executable?
    assert_predicate Pathname.new("/Applications/PingBar.app/Contents/Info.plist"), :exist?
    
    # Verify Info.plist contains expected keys
    plist_content = File.read("/Applications/PingBar.app/Contents/Info.plist")
    assert_match(/CFBundleName/, plist_content)
    assert_match(/PingBar/, plist_content)
    assert_match(/LSUIElement/, plist_content)
  end
end