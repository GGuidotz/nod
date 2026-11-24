# frozen_string_literal: true

# Cask di Nod per il tap GGuidotz/homebrew-tap. Version e sha256 li aggiorna release.sh: non modificarli a mano.
cask "nod" do
  version "0.4.3"
  sha256 "e88f3d0ff8a55e3d53dffe83e4218f2b995488a2b22e92aca14b7a5f01710927"

  url "https://github.com/GGuidotz/nod/releases/download/v#{version}/Nod-#{version}.dmg"
  name "Nod"
  desc "Hands-free AI approvals and presence for Cocaine, with AirPods and Apple Watch"
  homepage "https://github.com/GGuidotz/nod"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Nod.app"

  postflight_steps do
    # L'app non è notarizzata (niente account Apple Developer): togliere la quarantena evita "Apri comunque".
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Nod.app"],
        writable_paths: ["{{appdir}}/Nod.app"],
        must_succeed:   false
  end

  uninstall quit: "local.nod.companion"

  zap trash: [
    "~/Library/Preferences/local.nod.companion.plist",
    "~/Library/Application Support/Nod",
  ]

  caveats <<~EOS
    Nod is signed with a local certificate, not by Apple. On first launch a guided setup asks for the
    permissions (Motion & Fitness for AirPods) and tests Apple Watch and notifications.
    It needs Cocaine: brew install --cask mattiakart/tap/cocaine
  EOS
end
