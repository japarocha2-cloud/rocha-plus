import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'billing_controller.dart';

class SubscriptionScreen extends StatelessWidget {
  final BillingController controller;
  final Future<void> Function()? onSignOut;
  const SubscriptionScreen({super.key, required this.controller, this.onSignOut});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller, builder: (_, __) => Scaffold(
      appBar: AppBar(title: const Text('Assinatura Rocha+')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
          const Text('Rocha+ mensal', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(controller.beta ? 'Beta gratuito: sem cobrança e sem compra disponível.'
            : 'R\$ 4,90 por mês. Reprodução disponível somente com assinatura ativa.'),
          const SizedBox(height: 12),
          const Text('7 dias gratuitos para novos assinantes elegíveis, quando a Google Play oferecer o teste. Depois, R\$ 4,90/mês com renovação automática. Cancele na Google Play antes do fim do teste para evitar cobrança.'),
          if (!controller.beta) ...[
            const SizedBox(height: 16),
            Text(controller.allowed ? 'Assinatura ativa' : 'Assinatura não confirmada'),
            if (controller.state == 'SUBSCRIPTION_STATE_PENDING')
              const Text('Pagamento pendente. Aguarde a confirmação da Google Play.'),
            if (controller.expiresAt != null)
              Text('Acesso até: ${DateTime.fromMillisecondsSinceEpoch(controller.expiresAt!).toLocal()}'),
            if (controller.allowed && !controller.autoRenewing)
              const Text('Renovação desativada. O acesso termina na data indicada.'),
            if (!controller.allowed)
              ...controller.offers.map((offer) => FilledButton(
                onPressed: controller.busy ? null : () => controller.buy(offer),
                child: Text(controller.isTrial(offer)
                  ? 'Iniciar 7 dias grátis — depois R\$ 4,90/mês'
                  : 'Assinar por R\$ 4,90/mês'))),
            if (controller.offers.isEmpty)
              const Text('Oferta indisponível. A configuração de testes da Google Play precisa estar pronta.'),
            OutlinedButton(onPressed: controller.busy ? null : controller.restore,
              child: const Text('Restaurar compras')),
            OutlinedButton(onPressed: controller.busy ? null : controller.refresh,
              child: const Text('Verificar assinatura')),
            TextButton(onPressed: () async {
              final opened = await launchUrl(Uri.parse(
                'https://play.google.com/store/account/subscriptions?sku=rocha_plus_monthly&package=com.rochaplus.app'),
                mode: LaunchMode.externalApplication);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Abra Google Play > Pagamentos e assinaturas > Assinaturas.')));
              }
            }, child: const Text('Gerenciar ou cancelar na Google Play')),
          ],
          if (controller.error != null) Text(controller.error!),
          if (controller.busy) const Center(child: CircularProgressIndicator()),
          if (onSignOut != null) TextButton(onPressed: onSignOut, child: const Text('Sair da conta')),
        ])),
      ),
    ));
}
