# 1.0.0 release gate

Release: `1.0.0`. The owner approved stable changelog/community/offline scope on 2026-10-29, with App Attest disabled by default and explicitly experimental. This replaces the earlier requirement to verify App Attest before releasing the other features.

## Stable scope and publication requirements

- Changelog and automatic What's New; Installed/Latest badges; release/comment votes; nested replies; pseudonyms; reporting/blocking/moderation; own-comment deletion; private offline read cache and best-effort events.
- Publish the stable tag only after Linux/macOS Swift tests, iOS integration tests and iOS library/demo builds pass on its exact commit.
- Backend CI/readiness and independent native write gates must remain healthy. Default clients do not attempt App Attest enrollment; do not require attestation on apps using the default configuration.
- Keep the installation guide, README, API docs, CHANGELOG and canonical fixtures consistent. No private credentials, local configuration or generated build products in Git.

## Recorded verification

- 2026-10-29: 30 macOS Swift tests pass. The iOS simulator runs 32 tests, including public Options default `.disabled`, explicit experimental `.automatic`, unconfigured views, and the core contracts.
- 2026-10-29: 121 backend/core/web tests pass, plus lint and typecheck. Ownership, signed DELETE/body binding/replay, report thresholds, deletion pruning, nested visibility, votes, caches and error handling are covered.
- 2026-10-28: simulator first install 3.9 skipped the update sheet; upgrade to 4.0 presented once and relaunch skipped. Offline changelog/comments showed saved content and Offline labels; an attempted offline vote restored its prior selection and showed an error. Offline writes are not queued; cache eviction/revalidation and reconnect behavior are covered by core transport tests.
- 2026-10-29: the stable SDK demo was downgraded from 4.0 to 3.8; the visible UI remained on Demo without an automatic update sheet. The decider tests independently cover downgrade and presentation state.
- The owner reported successful changelog integration in Today App on a physical iPhone. This is ordinary SDK usage evidence, not App Attest verification.
- Threading, mixed-case composing and selection of exact reply targets were visually verified in the simulator. A synthetic local deletion UI test verified confirmation, notice, preserved reply and count update. Production HTTPS tests verified owner-only deletion and readiness; a read-only check verified omission of deleted leaves.
- PrivacyInfo.xcprivacy is a valid plist and is explicitly bundled as a Swift-package resource. Source review found no UserDefaults, boot-time, file timestamp, disk-capacity, advertising-ID or vendor-ID APIs. The manifest declares user content, interactions and the pseudonymous installation ID, with no tracking. Host apps still review their own disclosures and combined privacy report.
- Privacy packaging review used Apple's [manifest guide](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk) and [privacy manifest reference](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

## Separate experimental App Attest gate — not passed

App Attest is excluded from the stable guarantee and defaults to `.disabled`. `.automatic` is an explicit experimental opt-in. Apple sample vectors, ECDSA/replay tests and simulator builds do not establish real-device verification.

Before claiming stable App Attest or enabling required mode: use a correctly provisioned, signed real-iPhone host with the app's Apple App ID prefix and entitlement; verify enrollment, a Verified app comment, increasing counters, replay rejection and unsupported-device fallback. Test optional mode before required mode. Production development-proof acceptance remains disabled. Horizontal scaling also requires coordinated assertion-counter updates.
