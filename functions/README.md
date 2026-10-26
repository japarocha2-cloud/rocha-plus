# Rocha+ entitlement API (experimental)

Deploy only to the verified Firebase project with billing configured and reviewed.

1. In the functions folder, install locked dependencies and validate syntax.
2. Deploy `entitlement` in region `southamerica-east1`.
3. Build an **experimental-only** APK with `ROCHA_EXPERIMENTAL_SUBSCRIPTIONS=true` and `ROCHA_ENTITLEMENT_URL=https://<verified-cloud-function-url>`.
4. Test new, expired, and paid Firebase users. Keep commercial release disabled until reconciliation is implemented and tested.

The endpoint verifies Firebase ID tokens, including revocation, derives UID from the verified token, creates the first seven-day trial once per UID in a Firestore transaction, and requires a server-owned `paidUntil` timestamp to grant paid access. It never treats an emailed receipt, payment link, transaction ID, or client-controlled field as payment confirmation.

**Pending:** create and test an authorized server-side Mercado Pago reconciliation process. Verify transactions using Mercado Pago's authenticated API, establish their actual payment and refund states, map each to the correct Firebase UID after documented account-holder confirmation, apply paid periods exactly once per transaction, and handle reversals. Do not set `paidUntil` manually based only on an ID.

Security: ensure Firestore client access to `entitlements` is denied before deployment. The Admin SDK bypasses Firestore client rules. Keep the Mercado Pago token in Secret Manager, never inside this app.

## Firestore rules deployment warning

The new root `firestore.rules` is a **deny-by-default experimental policy** and is NOT ready to replace an existing project's complete ruleset. Before any deployment, inspect the live Firestore rules and merge the relevant `entitlements`, `payment_events`, and `payment_claims` restrictions with existing rules. Replacing an existing ruleset without review can break other application collections. Do not deploy this file blindly.

The Mercado Pago inspection module is a read-only scaffold, not an activated webhook, scheduled reconciliation job or completed payment association. Do not report payment tests as passed until provider API access and a real end-to-end transaction test are confirmed.

## Payment verification ledger added

`recordVerifiedPayment({db, paymentId, accessToken})` looks up the payment **again** via the official provider API, requires a previously admin-reviewed mapping in `payment_claims/{paymentId}` to one UID, and atomically records its latest status in `payment_events/{paymentId}`. Repeated checks update the same event rather than creating duplicates. It **never** writes `entitlements/{uid}.paidUntil`. A back-office association process and an audited paid-period computation including multiple plans and reversals are still needed; the real monthly and annual purchases must not be auto-linked based solely on the known transaction IDs.

## Deterministic periods (not yet connected to production grants)

`entitlement_periods.js` computes the maximum approved period end from server-owned ledger entries after an **independently reviewed plan and UID association**. A month means a calendar month, and an annual plan means 12 calendar months. Concurrent purchases do not stack automatically; the latest valid end wins. The same payment ID cannot appear twice, and status changes such as refunds remove that payment on recalculation. This logic is deliberately not wired to `paidUntil` until trusted claim review, verified plan/amount mapping, account ownership and reconciliation of existing transactions are operationally validated. Tests are included but have not yet been run in CI.

## Privileged reconciliation grant (experimental)

`reconcile_and_grant.js` now combines provider verification, an independently reviewed `payment_claims/{paymentId}` record (UID, plan, BRL amount in cents), one Firestore transaction, unique `payment_events/{paymentId}` ledger entry and recomputation of `entitlements/{uid}.paidUntil`. Repeating the same approved payment will not extend its period again. A verified refund recomputes the account from remaining ledger records. Run only from a trusted backend/admin process with a protected Mercado Pago access token; **do not expose this function directly to client calls**.

**Critical deployment blockers:** an audited back-office workflow must establish each historical payment claim after account ownership verification; refund/chargeback state must be refreshed promptly for all relevant payments; verify account plan terms and amount before marking a claim reviewed. The code is not deployed, provider credentials are not configured, and live payment transactions have not been reconciled. Maintain PR as draft.
