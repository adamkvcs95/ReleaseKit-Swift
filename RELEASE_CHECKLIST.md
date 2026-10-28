# 1.0.0 release gate

Candidate: `1.0.0-rc.1`. Do not label it stable or publish `1.0.0` until all checks below are recorded.

- Automated Linux/macOS Swift tests and iOS library/demo builds pass on the tagged commit.
- Backend CI and readiness checks pass; independently gated comment votes, events and optional App Attest are deployed.
- Fresh install skips What's New; a real version update presents once; relaunch skips; downgrade skips. Verify UI, not only local state.
- Changelog and comments render cached content with Offline labels after relaunch; attempted writes fail without later submission; reconnect refreshes.
- Release/comment votes switch/remove and preserve state; bans/report/block/moderation still work.
- A signed real-iPhone host build, with its correct Apple App ID prefix and entitlement, successfully enrolls and submits verified writes. Confirm a Verified app comment, increasing counters and rejection of a replay; an unsupported Simulator remains readable and unverified. Confirm required mode only after optional mode succeeds.
- Required-reason API usage and privacy manifest reviewed against Apple's current documentation.
- Review README, API docs, CHANGELOG and exact shared fixtures; no private credentials or local configuration in Git.

## Outstanding external requirement

The host Mac currently has no valid code-signing identities. The owner has not supplied the app's Apple App ID prefix/Team ID or a signed real-device test build. Consequently real-iPhone App Attest verification cannot yet be reported as passed. After the owner unlocked the Mac, the simulator visibly showed automatic 4.0 What's New after upgrading from 3.9; relaunch did not repeat it. Offline changelog and comments rendered saved content with Offline labels; an attempted offline vote restored the prior selection and showed an error. Those simulator checks are complete. The real-device gate is not waived by successful Apple test vectors or simulator compilation.

## Local verification, 2026-10-28

- 88 backend/core tests pass, including the official Apple certificate vector at its documented valid date, real ECDSA assertion signatures, nonce reuse rejection and independent comment-vote gates.
- 23 Swift tests pass, including shared signing contracts, ETag 304, disk isolation/expiry, offline fallback, HTTP denial eviction, no queued user writes and the bounded event queue.
- iOS library/demo compile with Swift 6.
- Simulator: 3.9 first launch recorded without an update sheet; 4.0 presented automatically once; next launch skipped. Offline release history/comments and vote rollback verified through Device Hub.
- Required-reason API review: no UserDefaults, file timestamps, disk capacity or system boot-time APIs added.
