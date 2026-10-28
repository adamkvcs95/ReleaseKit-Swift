# ReleaseKit for iOS

A native changelog with release notes and up/down votes. iOS 17+, Swift 6, no third-party dependencies. This is a development preview; use the `main` branch while the first versioned release is being prepared.

## Add the package

In Xcode, add `https://github.com/adamkvcs95/ReleaseKit-Swift`, choose the **main branch**, and link the **ReleaseKit** product. Copy your public app key from ReleaseKit → your app → SDK installation. This is an app identifier, not an Appwrite API key or an Apple private key.

## Open the changelog

```swift
import SwiftUI
import ReleaseKit

@main
struct MyApp: App {
    init() {
        ReleaseKit.configure(appKey: "rk_pub_REPLACE_ME")
    }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var showUpdates = false
    var body: some View {
        Button("What's New") { showUpdates = true }
            .releaseKitChangelog(isPresented: $showUpdates)
    }
}
```

The modifier presents an iPhone sheet with navigation and a Done button. It shows your app icon, complete release notes, dates and voting controls. Tap the selected vote again to remove it, or the other direction to switch. Votes belong to the anonymous installation identity held in Keychain and are reloaded from the server when reopening or refreshing the changelog. Failed submissions restore the previous button/count state. No Apple or Appwrite account is required for the end user.

For an existing `NavigationStack`, use `ReleaseKitSettingsLink()` or push `ReleaseKitChangelogView()` directly. Pull to refresh; **Load more updates** loads older pages. Loading, empty, failure and unconfigured states are handled explicitly. Light/dark mode and Dynamic Type follow iOS.

Voting is available when the server advertises `features.votes=true`. The release-only server flag is `RK_ENABLE_RELEASE_VOTES=true`; it does not enable comments, comment voting or web writes. App-level bans, rate limits and attestation requirements still apply. The anonymous app key/installation identifier is not proof of a unique person or a genuine app installation; App Attest remains future work.

## Demo

Open `Examples/ReleaseKitDemo/ReleaseKitDemo.xcodeproj`. Add an ignored `Examples/ReleaseKitDemo/Local.xcconfig`:

```xcconfig
RK_DEMO_APP_KEY = rk_pub_REPLACE_ME
RK_DEMO_BASE_URL = https:/$()/releasek.it
```

Run on an iPhone Simulator and tap **Open changelog**. The demo configures only the changelog flow and does not open the automatic What's New sheet. Debug launch argument `--show-changelog` opens it immediately.

## Validation and scope

`swift test` covers version decisions, optimistic vote transitions, shared API JSON contracts, request encoding, pagination and network errors. Build the `ReleaseKit` scheme for an iOS Simulator to compile UIKit/SwiftUI code. The canonical contract fixtures live in the web repository's `contracts/sdk/`; exact copies are included in this package's test fixtures.

Automatic What's New presentation remains available as an earlier preview API (`.releaseKitWhatsNew()`), but this iteration focuses on the explicit changelog view and release votes. Comments, reports, blocking, offline cache and App Attest are outside this release's completed scope. No stable 1.0.0 tag is published yet.

The privacy manifest declares anonymous installation identifiers and product interactions. Review your app's privacy declarations for the features you enable; this preview's changelog/voting flow does not submit comment text.
