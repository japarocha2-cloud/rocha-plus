import {inspectRegularPaymentContract} from './regular_payment_contract.mjs';
// Read-only preparation: provider exposes GET-equivalent methods only. No cancellation/refund writer.
export async function prepareMonthlyOnly({monthlyPayment,annualPayment,provider,merchantId}) {
 const monthly=await inspectRegularPaymentContract({payment:monthlyPayment,provider,merchantId});
 const annualRef=annualPayment?.metadata?.preapproval_id||annualPayment?.point_of_interaction?.transaction_data?.subscription_id;
 if(typeof annualRef!=='string'||!/^[a-zA-Z0-9_-]{8,100}$/.test(annualRef))throw Error('annual-contract-reference-required');
 const rawAnnual=await provider.subscription(annualRef);let annual;
 if(rawAnnual?.status==='cancelled'){
  const t=rawAnnual.auto_recurring;
  if(rawAnnual.id!==annualRef||String(rawAnnual.collector_id)!==String(merchantId)||String(annualPayment.collector_id)!==String(merchantId)||String(rawAnnual.payer_id)!==String(annualPayment.payer?.id)||rawAnnual.payer_id==null||t?.transaction_amount!==49.5||t.currency_id!=='BRL'||!((t.frequency===1&&t.frequency_type==='years')||(t.frequency===12&&t.frequency_type==='months')))throw Error('cancelled-contract-not-verified');
  annual={plan:'annual',subscriptionId:annualRef};
 }else annual=await inspectRegularPaymentContract({payment:annualPayment,provider:{subscription:async id=>id===annualRef?rawAnnual:null},merchantId});
 if(monthly.plan!=='monthly'||annual.plan!=='annual'||monthly.subscriptionId===annual.subscriptionId||
 monthlyPayment.transaction_amount!==4.5||annualPayment.transaction_amount!==49.5||
 String(monthlyPayment.payer?.id)!==String(annualPayment.payer?.id)||
 monthlyPayment.status!=='approved'||monthlyPayment.transaction_amount_refunded!==0)throw Error('monthly-only-evidence-required');
 return {dryRun:true,writes:0,readyToApply:false,externalRefund:{reportedByOwner:true,amountCents:4950,reconciledWithReceipt:false,mercadoPagoRefundConfirmed:false},
 annual:{paymentStatusUnchanged:annualPayment.status,cancellationPreview:rawAnnual.status==='cancelled'?{operation:'NO_OP',reason:'already_cancelled'}:{method:'PUT',path:'/preapproval/'+annual.subscriptionId,body:{status:'cancelled'},purpose:'stop future annual recurrence only',requiresProviderSchemaReview:true,requiresFreshReadAndSpecificAuthorization:true},refundRequest:null},
 monthly:{subscriptionId:monthly.subscriptionId,providerMutation:null,paymentId:String(monthlyPayment.id),periodCandidate:{start:monthly.periodStart,end:monthly.periodEnd,independentlyReviewed:false}},
 access:{eligiblePaymentIds:[String(monthlyPayment.id)],excludedPaymentIds:[String(annualPayment.id)],writePreview:null,blockedBy:['installed-backend-and-session','fresh-private-baseline','reviewed-monthly-coverage','specific-write-authorization']}};
}
