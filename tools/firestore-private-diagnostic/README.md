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

The invoking operator needs only these scoped permissions during a future authorized test:

- `roles/iam.serviceAccountOpenIdTokenCreator` on the chosen caller service account;
- `roles/run.invoker` on the one diagnostic Cloud Run service for that caller.

No JSON key is used. The runtime service account should not be selected merely
because it exists; use a dedicated caller identity or an identity explicitly
approved for invocation.

`roles/iam.serviceAccountOpenIdTokenCreator` contains only
`iam.serviceAccounts.getOpenIdToken`. It is sufficient for this helper's
audience-bound OIDC token operation and is intentionally narrower than
`roles/iam.serviceAccountTokenCreator`, which also permits access-token and
signature operations. Grant it on the one caller service account, not on the
project. The IAM Credentials API (`iamcredentials.googleapis.com`) must be enabled
before the Phase 2 invocation.

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

### First creation without a circular audience claim

The Google-generated `run.app` URL does not exist until the first creation has
completed. Therefore the first deploy must use an explicit fail-closed bootstrap
revision; it must not claim that the final audience or Firestore isolation has
already been observed.

For a future separately authorized deployment window:

1. Copy `deployment.example.json` to the ignored `deployment.review.json` and fill
   distinct approved caller/runtime service accounts. Leave `deploymentStage` as
   `bootstrap` and keep the exact bootstrap audience sentinel.
2. Copy `.env.example` to the ignored `.env.rocha-plus-homologacao` and use exactly
   the reviewed bootstrap values. Never commit it.
3. Validate both files together with
   `node validate-deploy-config.cjs deployment.review.json .env.rocha-plus-homologacao`.
4. Run `npm ci`, `npm test`, and `npm run check` with Node.js 22.
5. If separately authorized, create the private service. Do not invoke it. The
   bootstrap audience is deliberately not accepted by a newly created Cloud Run
   service and the application verifier also requires that sentinel, so no normal
   service-URL token can reach the diagnostic logic.
6. Record `serviceConfig.uri`, the backing service URL, ingress, custom audiences,
   and IAM policy. Set `deploymentStage` to `verification`, replace the sentinel in
   both files with the exact accepted Google-reported URL, rerun the local gates,
   and deploy the verification revision only under the same separate authorization.

The validator accepts only the exact sentinel in `bootstrap` and only a
Google-managed HTTPS service URL in `verification`. It does not contain flags
asserting that either Firestore access result has been proved.

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

### Minimum deployment, build and cleanup authority

Keep the deployment principal, build identity, runtime identity and invocation
principal distinct. Before an authorized first deploy, verify:

- the deployer has `roles/cloudfunctions.developer` (or an equivalently narrow
  custom role) and `serviceusage.services.use` on the project;
- the deployer has `iam.serviceAccounts.actAs` (`roles/iam.serviceAccountUser`)
  on the selected runtime service account and on the actual Cloud Build service
  account, not on every service account in the project;
- the actual Cloud Build service account has `roles/cloudbuild.builds.builder` on
  the project, and the Google-managed service agents retain their standard service
  agent roles;
- the runtime service account has only the separately reviewed database-scoped read
  authority. The deployment principal does not need that data access;
- deletion of the temporary function is covered by
  `cloudfunctions.functions.delete` (included in Cloud Functions Developer), while
  removing the temporary caller binding requires `run.services.getIamPolicy` and
  `run.services.setIamPolicy` on the one service; and
- artifact cleanup policy management is separate: it requires
  `artifactregistry.repositories.update`; actual policy-driven deletion uses
  `artifactregistry.versions.delete`. Do not broaden the deployer merely to combine
  these cleanup duties.

The broad `roles/cloudfunctions.admin`, project-wide Service Account User, and
`roles/iam.serviceAccountTokenCreator` are not minimum requirements for this flow.
No IAM grant is implied by this document.

### APIs and private creation

Before deployment, confirm that `cloudfunctions.googleapis.com`,
`run.googleapis.com`, `cloudbuild.googleapis.com` and
`artifactregistry.googleapis.com` are enabled. If the deployer does not have
`serviceusage.services.enable`, an administrator must enable them beforehand;
deploy must not be used as an implicit API-enablement step. The project is already a
Firebase project, so its Firebase project setup is a prerequisite rather than a
permission to add during this window. `firestore.googleapis.com` is required for the
later data probe, and `iamcredentials.googleapis.com` for Phase 2 token minting;
neither is a reason to invoke the diagnostic during deployment. Eventarc, Pub/Sub
and Cloud Scheduler APIs are not required by this HTTP-only function.

The source declares `invoker: 'private'`; the contract test verifies the generated
GCF v2 endpoint contains only the `private` invoker marker. The first creation must
not use `--allow-unauthenticated`, grant `allUsers`, or add the caller binding as part
of the deploy. Add the one `roles/run.invoker` binding only in the separately
authorized Phase 2 window. Thus the service can remain private from creation; this
local declaration still requires post-create IAM evidence to prove the remote state.

### Documentary review versus Phase 2 proof

Predeploy evidence may establish only configuration facts: exact project, region,
codebase, distinct identities, runtime identity selection, private source option,
reviewed IAM policy, enabled APIs and (after bootstrap) the observed URL. Store those
facts with policy snapshots and timestamps outside the deploy gate.

Effective isolation is a Phase 2 runtime result. It is proved only by one authorized
request returning `200 isolation_proven`, with a matching application trace, where
the named database read succeeds and the `(default)` read returns
`permission_denied`. A reviewed policy, absence of an obvious project-level role,
successful deploy, platform 401/403, missing database, or either reviewer's boolean
assertion is not effective isolation proof.

Run the local contract tests with Node.js 22:

```sh
npm test
```
