# Firestore private diagnostic authentication

This package is deliberately isolated from the deployed application. It prepares
and invokes a private Cloud Run function without service-account keys and without
changing IAM, deploying code, or writing to Firestore.

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

Run the local contract tests with Node.js 22:

```sh
npm test
```
