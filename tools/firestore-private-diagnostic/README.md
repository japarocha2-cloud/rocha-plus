# Firestore private diagnostic authentication

This package is deliberately isolated from the deployed application. It prepares
and invokes a private Cloud Run function without service-account keys and without
changing IAM, deploying code, or writing to Firestore.

The diagnostic performs exactly two non-financial document reads at the fixed path
`_diagnostics/firestore-read-isolation`:

- an explicit `getFirestore(app, 'rocha-payments-test')` read must be accessible;
- an explicit `getFirestore(app)` read against `(default)` must return
  `permission_denied`.

The result is `isolation_proven` only when both conditions hold. A missing database,
configuration error, network failure, unknown error, or readable `(default)` database
returns `isolation_not_proven`; absence of a sentinel document is not an error because
the read itself is the permission probe. No collection enumeration or write occurs.

The invocation contract is:

1. Use the exact HTTPS audience accepted by the private function. For a Cloud Run
   function, use the function URL reported by Google Cloud verbatim except for a
   trailing slash. Do not append any path that Google Cloud did not report.
2. Mint a short-lived Google ID token by impersonating an existing, dedicated
   caller service account.
3. Verify the RS256 signature against Google JWKS and require exact `iss`, `aud`,
   `sub`, time, and authorized identity claims before sending the request.
4. Send exactly one `Authorization: Bearer` header and never follow redirects.

The operator needs only these scoped permissions during a future authorized test:

- `roles/iam.serviceAccountOpenIdTokenCreator` on the chosen caller service account;
- `roles/run.invoker` on the one diagnostic Cloud Run service for that caller.

No JSON key is used. The runtime service account should not be selected merely
because it exists; use a dedicated caller identity or an identity explicitly
approved for invocation.

Prepare a non-secret configuration:

```sh
python3 prepare-window-local.py \
  --url https://EXACT-ACCEPTED-URL \
  --audience https://EXACT-ACCEPTED-URL \
  --caller-service-account CALLER@PROJECT.iam.gserviceaccount.com \
  --allowed-email CALLER@PROJECT.iam.gserviceaccount.com \
  --output invocation.json
```

After an authorized deployment and IAM window, invoke with:

```sh
python3 invoke-private-diagnostic.py --config invocation.json
```

Neither command prints the token. `invoke-private-diagnostic.py` requires the
cryptographic verifier to pass before it opens a connection.

## Correlation and safe observability

The response includes `X-Diagnostic-Correlation-ID` and the same opaque value in its
JSON body. A valid `X-Cloud-Trace-Context` trace ID is used when present; otherwise a
random UUID is generated. Structured logs include the Cloud Logging
`logging.googleapis.com/trace` field when possible, verdict and sanitized outcome
categories only. They never include JWTs, Authorization, subject, email, provider
error messages, document data, or financial identifiers.

Expected application statuses are:

- `200 isolation_proven`: named database readable and `(default)` denied;
- `409 isolation_not_proven`: the two-sided proof did not match exactly;
- `401 unauthenticated`: application token validation failed;
- `503 diagnostic_unavailable`: the handler itself failed unexpectedly.

A platform 401/403 can occur before the application and therefore has no application
correlation response. Correlate it using the Cloud Run request log timestamp/trace.

## Isolated deployment preparation — documentation only

`firebase.json` contains one codebase, `firestore-private-diagnostic`, sourced only
from this directory. The root application `functions/index.js` does not import it.
Dependencies are pinned in `package-lock.json`, runtime is Node.js 22, the endpoint is
private, `maxInstances` is 1, and the runtime service account is a required Firebase
parameter.

For a future separately authorized window:

1. Copy `deployment.example.json` to the ignored `deployment.review.json` and fill
   the exact Google-reported audience plus distinct approved caller/runtime service
   accounts.
2. Set the two review flags to `true` only after Work confirms that the runtime can
   read the named database, cannot read `(default)`, public access is disabled, and
   the caller alone has invocation permission on this temporary service.
3. Copy `.env.example` to the ignored `.env.rocha-plus-homologacao` and use exactly
   the reviewed values. Never commit it.
4. Validate both files together with
   `node validate-deploy-config.cjs deployment.review.json .env.rocha-plus-homologacao`.
5. Run `npm ci`, `npm test`, and `npm run check` with Node.js 22.

Only after separate deploy authorization, the reviewed isolated command is:

```sh
firebase deploy \
  --config firebase.json \
  --project rocha-plus-homologacao \
  --only functions:firestore-private-diagnostic
```

This command was not executed during issue #46. The JSON validator is a fail-closed
review gate, cross-checks the ignored runtime environment file, and runs automatically
as a predeploy step using Firebase's isolated `$RESOURCE_DIR`. It is not a substitute
for remote IAM evidence.

Run the local contract tests with Node.js 22:

```sh
npm test
```
