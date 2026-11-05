'use strict';

const {verifyGoogleIdToken} = require('../verify-owner-token.cjs');

function oneAuthorizationHeader(req) {
  const raw = req.headers?.authorization;
  if (Array.isArray(raw) || typeof raw !== 'string' || raw.includes(',') || raw.includes('\n')) {
    throw new Error('authorization header is missing or ambiguous');
  }
  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(raw);
  if (!match) throw new Error('authorization header is not one Bearer JWT');
  return match[1];
}

function createOperatorAuthenticator(options) {
  const verifier = options.verifier ?? verifyGoogleIdToken;
  return async function authenticate(req) {
    const token = oneAuthorizationHeader(req);
    return verifier(token, {
      audience: options.audience,
      allowedEmails: options.allowedEmails,
      allowedSubjects: options.allowedSubjects,
      allowedAuthorizedParties: options.allowedAuthorizedParties,
    });
  };
}

module.exports = {createOperatorAuthenticator, oneAuthorizationHeader};
