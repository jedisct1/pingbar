# Homebrew Cask PR Checklist

- Confirm the app is signed with a Developer ID certificate
- Confirm the app is notarized and stapled
- Confirm the release archive is universal (`arm64` and `x86_64`)
- Confirm the release asset name is `pingbar-<version>.tar.gz`
- Confirm `Info.plist` version matches the Git tag
- Confirm `CFBundleIdentifier` is `com.example.PingBar`
- Confirm `brew install --cask ./Casks/pingbar.rb` works locally
- Confirm `brew uninstall --cask pingbar` works locally
- Run `brew audit --new --cask ./Casks/pingbar.rb`
- Run `brew style --fix ./Casks/pingbar.rb`
- Check for prior rejected or open `pingbar` cask submissions in `homebrew/homebrew-cask`
- Be prepared for Homebrew notability review; current repo metrics may be below the self-submitted threshold

## Suggested Submission Steps

```bash
git clone https://github.com/Homebrew/homebrew-cask.git
cd homebrew-cask
git checkout -b pingbar-cask
cp /path/to/pingbar/Casks/pingbar.rb Casks/p/pingbar.rb
brew audit --new --cask Casks/p/pingbar.rb
brew style --fix Casks/p/pingbar.rb
git add Casks/p/pingbar.rb
git commit -m "pingbar 1.1.0 (new cask)"
```

## Important Current Risk

Homebrew's acceptable-casks policy applies a higher notability threshold to self-submitted casks. At the time of writing, the `jedisct1/pingbar` repository appears to be below that threshold, so the cask may still be rejected even if technically correct.
