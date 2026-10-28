# Changelog

## 1.0.0-rc.2

- Reference-inspired outlined vote capsule using arrowtriangle.up/down, a shared net score and a vertical divider.
- Adjacent outlined comment-count capsule in changelog previews.
- Consistent voting appearance in previews, release details, automatic What's New and comments; 44-point tap targets and selected-state accessibility preserved.

## 1.0.0-rc.1

- Native changelog previews, release details, Installed/Latest badges and shared voting state.
- Comments, replies, random app-scoped names, reporting, blocking and comment voting.
- Automatic What's New presentation with first-install/update/downgrade handling and per-app state.
- Private disk cache, ETag revalidation and explicit offline views; writes are never queued.
- Bounded offline event queue (50 events), flushed after configuration loads.
- DeviceCheck App Attest enrollment, Secure Enclave assertions, one-time server challenges and replay protection.
- English/Hungarian strings, native themes, Dynamic Type and accessible controls.

Release gate: a signed real-iPhone App Attest test with the host app's Apple App ID prefix is required before promoting this candidate to stable 1.0.0. Simulator fallback, Apple reference vector validation and automated signed-request tests do not replace that device test.
