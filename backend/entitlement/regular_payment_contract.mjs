// Inspect the receipt's own subscription reference. Searches by payer_email can
// miss a contract whose email is masked/different. This NEVER grants access.
export async function inspectRegularPaymentContract({payment,provider,merchantId}) {
  const deny=()=>{throw Error('linked-contract-not-verified');};
  const id=payment?.metadata?.preapproval_id || payment?.point_of_interaction?.transaction_data?.subscription_id;
  if (typeof id!=='string' || !/^[a-zA-Z0-9_-]{8,100}$/.test(id) ||
      payment?.operation_type!=='regular_payment' || String(payment.collector_id)!==String(merchantId)) deny();
  const subscription=await provider.subscription(id), terms=subscription?.auto_recurring;
  const approved=Date.parse(payment.date_approved), start=Date.parse(terms?.start_date),end=Date.parse(subscription?.next_payment_date);
  const plan=terms?.frequency===1 && terms?.frequency_type==='months' ? 'monthly' :
    ((terms?.frequency===1 && terms?.frequency_type==='years') ||
      (terms?.frequency===12 && terms?.frequency_type==='months')) ? 'annual' : null;
  if (subscription?.id!==id || String(subscription.collector_id)!==String(merchantId) ||
      subscription.payer_id==null || payment.payer?.id==null ||
      String(subscription.payer_id)!==String(payment.payer.id) || subscription.status!=='authorized' ||
      terms?.currency_id!=='BRL' || payment.currency_id!=='BRL' ||
      typeof terms.transaction_amount!=='number' || terms.transaction_amount!==payment.transaction_amount ||
      !plan || !Number.isFinite(approved) || !Number.isFinite(start) || !Number.isFinite(end) ||
      // Narrow initial-purchase recovery only. Never assign an earlier/later cycle to this receipt.
      approved<start || approved-start>300000 || end<=approved) deny();
  return {subscriptionId:id,plan,periodStart:start,periodEnd:end,
    automaticRenewalStatus:subscription.status,nextPaymentDate:end,
    independentlyReviewed:false,accessGranted:false};
}
