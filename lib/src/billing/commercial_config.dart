/// Build-time isolation: the frozen Mercado Pago variant keeps its own prices.
abstract final class CommercialConfig {
  static const asaas = bool.fromEnvironment('ROCHA_ASAAS_VARIANT');
  static const appName = asaas ? 'Rocha+ Asaas' : 'Rocha+';
  static const provider = asaas ? 'Asaas' : 'Mercado Pago';
  static const monthlyPrice = asaas ? r'R$ 5,50' : r'R$ 4,90';
  static const annualPrice = r'R$ 55,00';
  static const setupMessage = 'Pagamentos Asaas em preparação. A contratação ainda não está disponível.';
}
