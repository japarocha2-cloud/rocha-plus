# Rocha+ | Cross-platform parity contract

## Canonical reference
APK 538 at `freeze/apk-538-20261014` is the approved reference for appearance, user-facing functions and behaviors. Do not edit or overwrite the freeze. Adapt technical implementation for each device input, form factor and platform policy while keeping feature parity.

## Platforms
Android phone APK; Android TV / Google TV; Chromecast / Cast receiver; Roku; other explicitly supported TV builds.

## Common requirements
- One subscriber identity and single backend entitlement across all devices. Logging into a second compatible device does not grant another trial.
- 7-day one-time trial starts at an immutable Firestore server timestamp for the account. Closing/reopening, clearing data, reinstalling or switching platforms must not reset it.
- At expiry, stop protected playback and casting, display the approved subscription screen or platform-equivalent layout and refuse further playback without valid server-confirmed entitlement.
- Checkout or clicking 'Já paguei' never grants access. Verify payment and subscription on a trusted server and then update Firestore access. Handle renewal, pending, cancellation, refunds and expired access.
- Same approved plans and founder price terms: monthly BRL 4.90, annual BRL 55.00. Do not assume payment provider's off-platform checkout is permitted on every TV store: check each store's payment policy before shipping.
- Preserve from APK 538: intro, channels, approved catalog and removal of bad links, video/audio playback, channel covers, favorites, 7-day welcome notice, subscription screen design and navigation intents. Input adaptations: remote focus and D-pad on TVs, touch on phones.
- Same backend status semantics and short-lived server access leases; fail closed if entitlement cannot be established. Revalidate on launch/resume and periodically during playback. A Cast receiver must enforce rights itself or use short-lived authorized stream access; controlling only the mobile screen is insufficient.

## Validation matrix
For EACH platform: login/logout, 7-day first use, persistence after app/device restart, channel playback with audio, favorites, covers, expired playback interruption, subscription screen, unpaid denial, paid grant, renewal, cancellation/refund, offline behavior and cross-device syncing. Record physical hardware results, not just unit tests.

## Progress discipline
This document is a requirement specification, not proof that Roku/TV/Cast implementations are complete. APK 538 remains frozen; implement on development branches and only propagate after tests pass.
