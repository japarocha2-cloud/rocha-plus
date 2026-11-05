# P0 private Firestore diagnostic: Cloud Run HTTP 401

## Classification

**AMARELO** — the authentication correction is locally validated. A remote request
through the Google-managed Cloud Run authentication layer remains intentionally
pending because the temporary function was deleted and recreation/IAM changes were
not authorized.

Issue #46 preserves this **AMARELO** classification: the two-sided Firestore
isolation contract, trace correlation and isolated deployment manifest are locally
validated, but no Google-managed authentication or database-IAM behavior has been
tested remotely.

## Conclusions and evidence

1. The observed 401 was emitted before the diagnostic handler. The handler did not
   run and changing `roles/run.invoker` did not change the response. This locates
   the failure in Google-managed request authentication, not in the Firestore read.
2. A valid Google signature proves who signed the JWT; it does not prove that the
   token was minted for this receiver. The recorded `oauth-client-aud` profile and
   `audience_matches_service_url: false` prove that the tested token was not bound to
   the service URL.
3. Audience mismatch alone is not enough to identify the prior token as invalid:
   Google documents a generic `gcloud auth print-identity-token` development token
   accepted by Cloud Run despite lacking a receiver-specific audience. The missing
   helpers and absence of the sanitized JWT header/claims prevent proving whether
   the prior token was that special generic token or an ordinary OAuth-client ID
   token. Therefore the exact historical token subtype remains unproven.
4. The definitive correction removes that ambiguity: mint a Google-signed service
   account ID token with the exact accepted URL as `aud`, verify it locally, and send
   one Bearer header without redirects. This satisfies the normal production Cloud
   Run contract and does not rely on the development-token exception.
5. `iss`, `aud`, `sub`, `exp`, `iat`, optional `nbf`, optional `azp`, email identity,
   RS256 algorithm, `kid`, and signature are fail-closed. `azp` is checked for shape
   and can be allowlisted when the approved issuer supplies it; it is not required
   because service-account ID tokens need not contain it.
6. Issue #46 replaces the ambiguous default Firestore client with
   `getFirestore(app, 'rocha-payments-test')` and separately constructs
   `getFirestore(app)` solely for the negative `(default)` sentinel probe.
7. Isolation is proven only by the conjunction `named accessible AND default
   permission_denied`. Database absence, configuration, network and unknown failures
   are categorized separately and remain `not_proven`.
8. Application responses and structured logs share a validated Cloud trace ID or an
   opaque UUID. Logs contain no JWT, Authorization, subject, email, provider message,
   document contents or financial identifier.

## Issue #46 local evidence

- Node.js 22.23.4 contract suite: **33 passed, 0 failed**. It covers authentication, explicit database isolation,
  denied/default-access counterexamples, error classification, log redaction,
  correlation and deployment validation.
- `firebase.json` has one isolated codebase and `package-lock.json` pins its runtime
  dependencies. The generated endpoint contract remains GCF v2, private,
  `southamerica-east1`, `maxInstances: 1`, with a required runtime service account
  parameter.
- `deployment.example.json` intentionally fails until the exact audience, distinct
  identities and both IAM review assertions are supplied in an ignored review file.
- Runtime dependencies are pinned to `firebase-admin` 14.5.0 and
  `firebase-functions` 7.4.0. Safe transitive overrides are locked for
  `rimraf`/`glob`/`minimatch`; `npm audit --omit=dev` reports **0 vulnerabilities**.
- JavaScript syntax checks, Python bytecode compilation and `git diff --check` pass.
- No deploy, IAM inspection/change, Firestore request, function recreation or
  application modification was performed.

## Issue #46 Git evidence

- Review branch: `fix/cloud-run-private-diagnostic-auth`.
- Authentication baseline: `f085084231c894138b20c2447876e5fe0c99559c`.
- Named-database isolation implementation:
  `7657c5b26a1ea7fdbea104ba2e90d595ac948869`.
- Scope remains limited to `tools/firestore-private-diagnostic/` and this incident
  report. The implementation commit contains no change to the main Functions entry
  point, entitlement, webhook, applications, catalog, subscriptions or prices.

Official contracts used for this conclusion:

- [Cloud Run service-to-service authentication](https://cloud.google.com/run/docs/authenticating/service-to-service)
  requires a Google-signed ID token whose audience is the receiving service URL or
  a configured custom audience, sent in one supported Bearer header.
- [Cloud Run developer authentication](https://cloud.google.com/run/docs/authenticating/developers)
  documents the exceptional generic gcloud user token for development and warns
  that it is not audience-bound.
- [Cloud Run functions troubleshooting](https://cloud.google.com/functions/docs/troubleshooting#function_invocation_lacks_valid_authentication_credentials)
  distinguishes a 401 caused by invalid credentials/audience from a 403 caused by
  missing invocation permission.
- [Google ID-token generation](https://cloud.google.com/docs/authentication/get-id-token#impersonating_a_service_account)
  documents short-lived service-account impersonation without downloaded keys.

## Missing prior artifacts

`owner_auth.py`, `verify-owner-token.cjs`, `prepare-window-local.py`,
`invoke-private-diagnostic.py`, and `functions-firestore-diagnostic/*` were not in
any Git branch, commit, or current GitHub Actions artifact. They were executor-local
artifacts. The replacement package is now versioned under
`tools/firestore-private-diagnostic/`.

## Remote validation request for ChatGPT Work

Do not deploy or change IAM until separately authorized. In the authorized window:

1. Record the exact function URL reported by `serviceConfig.uri`, the backing Cloud
   Run service URL, ingress setting, and configured custom audiences. Do not record a
   token.
2. Confirm one existing approved caller service account and report only whether the
   operator has `iam.serviceAccounts.getOpenIdToken` on that account and whether that
   account has `run.routes.invoke` on this one service.
3. Confirm that the separately approved runtime service account has database-scoped
   read permission on `rocha-payments-test` and no corresponding permission on
   `(default)`. A project-wide Firestore role cannot prove this isolation.
4. Populate the ignored deployment review/environment files, run the fail-closed
   validator, and retain only its sanitized output.
5. Recreate the reviewed temporary function only if authorized. Use the exact accepted
   URL for both request and `aud`; make one invocation with the versioned helper.
6. Return the HTTP status, response body, Cloud Run request log timestamp/trace,
   `status`, `authenticationInfo.principalEmail` if present, and whether an application
   log with the same trace exists. Redact JWTs and Authorization headers.
7. Remove the scoped temporary bindings and delete the temporary function after the
   test; confirm both removals.

Expected proof: 200 plus a matching application trace. A 401 with no application log
still indicates Google-managed token rejection; a 403 indicates authenticated but
unauthorized; an application-generated 401 includes the JSON code `unauthenticated`.

## Rollback

The patch is isolated and not imported by `functions/index.js`. Rollback is deletion
or revert of `tools/firestore-private-diagnostic/` and this report. No cloud rollback
is necessary because this investigation performs no deploy, IAM, database, secret,
payment, price, subscription, catalog, Android, Roku, or LAB change.
