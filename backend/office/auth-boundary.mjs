// The Google approval time remains authoritative even if a custom token is
// exchanged after a Firebase refresh-session revocation.
export function officeTokenVerifier({ verifyIdToken, getUser }) {
  return async (token, checkRevoked) => {
    const claims = await verifyIdToken(token, checkRevoked);
    if (claims.firebase?.sign_in_provider === 'custom') {
      const original = claims.officeGoogleAuthTime;
      if (claims.officeGoogleBridge !== true || !/^[a-f0-9]{64}$/.test(claims.officeDeviceId ?? '') || !Number.isSafeInteger(original) || original <= 0) throw new Error('Invalid Office session');
      const user = await getUser(claims.uid);
      const validAfter = Date.parse(user.tokensValidAfterTime);
      if (user.disabled || !Number.isFinite(validAfter) || original * 1000 < validAfter) throw new Error('Original Google session revoked');
    }
    return claims;
  };
}
