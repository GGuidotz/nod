# Changelog

All notable changes to Nod. The app shows the sections newer than the last version you opened (Sources/Changelog.swift).
Format: `## <version> · <date>`, then `### New Features`, `### Improvements`, `### Bug Fixes`, `### Security`,
`### Known Issues`, one `- ` line per change.

## 0.3.1 · 2026-10-12

### Improvements
- Apple Watch confirmation uses an automatic policy chain, `deviceOwnerAuthenticationWithBiometricsOrCompanion` → `deviceOwnerAuthenticationWithCompanion` → `deviceOwnerAuthenticationWithWatch`, restricted to the policies the Mac can evaluate. A policy that fails within 1.5 s with `authenticationFailed`, `biometryNotAvailable` or `watchNotAvailable` falls through to the next one. The last policy that succeeded is remembered and tried first.
- New "Test the Watch via osascript" diagnostic: it runs the same LocalAuthentication request from an Apple-signed process (`Resources/Scripts/watch-probe.js`) to tell whether macOS refuses Watch approval for the locally signed app. A Terminal equivalent is `xcrun swift tools/watch-probe.swift`.
- The Watch troubleshooting checklist (system setting, wrist detection, Bluetooth, Apple Account, comparison with an Apple app) appears in Devices, Setup and Diagnostics when watch-only policies fail instantly.
- The diagnostics report opens with an automatic summary of detected problems. It also adds a dedicated Icon section (tier, build check, measured coverage, Dock fallback) and the Watch policy chain, learned method, raw policy values and the osascript probe result.
- The ntfy alert checklist is shared by Setup and Diagnostics. New items: Immediate Delivery instead of Scheduled Summary, and a push test with the ntfy app closed (re-subscribe and enable Background App Refresh if messages only appear when the app opens).

### Bug Fixes
- The ntfy server check no longer reports false negatives. ntfy.sh writes messages to its cache in batches, so the check now retries after 1, 3 and 6 s, bypasses the URLSession cache, parses each JSON line and logs the attempt that found the message.
- Liquid Glass icon: `Nod.icon/icon.json` now follows the structure Icon Composer writes.
  - The background is a document-level `fill` gradient instead of a full-canvas image layer.
  - Every layer has an explicit `position`.
  - `supported-platforms` uses `"squares": "shared"`, and glass groups enable `specular`.
- Liquid Glass icon: `build.sh` now invokes `actool` with the same options as Xcode. It then renders the bundle icon through IconServices from a fresh copy of the app (`tools/icon-check`, built with `Sources/IconMetrics.swift`), the same path the Dock uses.
  - If the icon is nearly transparent or identical to the generic app icon, the build falls back to the classic `.icns`.
  - The build writes previews to `build/icon-preview.png` and `build/icon-actool.png`.
- Liquid Glass icon: at launch, Nod measures the icon the Dock draws and automatically applies the bundled classic icon when it is blank. Nod no longer resets `NSApp.applicationIconImage` when no fallback is needed.

### Known Issues
- If watch-only policies keep failing instantly while the osascript probe succeeds, macOS is refusing Watch approval for the locally signed app. Touch ID approval at the Mac works meanwhile.
- The ntfy server check cannot detect delivery problems on the iPhone (notification settings, Focus, Scheduled Summary). Use the checklist.

## 0.3.0 · 2026-10-12

### New Features
- Diagnostics panel: an automatically compiled, secret-free report (app, macOS, signing, icon tier, LocalAuthentication policy availability, ntfy delivery, presence and a rolling event log) that can be copied, saved, emailed or attached to a GitHub issue.
- Localization in Italian, English, French and Spanish, following the system language with an in-app override that applies instantly.
- Update checks: on launch, every 6 hours and on demand, against `VERSION` and `CHANGELOG.md` on `main`; shows the release notes before updating, with a copyable update command and a one-click "Update in Terminal" action (Homebrew and source builds detected automatically).
- "Try every Watch method" diagnostic, which evaluates each LocalAuthentication policy in turn and records which one succeeds, plus a persistent confirmation-method override.
- Server-side delivery check after every ntfy publish (`poll` request on the topic), distinguishing "not sent by the Mac" from "not displayed by the iPhone".

### Improvements
- Apple Watch confirmation now prefers `deviceOwnerAuthenticationWithCompanion` on macOS 15 and later, falling back to the deprecated watch-only policy; every attempt is logged with duration and `LAError` code, and a prompt closed by the system within 1.5 s is retried once with Nod brought to the front.
- Notifications step: explicit guidance to use the official ntfy app (not "Ntfy me", a separate service), with the topic name ready to copy and a direct App Store link.
- Liquid Glass icon rebuilt from PNG layers; `build.sh` accepts the compiled asset catalog only when it actually contains the `Nod` icon and otherwise falls back to the classic `.icns`.
- Changelog restructured into sections, rendered with per-section symbols.

### Bug Fixes
- Blank Dock icon while the app is running: invalid asset catalogs are no longer shipped, Launch Services is refreshed on install, and a "Use classic Dock icon" option is available as a fallback.

### Known Issues
- Real AI approval requests are not yet wired to Cocaine; the approval flow runs in demo mode.
- Liquid Glass icon compilation requires Xcode; command-line-tools-only builds use the classic icon.

## 0.2.0 · 2026-10-12

### New Features
- Watch-only approvals: without AirPods, the Apple Watch side-button prompt and an ntfy notification with Approve / Deny are issued together; the first answer wins and dismisses the other.
- Liquid Glass app icon (Icon Composer layers, compiled with `actool` when Xcode is available) with a rendered `.icns` fallback.
- Custom template menu bar glyph with Filled and Outline styles and per-state variants (at the Mac, leaving, away).
- Appearance setting: System, Light or Dark.
- About panel and Settings > Info with developer credits.

### Improvements
- Redesigned setup: animated aurora background, a single glass control bar, live visual feedback for every step.
- Notification checklist with a live round-trip check.
- Approval and "stepping away" notifications are published at maximum priority (5).

### Bug Fixes
- Apple Watch confirmation prompt closing immediately: the `LAContext` is now retained for the whole evaluation; "Deny" in the system prompt counts as a refusal.

## 0.1.0 · 2026-10-11

### New Features
- First release: menu bar app with main window, guided setup and post-update "What's New".
- Presence engine: detects when you step away (idle time, walking with AirPods, AirPods disconnected, screen locked) and asks on the Apple Watch whether to keep the Mac awake; a rule (watched app, weekdays, time window) decides when you don't answer.
- Approval flow demo: nod with AirPods, confirm with the Apple Watch side button, shake to deny.
- Notifications through ntfy.sh or a self-hosted server, with single-use action tokens.
