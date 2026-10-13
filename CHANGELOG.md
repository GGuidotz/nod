# Changelog

All notable changes to Nod. The app shows the sections newer than the last version you opened (Sources/Changelog.swift).
Format: `## <version> · <date>`, then `### New Features`, `### Improvements`, `### Bug Fixes`, `### Security`,
`### Known Issues`, one `- ` line per change.

## 0.4.1 · 2026-10-13

### Improvements
- Confirmations are built for when you are away from the Mac. After a nod with AirPods, Nod now also sends the ntfy notification (Approve / Deny) and, if enabled, the "Approve: …" reminder, not only the Watch prompt at the Mac.
- The Watch side-button double-click is marked as experimental, waiting for a fix from Apple. The notice appears for everyone in Setup, Devices and Diagnostics, and the Apple Watch setup step is shown again after this update.
- Setup and Approvals texts now point to the notification and the reminder as the way to answer from the Watch.

### Bug Fixes
- A double-click that macOS 27 reports as "cancelled" no longer denies the request. It has the same code as Deny in the system prompt, so while a notification or reminder is open the system prompt cannot deny: deny from the ntfy notification.

### Known Issues
- Watch side-button double-click: on macOS 27 the system closes the prompt but answers "cancelled" to every app, Apple's included. We are waiting for a fix from Apple. Answer from the Watch with the ntfy notification, or approve by completing the reminder.
- Reminders can only approve: to deny, use the ntfy notification, or let the request expire (nothing happens).

## 0.4.0 · 2026-10-12

### New Features
- Answer from the Apple Watch by completing a reminder, a native round trip with nothing to install. Watch-only approvals create "Approve: …" and completing it approves. "You're stepping away" creates "Keep the Mac awake?" and completing it keeps the Mac awake. Nod listens for `EKEventStoreChanged` and polls every 5 s while a request is open.
- Completion counts only for a reminder Nod created, before it expires, once, matched by identifier or an embedded reference. The reminder is deleted after the answer or on expiry, and a deleted or expired reminder does nothing.
- The Reminders test is a round trip: complete the test reminder on the Watch and Nod reports how many seconds it took. The Notifications setup step is shown again for this.

### Improvements
- Guided-test diagnosis: when every policy returns `userCancel`, `userFallback` or `authenticationFailed` after a real double-click, Nod says the Watch double-click is not confirmed by macOS on this Mac and points to Reminders and Touch ID.
- "Copy text for Feedback Assistant" in Diagnostics: a ready-made report for Apple with the macOS version, Mac model and the recent attempts.

### Bug Fixes
- Removed the `LARight` method: on macOS 27.0.1 its prompt never appeared, and the app waited two minutes before failing with `ViewBridge error 17`.

### Known Issues
- On macOS 27.0.1 with this Mac and Watch, the Watch double-click closes the LocalAuthentication prompt but returns `userCancel` to every app, Apple's osascript included. Approve by completing the reminder on the Watch, or with Touch ID.

## 0.3.3 · 2026-10-12

### Improvements
- Two more confirmation paths to try: `deviceOwnerAuthentication` ("Touch ID, Watch or password", policy 2), which is now part of the automatic chain after Touch ID or Watch, and `LARight` (`authorize(localizedReason:)`, default requirement), available from Diagnostics.
- Guided double-click test in Diagnostics. Before each method Nod says "now double-click the Watch, don't touch the Mac", then records the outcome and `LAError` code in a table that is also added to the report.
- The osascript probe runs with both policy 3 (watch only) and policy 2 (device owner).
- When a forced method returns `userFallback`, Diagnostics suggests going back to Automatic.

### Bug Fixes
- The fallback button is now hidden on watch-only and Touch ID or Watch prompts (`localizedFallbackTitle = ""`). On macOS 27.0.1 the Watch double-click was coming back as `userFallback` (-3) instead of success.
- `LAError` codes are named in the log and report, `userFallback` included, and a `userFallback` is explained as "not recognized as a confirmation". It never counts as an approval.

### Known Issues
- On macOS 27.0.1 the Watch double-click can close the Mac prompt yet return `userFallback` or `userCancel`, even for Apple-signed processes. If no method in the guided test returns "Confirmed", approvals at the Mac use Touch ID.

## 0.3.2 · 2026-10-12

### New Features
- Reminders alerts: an optional second channel to the iPhone and Apple Watch with nothing to install. Nod creates a reminder with an immediate alarm in a dedicated iCloud "Nod" list (EventKit, full Reminders access). iCloud syncs it, usually within a minute, and Nod deletes it once the request is answered or expires. It is used for Watch-only approvals, the "You're stepping away" prompt and the test. Reminders have no buttons: answers come from Touch ID at the Mac or the ntfy notification.
- Reminders controls in Settings > Notifications, in the Notifications setup step (shown again after this update) and in Diagnostics, with access request and a test.

### Improvements
- Watch approval refused system-wide is now recognized. When the Apple-signed osascript probe is refused instantly, Nod says that macOS refuses Watch approval for every app on this Mac, rather than blaming its own signature. The result persists across launches, and the remaining system remedies are listed.
- ntfy buttons stay valid for 10 minutes on the test and 5 minutes on approvals, up from 2. A late reply is still ignored, but it is reported with its delay: this proves the buttons reach the Mac even when the alert itself arrives late.
- The ntfy alert checklist starts with the usual fix for messages that appear only inside the app: reinstall ntfy, allow notifications and subscribe again.
- The diagnostics report gains a Reminders section and summary lines for system-level Watch refusal, late replies and a local-only Reminders list.

### Bug Fixes
- The classic Dock icon forced in 0.3.0 as a workaround is turned off once, at the first launch of 0.3.2, when the Liquid Glass icon renders correctly. The option stays available in Diagnostics, and the automatic fallback remains.

### Known Issues
- On some Mac and Watch configurations, macOS refuses Watch approval for every app, Apple's included. Nod then approves with Touch ID at the Mac and relies on ntfy and Reminders when you are away.

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
