# Rocha+ entitlement API (experimental)

Deploy only to the verified Firebase project with billing configured and reviewed.

1. In the functions folder, install locked dependencies and validate syntax.
2. Deploy `entitlement` in region `southamerica-east1`.
3. Build an **experimental-only** APK with `ROCHA_EXPERIMENTAL_SUBSCRIPTIONS=true` and `ROCHA_ENTITLEMENT_URL=https://<verified-cloud-function-url>`.
4. Test new, expired, and paid Firebase users. Keep commercial release disabled until reconciliation is implemented and tested.

The endpoint verifies Firebase ID tokens, including revocation, derives UID from the verified token, creates the first seven-day trial once per UID in a Firestore transaction, and requires a server-owned `paidUntil` timestamp to grant paid access. It never treats an emailed receipt, payment link, transaction ID, or client-controlled field as payment confirmation.

**Pending:** create and test an authorized server-side Mercado Pago reconciliation process. Verify transactions using Mercado Pago's authenticated API, establish their actual payment and refund states, map each to the correct Firebase UID after documented account-holder confirmation, apply paid periods exactly once per transaction, and handle reversals. Do not set `paidUntil` manually based only on an ID.

Security: ensure Firestore client access to `entitlements` is denied before deployment. The Admin SDK bypasses Firestore client rules. Keep the Mercado Pago token in Secret Manager, never inside this app.
