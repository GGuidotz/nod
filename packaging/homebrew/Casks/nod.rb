# frozen_string_literal: true

# Cask di Nod per il tap GGuidotz/homebrew-tap. Version e sha256 li aggiorna release.sh: non modificarli a mano.
cask "nod" do
  version "0.4.1"
  sha256 "262bb982802cd5ee930d6ac4133b9ed915de78f6f88cc29c26b107708df9856f"

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
    Nod è firmato con un certificato locale, non da Apple. Al primo avvio una configurazione guidata
    chiede i permessi (Movimento e fitness per le AirPods) e prova Apple Watch e notifiche.
    Serve Cocaine: brew install --cask mattiakart/tap/cocaine
  EOS
end
