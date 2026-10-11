import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'billing_controller.dart';
import 'subscription_documents.dart';

class SubscriptionScreen extends StatelessWidget {
  final BillingController controller;
  final Future<void> Function()? onSignOut;
  const SubscriptionScreen({super.key, required this.controller, this.onSignOut});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller, builder: (_, __) => Scaffold(
      appBar: AppBar(title: const Text('Assinatura Rocha+')),
      body: DecoratedBox(decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage('branding/home-tv-galaxy.png'), fit: BoxFit.cover),
      ), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
          const Text('Planos fundadores Rocha+', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF70E6F2))),
          const SizedBox(height: 16),
          Text(controller.beta ? 'Beta gratuito: sem cobrança e sem compra disponível.'
            : 'Reprodução disponível somente com assinatura ativa validada.'),
          const SizedBox(height: 12),
          const Card(color: Color(0xF016303D), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fundador mensal: R\$ 4,90/mês', style: TextStyle(color: Color(0xFFFFD67A), fontSize: 20)),
            SizedBox(height: 12),
            Text('Fundador anual: R\$ 53,90 por 12 meses', style: TextStyle(color: Color(0xFFFFD67A), fontSize: 20)),
            Text('Pagamento anual único. Economia de R\$ 4,90 frente a 12 mensalidades.', style: TextStyle(color: Color(0xFF8CE7CD))),
            SizedBox(height: 12),
            Text('Valores de planejamento. Nenhuma venda ativa nesta prévia.', style: TextStyle(color: Colors.white)),
            Text('Fundadores mantêm o preço original nas renovações elegíveis. Cancelar, deixar vencer e voltar implica perda do benefício. O período já pago permanece até o vencimento.', style: TextStyle(color: Colors.white)),
            SizedBox(height: 12),
            Text('Filmes e séries são uma expansão futura, sem data de lançamento. Para novos assinantes após eventual expansão: R\$ 15,50/mês ou R\$ 170,50/ano. Valores futuros, sem oferta ativa.', style: TextStyle(color: Color(0xFF70E6F2))),
            Text('Sete dias grátis somente se a oferta e a elegibilidade forem confirmadas pela Google Play. Não é uma promessa de lançamento.', style: TextStyle(color: Colors.white)),
          ]))),
          for (final document in subscriptionDocuments)
            TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SubscriptionDocumentScreen(document: document))),
              child: Text(document.title)),
          if (!controller.beta) ...[
            const SizedBox(height: 16),
            Text(controller.allowed ? 'Assinatura ativa' : 'Assinatura não confirmada'),
            if (controller.basePlanId != null)
              Text(controller.basePlanId == 'yearly' ? 'Modalidade anual' : 'Modalidade mensal'),
            if (controller.state == 'SUBSCRIPTION_STATE_PENDING')
              const Text('Pagamento pendente. Aguarde a confirmação da Google Play.'),
            if (controller.expiresAt != null)
              Text('Acesso até: ${DateTime.fromMillisecondsSinceEpoch(controller.expiresAt!).toLocal()}'),
            if (controller.allowed && !controller.autoRenewing)
              const Text('Renovação desativada. O acesso termina na data indicada.'),
            if (!controller.allowed)
              ...controller.offers.map((offer) => FilledButton(
                onPressed: controller.busy ? null : () => controller.buy(offer),
                child: Text(controller.isAnnual(offer)
                  ? 'Assinar por R\$ 53,90/ano'
                  : controller.isTrial(offer)
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
      )),
    ));
}
