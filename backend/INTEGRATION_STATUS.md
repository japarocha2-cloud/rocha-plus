# Rocha+ | Integration handoff (2026-10-14)

## State
- Existing Android trial: `SparkBillingRepository` creates `rochaSparkAccounts/{googleProviderUid}` on first valid use with Firestore REQUEST_TIME, computes seven days with Firestore readTime.
- `BillingController` enforces a short-lived local lease and refreshes on resume; physical two-minute *laboratory* expiration is not proof of durable entitlement.
- `paidUntil` is read but no verified payment writer is deployed from this branch.
- Two existing Mercado Pago recurring plans: monthly BRL 4.90, annual BRL 55.00. Their currently embedded mpago.la URLs are static and do not pass a per-user external_reference.
- Mercado Pago Developers application creation blocked by DXP07; support case 488583188. No production API credentials or webhook endpoint verified.
- APK 538 freeze must remain unchanged.

## Before enabling payment unlock
1. Confirm with Mercado Pago Developers whether these panel-created plans have API preapproval_plan IDs, and whether existing checkout links can carry user-specific references. Do not assume the same existing link binds a Google account.
2. Create a **server-generated**, unguessable checkout correlation record for the authenticated Firebase UID / stable Google provider identifier, mapped to an exact plan ID and external_reference. Use an opaque random reference, not personally identifiable data. The payment verifier requires a server-resolved `referenceAccountId` in addition to the exact reference; this value must come from trusted storage, never the Android client.
3. Build HTTPS server endpoint for checkout, authenticate Firebase ID token and issue a subscription checkout for the selected existing plan using a *server-side secret only*. Never ship an access token in Flutter/APK/GitHub.
4. Build webhook with signature validation where supported. Treat event data as hints only: fetch subscription and payment from Mercado Pago authenticated API, validate seller, plan, identity mapping, amount/currency, dates, status, and charge identity.
5. Apply **idempotent**, transactional updates to Firestore in trusted backend. Persist event/payment IDs, subscription ID and paid-through date; never extend access twice for duplicate event. Use server-only privileges. Reconcile cancellations/refunds, failed renewals, out-of-order notifications.
6. Make status() derive rights solely from immutable trialStartedAt and verified, non-revoked paid entitlement. When status is unknown, fail closed. Test expiration across app restart, data clear, reinstall, offline, and cross-device.
7. Maintain old prices/layout/cast/favorites/covers. Test on Android, including stopping playback and active casts at entitlement expiry.

## Important technical note
`backend/mercadopago_payment_verifier.js` is currently only a payment response predicate with test fixtures. It is NOT a webhook, server, payment integration, nor enough to unlock access. The checks use an externally authenticated payment response supplied by future server code. It must be extended to support recurring subscription lifecycle and precise entitlement periods.

## Security gate
Never allow the Android client to write `paidUntil`, payment status or subscription metadata to Firestore. Confirm deployed rules deny such mutations and restrict individual reads to account owner or authenticated authorized admin. Commit to GitHub is not deploy.
