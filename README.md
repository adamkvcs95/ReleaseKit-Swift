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

The modifier presents an iPhone sheet with navigation and a Done button. It shows your app icon, three-line release previews, dates and compact voting controls. Tap a release to open its complete notes and comments. List/detail votes share state. The host app’s CFBundleShortVersionString receives an Installed badge; when different, the server’s latestVersion receives a Latest badge. Version comparison normalizes trailing zeros. Tap the selected vote again to remove it, or the other direction to switch. Votes belong to the anonymous installation identity held in Keychain and are reloaded from the server when reopening or refreshing the changelog. Failed submissions restore the previous button/count state. No Apple or Appwrite account is required for the end user.

For an existing `NavigationStack`, use `ReleaseKitSettingsLink()` or push `ReleaseKitChangelogView()` directly. Pull to refresh; **Load more updates** loads older pages. Loading, empty, failure and unconfigured states are handled explicitly. Light/dark mode and Dynamic Type follow iOS.

Voting is available when the server advertises `features.votes=true`. The release-only server flag is `RK_ENABLE_RELEASE_VOTES=true`; it does not enable comments, comment voting or web writes. App-level bans, rate limits and attestation requirements still apply. The anonymous app key/installation identifier is not proof of a unique person or a genuine app installation; App Attest remains future work.

## Comments

`RK_ENABLE_SDK_COMMENTS=true` on the server and the app’s Comments setting enable native posting, guidelines acceptance, reporting and blocking. `Options.comments.isEnabled` defaults to true; set it to false to hide commenting in the host app. The demo enables it. This gate does not enable comment voting or browser writes.

Before the first post, the user accepts the community guidelines. The server assigns a stable random-style pseudonym (e.g. Sunny Otter AB12) scoped to the app and anonymous installation; the name is shown in the composer and on comments without exposing the installation ID. All new comments are pending developer review, visible immediately to their author and publicly only after approval. The composer preserves text on errors. Comments paginate in the detail view; long-press a visible comment for reply/report/block actions. The SDK retains the existing preview limit of three inline replies per thread.

## Demo

Open `Examples/ReleaseKitDemo/ReleaseKitDemo.xcodeproj`. Add an ignored `Examples/ReleaseKitDemo/Local.xcconfig`:

```xcconfig
RK_DEMO_APP_KEY = rk_pub_REPLACE_ME
RK_DEMO_BASE_URL = https:/$()/releasek.it
```

Run on an iPhone Simulator and tap **Open changelog**. The demo configures only the changelog flow and does not open the automatic What's New sheet. Debug launch argument `--show-changelog` opens it immediately.

## Validation and scope

`swift test` covers version decisions, optimistic vote transitions, shared API JSON contracts, request encoding, pagination and network errors. Build the `ReleaseKit` scheme for an iOS Simulator to compile UIKit/SwiftUI code. The canonical contract fixtures live in the web repository's `contracts/sdk/`; exact copies are included in this package's test fixtures.

Automatic What's New presentation remains available as an earlier preview API (`.releaseKitWhatsNew()`), but this iteration focuses on the explicit changelog view and release votes. Release details support comments, replies, reporting and blocking through the SDK. Comment voting, offline cache and App Attest are outside this release's completed scope. No stable 1.0.0 tag is published yet.

The privacy manifest declares anonymous installation identifiers and product interactions. Review your app's privacy declarations for the features you enable; enabling comments also submits the user’s comment text for moderation.
