# ReleaseKit for iOS

Native changelog, automatic What's New, release/comment voting and community comments. iOS 17+, Swift 6, system frameworks only.

**Stable version: 1.0.1.** App Attest is experimental, disabled by default and excluded from the stable feature scope. See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for validation and remaining experimental checks.

## Install

Add `https://github.com/adamkvcs95/ReleaseKit-Swift` in Xcode, select **Up to Next Major Version** from `1.0.1` (or **Exact Version** `1.0.1`), and link **ReleaseKit**. Use the public `rk_pub_…` app key from ReleaseKit → your app → SDK installation. Never use an Appwrite key or Apple .p8 private key.

```swift
import SwiftUI
import ReleaseKit

@main
struct MyApp: App {
    init() { ReleaseKit.configure(appKey: "rk_pub_REPLACE_ME") }
    var body: some Scene {
        WindowGroup { ContentView().releaseKitWhatsNew() }
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

Use `ReleaseKitSettingsLink()` or `ReleaseKitChangelogView()` inside an existing NavigationStack. Configure once before presenting SDK UI. Use one `.releaseKitWhatsNew()` modifier per scene; `ReleaseKit.presentWhatsNewIfNeeded()` is also available for UIKit.

## What's New

First install records the version without interrupting the user. A subsequent version change fetches that installed version's release notes and presents once. A downgrade is skipped; a release is marked handled only after its sheet appears. Hidden releases are skipped, unavailable notes retry on subsequent attempts with bounded pending-state lifetimes. State is stored separately for each endpoint/app key/installation. Concurrent presentation attempts are guarded.

`Options.whatsNew` controls enabled state, delay, first-launch opt-in and debug force-show. The app's Info.plist `CFBundleShortVersionString` is the source of the installed version. The changelog uses three-line previews with 10-point spacing, Installed/Latest badges, dates, counts and outlined vote capsules (up triangle, net score, divider, down triangle; filled selection with blue accents) and a neighboring comment-count capsule; details show complete notes. Toolbar actions use adaptive primary colors (dark in light mode, light in dark mode); content accents remain blue and Installed stays green. The top ellipsis menu opens Community guidelines and Contact developer. The bottom-right square.and.pencil icon opens comment composition. There is no detail footer branding.

The automatic What's New sheet shows the app icon above its title and opens at a 65% presentation detent, expandable to large in both SwiftUI and UIKit. It places release votes immediately after the notes in the scrollable content. Its top-right `arrow.up.forward` button opens the full changelog. Continue stays pinned in a bottom safe-area inset as a full-width Liquid Glass prominent button on iOS 26+, with a bordered prominent fallback on iOS 17–25 or when built with an older Swift compiler. The footer blurs the content behind it using a gradient-masked system material, fading in above Continue and extending under the bottom safe area. The sheet has no ellipsis menu or separate All updates link at the bottom.

## Community

Release and comment votes can be switched or removed by tapping the selected direction again; list/detail state stays synchronized. Failed writes restore the prior selection/count. SDK config controls release `features.votes` and independent `features.commentVotes`.

Comments use stable friendly names scoped to the app's anonymous installation, with no sign-in. New accepted comments appear automatically. Guidelines acceptance is required before the first post. The server retains content rejection, rate limits, bans, reporting, blocking and developer moderation. Reply from the trailing button beside each visible comment’s votes. Use the comment’s ellipsis menu or long-press for report/block. Your own comments offer Delete comment with confirmation; their text is erased while replies remain under a deletion notice. Deleted comments without displayed replies disappear entirely; notices remain only to preserve a reply thread. Ownership follows the app-scoped installation identity. Reporting submits immediately without asking the user for a reason; developers must provide a justification when resolving reports. Two distinct anonymous installations reporting a comment automatically hide its text behind “This comment has been hidden because it violated the community guidelines.” Duplicate reports do not count again; developers can review reports in the dashboard. Comment lists paginate and show newest parent comments first; replies do not bump a thread, and siblings are newest-first. Replies retain their exact parent at every level, with one indentation and continuous vertical guide per ancestor. Up to three replies per parent are initially inlined; Load more replies expands further children and deeper threads. The composer shows the selected author and comment and preserves its target through guidelines acceptance. Automatic capitalization is disabled. Own legacy pending posts show Awaiting review. The composer preserves its draft after errors. The preview comment count updates from the server response.

## Offline behavior

A private disk cache stores validated read responses, partitioned by endpoint, app key, installation, locale, storefront and URL. Config is fresh for 24 hours; release reads can reuse a five-minute cache, while explicit changelog refresh forces ETag revalidation. Connection failures fall back to saved reads for up to seven days with an Offline label. Server authorization/removal errors do not fall back to stale data. Cache entries and disk entry count are bounded. Successful votes patch cached vote state; comment counts update from the server; blocking/reporting removes cached community reads.

Comments, votes, reports and blocks are never queued. Analytics events alone have a bounded queue of 50, retried after configuration loads (best effort, at-least-once). Host apps must describe the enabled data collection in their own privacy disclosures. The privacy manifest declares anonymous identifiers, product interactions and user content; no required-reason APIs are used by this SDK.

## App Attest — experimental

`Options.appAttest` defaults to `.disabled`. Stable integrations need no Apple Team ID or App Attest entitlement. Explicit `.automatic` opts into the experimental implementation, which has not passed the signed real-iPhone verification gate. Keep server-side Require App Attest off for default integrations; a server requiring proofs rejects writes from this default configuration. On supported real devices, the SDK registers a Secure Enclave key with Apple and the ReleaseKit server, then signs each write with a fresh server challenge. The server verifies the Apple certificate chain, nonce, app identity, public key, environment, signature, counter and single-use challenge. Keys are scoped to endpoint/app/installation and stored in Keychain; no private key is uploaded. Invalid keys can re-enroll once. Apple service availability failures preserve optional, unverified operation; an app requiring attestation rejects unverified writes. Reads always remain available.

In the ReleaseKit dashboard, enter the **Apple App ID prefix** (usually the 10-character Team ID) from Apple Developer → Certificates, Identifiers & Profiles → Identifiers → your app. This is different from the ASC Issuer ID. Configure the host app's `com.apple.developer.devicecheck.appattest-environment` entitlement with appropriate provisioning. Production/TestFlight use production proofs. Development proofs require an explicitly enabled test server; `RK_ATTEST_ALLOW_DEV` remains false on production. Keep Require App Attest off until a signed real-device integration test passes. Unsupported devices and Simulator remain unverified; if required, they can read but cannot write.

App Attest verifies app instances, not individual people. Fraud receipt/risk scoring is not implemented. One production web replica serializes counter updates; deterministic database claim rows provide cross-process challenge single use and key ownership binding. Multi-replica counter coordination must be designed before horizontal scaling.

## Server switches

- `RK_ENABLE_RELEASE_VOTES`: SDK release votes.
- `RK_ENABLE_COMMENT_VOTES`: SDK comment votes.
- `RK_ENABLE_SDK_COMMENTS`: comments/consent/reports/blocks, additionally respecting app settings.
- `RK_ENABLE_SDK_EVENTS`: anonymous SDK events.
- `RK_ENABLE_APP_ATTEST`: attestation enrollment; per-app prefix enables optional verification.
- `RK_ATTEST_ALLOW_DEV`: development proofs; leave false on production.

`RK_ENABLE_EXPERIMENTAL_WRITES` can remain false; none of these switches enables browser writes. `Options.comments.isEnabled=false` hides native commenting.

## Demo and validation

Open `Examples/ReleaseKitDemo/ReleaseKitDemo.xcodeproj`. Create ignored `Examples/ReleaseKitDemo/Local.xcconfig`:

```xcconfig
RK_DEMO_APP_KEY = rk_pub_REPLACE_ME
RK_DEMO_BASE_URL = https:/$()/releasek.it
```

The demo uses the local package and automatic What's New. Debug argument `--show-changelog` opens the changelog directly, suppressing the automatic sheet. `--test-offline` simulates connection failure without modifying device networking; first run online to populate the cache.

`swift test` covers state decisions, cache partition/expiry/invalidation, ETags, offline read/write behavior, queued events, models and shared request-signing fixtures. CI tests Linux and macOS and compiles the iOS library/demo. Server tests validate Apple's official reference attestation, tampering/expiry, real ECDSA assertions, nonce replay, ownership binding and required/optional behavior. Canonical API fixtures live in `contracts/sdk/` of the web repository; exact copies are included in SDK tests.
