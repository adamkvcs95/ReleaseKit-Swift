# ReleaseKit iOS integration

Use the current README as the implementation guide. This package is a development preview, not a stable 1.0.0 release. Do not invent a release tag or promise that offline cache or App Attest are implemented.

- Minimum deployment target: iOS 17. Swift 6. If the host app targets an earlier iOS version, report the incompatibility before integrating.
- Package URL: `https://github.com/adamkvcs95/ReleaseKit-Swift`, branch `main`, product `ReleaseKit`.
- Configure once at app startup with `ReleaseKit.configure(appKey:)`. The key is the public `rk_pub_…` value from the ReleaseKit dashboard → app → SDK installation. Never use an Apple .p8 key or an Appwrite secret.
- If the app key is unavailable, use `rk_pub_REPLACE_ME` and clearly mark the integration as awaiting configuration. Never fabricate an active key.
- For a sheet, add `.releaseKitChangelog(isPresented: $showUpdates)` to the presenting view and set the binding from a button. The modifier supplies the NavigationStack and Done action.
- Inside an existing NavigationStack, use `ReleaseKitSettingsLink()` or `ReleaseKitChangelogView()`.
- The changelog list uses three-line previews with independent votes. Tapping a release opens complete notes and comments. Both voting and comments availability come from server config; comments additionally respect Options.comments.isEnabled. New comments require guidelines consent and await developer review. Keep unrelated experimental writes disabled. Installed/Latest badges use the host bundle version and config latestVersion; never fake the host version.
- Verify loading, empty, error, refresh, pagination, vote/remove/switch and reopening the view. Do not report success based only on a successful package import.
- Do not enable `.releaseKitWhatsNew()` automatically when integrating this changelog-only flow. It is a separate earlier preview feature.
- Never commit local configuration, credentials or real user data. The demo's Local.xcconfig is ignored.

Commands: `swift test`; `xcodebuild -scheme ReleaseKit -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
