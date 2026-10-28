# Rocha+ entitlement API (experimental)

Deploy only to the verified Firebase project with billing configured and reviewed.

1. In the functions folder, install locked dependencies and validate syntax.
2. Deploy `entitlement` in region `southamerica-east1`.
3. Build an **experimental-only** APK with `ROCHA_EXPERIMENTAL_SUBSCRIPTIONS=true` and `ROCHA_ENTITLEMENT_URL=https://<verified-cloud-function-url>`.
4. Test new, expired, and paid Firebase users. Keep commercial release disabled until reconciliation is implemented and tested.

The endpoint verifies Firebase ID tokens, including revocation, derives UID from the verified token, creates the first seven-day trial once per UID in a Firestore transaction, and requires a server-owned `paidUntil` timestamp to grant paid access. It never treats an emailed receipt, payment link, transaction ID, or client-controlled field as payment confirmation.

**Current state:** the privileged, non-deployed `reconcileAndGrant` module and
automated tests now cover reviewed UID/plan/amount/merchant matching, deterministic
monthly/annual periods, duplicate processing, refunds and ledger integrity.
These are code-level checks, not evidence of a completed sandbox purchase,
an operational back-office association workflow, or production deployment.


Security: ensure Firestore client access to `entitlements` is denied before deployment. The Admin SDK bypasses Firestore client rules. Keep the Mercado Pago token in Secret Manager, never inside this app.

## Firestore rules deployment warning

The new root `firestore.rules` is a **deny-by-default experimental policy** and is NOT ready to replace an existing project's complete ruleset. Before any deployment, inspect the live Firestore rules and merge the relevant `entitlements`, `payment_events`, and `payment_claims` restrictions with existing rules. Replacing an existing ruleset without review can break other application collections. Do not deploy this file blindly.

The Mercado Pago inspection module is a read-only scaffold, not an activated webhook, scheduled reconciliation job or completed payment association. Do not report payment tests as passed until provider API access and a real end-to-end transaction test are confirmed.

## Payment verification ledger added

`recordVerifiedPayment({db, paymentId, accessToken})` looks up the payment **again** via the official provider API, requires a previously admin-reviewed mapping in `payment_claims/{paymentId}` to one UID, and atomically records its latest status in `payment_events/{paymentId}`. Repeated checks update an unreviewed event; an already privileged-reviewed event is preserved unchanged by this snapshot-only operation. Refunds on reviewed events require the privileged reconciliation path to update both ledger and entitlement. It **never** writes `entitlements/{uid}.paidUntil`. An operational, audited back-office association process and end-to-end sandbox validation are still needed; the real monthly and annual purchases must not be auto-linked based solely on the known transaction IDs.

## Deterministic periods (connected only to the experimental privileged grant)

`entitlement_periods.js` computes the maximum approved period end from server-owned ledger entries after an **independently reviewed plan and UID association**. A month means a calendar month, and an annual plan means 12 calendar months. Concurrent purchases do not stack automatically; the latest valid end wins. The same payment ID cannot appear twice, and status changes such as refunds remove that payment on recalculation. This logic is wired to `paidUntil` only through the privileged `reconcileAndGrant` operation, which requires an independently reviewed claim. CI exercises the code with fixtures; no live payment reconciliation or sandbox-to-app flow has been certified.

## Privileged reconciliation grant (experimental)

`reconcile_and_grant.js` now combines provider verification, an independently reviewed `payment_claims/{paymentId}` record (UID, plan, BRL amount in cents), one Firestore transaction, unique `payment_events/{paymentId}` ledger entry and recomputation of `entitlements/{uid}.paidUntil`. Repeating the same approved payment will not extend its period again. A verified refund recomputes the account from remaining ledger records. Run only from a trusted backend/admin process with a protected Mercado Pago access token; **do not expose this function directly to client calls**.

**Critical deployment blockers:** an audited back-office workflow must establish each historical payment claim after account ownership verification; refund/chargeback state must be refreshed promptly for all relevant payments; verify account plan terms and amount before marking a claim reviewed. The code is not deployed, provider credentials are not configured, and live payment transactions have not been reconciled. Maintain PR as draft.

## Outstanding homologation evidence gates (do not mark green without evidence)

- **Firestore concurrency:** the isolated Standard Emulator suite in
  [emulator/README.md](emulator/README.md) now verifies competing first trial reads,
  same/different payment IDs, refund replay, ledger counts and exact `paidUntil`.
  [CI 40686132051](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40686132051)
  passed all 6 tests with 10 SDK transaction operations, 19 attempts and 9 retries.
  This is emulator evidence, not cloud load, client rules, IAM or provider E2E evidence.
- **Reviewed claim / UID ownership:** use an authenticated back-office procedure,
  independently verify account ownership, merchant and plan, and retain audit evidence
  without recording sensitive user identifiers in public CI logs. Never create claims
  from a webhook payload or untrusted client input.
- **Mercado Pago sandbox end-to-end:** with isolated test credentials and accounts,
  verify provider lookup, claim review, privileged reconciliation, entitlement read
  and application unlock/expiry; test duplicate notification and refund paths.
  The current reconciler and eligibility predicate require `liveMode === true`;
  [the isolated sandbox path](sandbox/README.md) now accepts explicit test-mode
  responses and writes only to its demo emulator and separate collections.
  Its fixture/transaction CI is green; a new provider E2E cycle remains pending.
  Do not bypass the production guard or substitute a real purchase.
  Never run a real charge or reuse historical production payments.
- **Trial and account switching:** in a dedicated experimental Firebase environment,
  verify first activation, expiry, renewal, logout/login, and no cross-account access.
  Preserve the existing expired-trial fixture.
- **Physical playback:** separately verify Android TV remote navigation and extended
  HLS/ExoPlayer/LibVLC playback; test Chromecast reconnect, media confirmation and
  recovery after network loss. Record device/build, stream type, elapsed time and
  observable outcome. A green Flutter CI is not a substitute.
- **Release gate:** keep PR #42 draft. No merge, deploy, APK publication or change
  to official version/approved assets until the above have independent evidence.
