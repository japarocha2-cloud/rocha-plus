'use strict';

const crypto = require('node:crypto');
const process = require('node:process');

const GOOGLE_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const GOOGLE_ISSUERS = new Set(['https://accounts.google.com', 'accounts.google.com']);

class TokenVerificationError extends Error {}

function decodeJsonSegment(segment, label) {
  try {
    const value = JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('not object');
    return value;
  } catch (_) {
    throw new TokenVerificationError(`invalid JWT ${label}`);
  }
}

function parseJwt(token) {
  if (typeof token !== 'string' || token.includes('\n') || token.includes('\r')) {
    throw new TokenVerificationError('invalid JWT input');
  }
  const parts = token.split('.');
  if (parts.length !== 3 || parts.some(part => !part)) {
    throw new TokenVerificationError('JWT must contain exactly three segments');
  }
  return {
    header: decodeJsonSegment(parts[0], 'header'),
    claims: decodeJsonSegment(parts[1], 'payload'),
    signed: Buffer.from(`${parts[0]}.${parts[1]}`),
    signature: Buffer.from(parts[2], 'base64url'),
  };
}

function audienceMatches(actual, expected) {
  if (typeof actual === 'string') return actual === expected;
  return Array.isArray(actual) && actual.length === 1 && actual[0] === expected;
}

function validateClaims(claims, options) {
  const now = options.now ?? Math.floor(Date.now() / 1000);
  const skew = options.clockSkewSeconds ?? 30;
  if (!GOOGLE_ISSUERS.has(claims.iss)) throw new TokenVerificationError('issuer is not Google');
  if (!audienceMatches(claims.aud, options.audience)) {
    throw new TokenVerificationError('audience does not exactly match');
  }
  if (typeof claims.sub !== 'string' || !claims.sub) throw new TokenVerificationError('subject is missing');
  if (!Number.isFinite(claims.exp) || claims.exp <= now - skew) throw new TokenVerificationError('token is expired');
  if (!Number.isFinite(claims.iat) || claims.iat > now + skew) throw new TokenVerificationError('issued-at is invalid');
  if (claims.nbf !== undefined && (!Number.isFinite(claims.nbf) || claims.nbf > now + skew)) {
    throw new TokenVerificationError('token is not active');
  }
  if (claims.azp !== undefined && (typeof claims.azp !== 'string' || !claims.azp)) {
    throw new TokenVerificationError('authorized party is malformed');
  }
  if (options.allowedAuthorizedParties?.length &&
      (!claims.azp || !options.allowedAuthorizedParties.includes(claims.azp))) {
    throw new TokenVerificationError('authorized party is not allowed');
  }
  if (options.allowedEmails?.length) {
    if (claims.email_verified !== true || !options.allowedEmails.includes(claims.email)) {
      throw new TokenVerificationError('email identity is not allowed');
    }
  }
  if (options.allowedSubjects?.length && !options.allowedSubjects.includes(claims.sub)) {
    throw new TokenVerificationError('subject identity is not allowed');
  }
}

async function fetchGoogleJwks(fetchImpl = globalThis.fetch) {
  const response = await fetchImpl(GOOGLE_JWKS_URL, {redirect: 'error'});
  if (!response.ok) throw new TokenVerificationError('Google JWKS request failed');
  const body = await response.json();
  if (!body || !Array.isArray(body.keys)) throw new TokenVerificationError('Google JWKS response is invalid');
  return body.keys;
}

async function verifyGoogleIdToken(token, options) {
  if (!options || typeof options.audience !== 'string' || !options.audience) {
    throw new TokenVerificationError('expected audience is required');
  }
  const parsed = parseJwt(token);
  if (parsed.header.alg !== 'RS256' || typeof parsed.header.kid !== 'string') {
    throw new TokenVerificationError('only keyed RS256 Google tokens are accepted');
  }
  const jwks = options.jwks ?? await fetchGoogleJwks(options.fetchImpl);
  const jwk = jwks.find(key => key.kid === parsed.header.kid && key.kty === 'RSA');
  if (!jwk) throw new TokenVerificationError('signing key is not trusted');
  let key;
  try {
    key = crypto.createPublicKey({key: jwk, format: 'jwk'});
  } catch (_) {
    throw new TokenVerificationError('signing key is invalid');
  }
  if (!crypto.verify('RSA-SHA256', parsed.signed, key, parsed.signature)) {
    throw new TokenVerificationError('signature is invalid');
  }
  validateClaims(parsed.claims, options);
  return parsed.claims;
}

function parseCli(argv) {
  const options = {allowedEmails: []};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--stdin') options.stdin = true;
    else if (arg === '--audience') options.audience = argv[++i];
    else if (arg === '--allowed-email') options.allowedEmails.push(argv[++i]);
    else throw new TokenVerificationError(`unknown argument: ${arg}`);
  }
  if (!options.stdin || !options.audience || options.allowedEmails.length === 0) {
    throw new TokenVerificationError('--stdin, --audience and --allowed-email are required');
  }
  return options;
}

async function main() {
  const options = parseCli(process.argv.slice(2));
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  const token = Buffer.concat(chunks).toString('utf8').trim();
  const claims = await verifyGoogleIdToken(token, options);
  process.stdout.write(JSON.stringify({
    valid: true,
    iss: claims.iss,
    aud: claims.aud,
    sub: claims.sub,
    email: claims.email,
    exp: claims.exp,
  }) + '\n');
}

if (require.main === module) {
  main().catch(error => {
    process.stderr.write(`token rejected: ${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {TokenVerificationError, parseJwt, validateClaims, verifyGoogleIdToken};
