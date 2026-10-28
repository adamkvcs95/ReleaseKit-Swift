# Changelog

## 1.0.0-rc.10

- Delete your own comments from the ellipsis menu with confirmation. Preserve replies and show a neutral deletion notice, invalidate cached discussions and update counts.

- Show comment threads newest-first by their parent comment date; keep nested replies under their parent and sibling replies newest-first.

- Connect native comment thread guides across adjacent reply rows and Load more replies rows. Keep content padding inside the full-height guides and inset each horizontal separator by the deeper of its two adjacent rows, including the boundary above the first reply.

## 1.0.0-rc.9

- Bind the comment composer sheet to an immutable composition request so the selected reply target is preserved on first presentation and after guidelines acceptance.
- Preserve the exact reply parent at every level. Render nested replies with one indentation and vertical guide per ancestor; Load more replies pages through longer and deeper threads. Show the selected author and excerpt in the composer; new top-level comments get a fresh target-free composer.
- Disable automatic capitalization and clear inherited text case on the comment editor.

## 1.0.0-rc.8

- Keep comment list separators aligned across the row instead of inheriting Reply button alignment.
- Mark indented replies with a subtle vertical thread line.

## 1.0.0-rc.7

- Move Reply beside each comment’s votes, aligned to the trailing edge, including replies and own comments.
- Add an icon to Block user and omit empty action menus on own comments.

## 1.0.0-rc.6

- Submit a report directly from the comment menu without asking the user to choose a reason. Developer moderation still requires a written justification.

## 1.0.0-rc.5

- Report comments from their ellipsis menu or long-press actions, with reason selection and confirmation.
- Two distinct installation reports automatically hide a comment. Hidden content is replaced with an English community-guidelines notice, without voting or reply actions.
- Apply the authoritative comment count after reporting and invalidate cached discussions.

## 1.0.0-rc.4

- Use adaptive neutral colors for navigation and toolbar actions, including Done, back, overflow, compose, Cancel and Post.
- Preserve indigo content/vote accents and the green Installed badge.

## 1.0.0-rc.3

- Restore green styling for the Installed badge; Latest and other SDK accents remain indigo.

## 1.0.0-rc.2

- Reference-inspired outlined vote capsule using arrowtriangle.up/down, a shared net score and a vertical divider.
- Selected vote triangles use filled SF Symbols; SDK controls and badges consistently use indigo.
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
