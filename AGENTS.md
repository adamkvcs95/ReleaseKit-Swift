# ReleaseKit integration

Use README.md and RELEASE_CHECKLIST.md. Current version is a release candidate; never claim stable 1.0.0 or real-device App Attest verification until the release gate is recorded as passed.

- iOS 17+, Swift 6, system frameworks only. Report an incompatible deployment target before integrating.
- Repository: https://github.com/adamkvcs95/ReleaseKit-Swift; product ReleaseKit. Use current tagged candidate or main for testing.
- Configure once with the real public rk_pub_ app key. Never invent credentials or use Apple/Appwrite secrets; use rk_pub_REPLACE_ME when configuration is pending.
- Add .releaseKitWhatsNew() once per scene for automatic update notes; use .releaseKitChangelog(isPresented:) for an explicit sheet, or the SettingsLink/ChangelogView inside a NavigationStack.
- App Attest is automatic when supported/configured. It does not prove a unique person. Never enable required mode before a signed real-iPhone test. Simulator remains unverified. Do not turn on development proofs in production.
- Keep native comments/votes/events gates independent of browser/experimental writes. Respect Options.comments and server config. New accepted comments publish automatically; bans and reporting still apply.
- Offline reads use private scoped caches; never queue user posts or votes. Verify privacy invalidation and error rollback.
- Do not commit Local.xcconfig, credentials, real device keys, application data or generated build products.
- Changes to server contracts require canonical web fixtures and exact SDK test copies.

Commands: swift test; xcodebuild -scheme ReleaseKit -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build.
