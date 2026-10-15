# Beckon for macOS, as a Homebrew cask. It belongs in a tap of its own, in a repository named homebrew-beckon
# (as Casks/beckon.rb), so that people can run:
#
#   brew install --cask omsingh02/beckon/beckon
#
# scripts/update-package-manifests.sh <tag> fills in the version and the checksum from a release.
cask "beckon" do
  version "2.0.0-alpha.4"
  sha256 "72c417c09eea6596c17bc415b1d3b4fb8ffaecdddf8c86807b0071dca6291566"

  url "https://github.com/omsingh02/beckon/releases/download/v#{version}/beckon-v#{version}-macos-universal.dmg"
  name "Beckon"
  desc "Use an Android phone as a trackpad, keyboard and media remote"
  homepage "https://beckon.omsingh.me"

  depends_on macos: ">= :big_sur"

  app "Beckon.app"

  zap trash: [
    "~/Library/Application Support/Beckon",
    "~/Library/LaunchAgents/io.github.omsingh02.beckon.plist",
  ]

  caveats <<~EOS
    Beckon lives in the menu bar. Click its icon, then "Pair a phone...", and scan the QR code with the Beckon app.

    macOS asks to let Beckon control the computer (System Settings > Privacy & Security > Accessibility): allow it,
    or the phone cannot type or click.

    This build is not notarized yet. If macOS says it cannot verify Beckon, run
      xattr -dr com.apple.quarantine /Applications/Beckon.app
    or choose Open Anyway in System Settings > Privacy & Security.
  EOS
end
