// Pure planning simulator. Not connected to production billing or Firestore.
export function founderRenewal(previous, event) {
  if (previous.lost) return { ...previous, eligible: false };
  switch (event) {
    case 'cancel': return { ...previous, canceled: true };
    case 'reactivate-before-expiry': return { ...previous, canceled: false };
    case 'expire': return previous.canceled
      ? { ...previous, eligible: false, lost: true }
      : { ...previous, reviewRequired: true };
    case 'payment-failure': case 'change-plan':
      return { ...previous, reviewRequired: true };
    case 'return': return { ...previous };
    case 'renew': return { ...previous };
    default: throw new Error('unknown-event');
  }
}
