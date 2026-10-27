# ReleaseKit for iOS — Integration Guide for Coding Agents

> This file is written for AI coding agents (Codex, Claude Code, Cursor, Copilot, etc.) and humans in a hurry.
> Goal: integrate ReleaseKit into an existing iOS app **in one pass** without asking questions.
> Package: `https://github.com/<OWNER>/ReleaseKit-Swift` · Product: `ReleaseKit` · Min iOS 17 · Zero dependencies.

## What ReleaseKit does
- Shows a native **"What's new" sheet** once, the first time a user opens a new App Store version (never on a fresh install).
- Provides a native **changelog view** (all releases, votes, comments) for your Settings screen.
- Release notes are fetched automatically from the App Store — the app developer writes nothing extra.

## Inputs you need (ask the human ONLY if not found in the repo)
| Input | Where to find it | Example |
|---|---|---|
| Public app key | ReleaseKit dashboard → App → Install. It is **not secret**; it may be committed. | `rk_pub_8fK2mQ...` |
| Base URL (optional) | Only for staging/self-hosting. Default is `https://releasek.it`. | `http://203.0.113.10:8080` |

If no key is available, insert the placeholder `"rk_pub_REPLACE_ME"` and add a `// TODO(ReleaseKit): paste public app key from dashboard` comment. Do not invent a key.

## Step 1 — Add the package
**Xcode project (`.xcodeproj`):** File → Add Package Dependencies… → URL `https://github.com/<OWNER>/ReleaseKit-Swift` → Dependency rule "Up to Next Major Version" from `1.0.0` → add product **ReleaseKit** to the app target.

If you are editing `project.pbxproj` programmatically, add an `XCRemoteSwiftPackageReference` with `repositoryURL = "https://github.com/<OWNER>/ReleaseKit-Swift"` and `requirement = { kind = upToNextMajorVersion; minimumVersion = 1.0.0; }`, plus an `XCSwiftPackageProductDependency` `productName = ReleaseKit` linked to the app target's frameworks build phase. Prefer the Xcode UI or a tool like `xcodeproj`/`tuist` if available.

**Swift package / Tuist / XcodeGen:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/<OWNER>/ReleaseKit-Swift", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "ReleaseKit", package: "ReleaseKit-Swift")])
]
```
```yaml
# XcodeGen project.yml
packages:
  ReleaseKit:
    url: https://github.com/<OWNER>/ReleaseKit-Swift
    from: 1.0.0
targets:
  MyApp:
    dependencies:
      - package: ReleaseKit
```
Deployment target must be **iOS 17.0 or later**. If the app targets lower, stop and tell the human.

## Step 2 — Configure at launch
Find the `@main` `App` struct (SwiftUI) and add an `init`. If an `init` exists, add the line at its top.
```swift
import SwiftUI
import ReleaseKit

@main
struct MyApp: App {
    init() {
        ReleaseKit.configure(appKey: "rk_pub_REPLACE_ME")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .releaseKitWhatsNew()   // Step 3
        }
    }
}
```
**UIKit app (AppDelegate/SceneDelegate):** call `ReleaseKit.configure(appKey:)` in `application(_:didFinishLaunchingWithOptions:)`. For the sheet, wrap the root in a `UIHostingController` that applies `.releaseKitWhatsNew()`, or call `await ReleaseKit.presentWhatsNewIfNeeded()` from the root view controller's `viewDidAppear` (it presents on the key window's top view controller).

Optional configuration (only if the human asks or the app has an obvious "existing user" signal):
```swift
ReleaseKit.configure(appKey: "rk_pub_REPLACE_ME", options: .init(
    whatsNew: .init(treatFirstLaunchAsUpdate: { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") })
))
```
`treatFirstLaunchAsUpdate` matters only for the first app update that ships ReleaseKit: return `true` when you can tell the user already used the app before, so they still see "What's new".

## Step 3 — Show the "What's new" sheet
Attach `.releaseKitWhatsNew()` **once**, to the root view inside `WindowGroup` (see Step 2). Do not attach it to multiple views. If the app shows onboarding/paywall on first screen, attach it to the main content view that appears after onboarding instead, or call `await ReleaseKit.presentWhatsNewIfNeeded()` when onboarding finishes.

## Step 4 — Add a Settings entry
In the app's settings screen (search for `Form`, `List` with "Settings", or `SettingsView`), add:
```swift
Section {
    ReleaseKitSettingsLink()          // NavigationLink → ReleaseKitChangelogView, label "What's New"
}
```
The settings screen must be inside a `NavigationStack` (it usually is). If there is no settings screen, present it from any menu:
```swift
.sheet(isPresented: $showChangelog) { NavigationStack { ReleaseKitChangelogView() } }
```

## Step 5 — Privacy label (tell the human)
ReleaseKit ships its own `PrivacyInfo.xcprivacy`. In App Store Connect → App Privacy, the app owner should declare (all **not linked** to identity, **not** used for tracking):
- User Content → Other User Content (App Functionality) — comments
- Usage Data → Product Interaction (Analytics, App Functionality) — sheet views, votes
- Identifiers → Device ID (App Functionality) — random anonymous install ID

ReleaseKit's UI already includes report, block, content filtering, community guidelines consent and developer contact (App Store Guideline 1.2). Make sure the developer contact email is set in the ReleaseKit dashboard.

## Step 6 — Verify (checklist)
- [ ] Project builds for iOS Simulator with no new warnings from ReleaseKit.
- [ ] `import ReleaseKit` present only in files that use it.
- [ ] `ReleaseKit.configure` called exactly once, before any ReleaseKit view appears.
- [ ] `.releaseKitWhatsNew()` attached exactly once at the root.
- [ ] `ReleaseKitSettingsLink()` visible in Settings and opens the changelog (shows releases or a "No updates yet" state — never crashes, even offline).
- [ ] Fresh install → **no** sheet on first launch (expected).
- [ ] To preview the sheet in DEBUG: temporarily set `options: .init(whatsNew: .init(debugAlwaysShow: true))`, run, confirm sheet appears at half height with votes and "All updates", then **revert** that flag.
- [ ] No secrets were added (the public app key is not a secret).

## Troubleshooting
| Symptom | Fix |
|---|---|
| `No such module 'ReleaseKit'` | Product not linked to the app target; re-add product **ReleaseKit** to target. |
| Sheet never shows | Expected on fresh install and when the installed version isn't live on the App Store yet (TestFlight). Use `debugAlwaysShow`. |
| Changelog empty | App not registered or key wrong → console log `[ReleaseKit] invalid_app_key`. |
| Build error about iOS version | Raise deployment target to iOS 17. |

## API surface (complete)
```swift
ReleaseKit.configure(appKey: String, options: ReleaseKit.Options = .init())
View.releaseKitWhatsNew(isEnabled: Bool = true, onPresent: ((String) -> Void)? = nil, onDismiss: (() -> Void)? = nil)
ReleaseKitChangelogView()
ReleaseKitSettingsLink()  /  ReleaseKitSettingsLink { label }
await ReleaseKit.presentWhatsNewIfNeeded()
ReleaseKit.webChangelogURL: URL?
ReleaseKit.resetLocalState()   // debug only
```
