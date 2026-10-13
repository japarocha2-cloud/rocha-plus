import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/rocha_theme.dart';

class SubscriptionScreen extends StatelessWidget {
  final Future<void> Function(String plan)? checkout;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onSignOut;
  final String? statusMessage;
  final bool busy;
  const SubscriptionScreen({super.key, this.checkout, this.onRefresh,
    this.onSignOut, this.statusMessage, this.busy = false});

  Future<void> _openPlan(BuildContext context, String plan, Uri legacy) async {
    if (busy) return;
    try {
      if (checkout != null) {
        await checkout!(plan);
      } else {
        await _openCheckout(context, legacy);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o pagamento. Tente novamente.')));
      }
    }
  }

  static final Uri _monthlyCheckout = Uri.parse('https://mpago.la/2E7yjF4');
  static final Uri _annualCheckout = Uri.parse('https://mpago.la/2b9hitF');

  Future<void> _openCheckout(BuildContext context, Uri checkout) async {
    final opened = await launchUrl(checkout, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Mercado Pago.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RochaColors.background,
    appBar: AppBar(title: const Text('Assinaturas'), actions: [
      if (onSignOut != null) TextButton(onPressed: busy ? null : onSignOut,
        child: const Text('Sair')),
    ]),
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final horizontal = constraints.maxWidth >= 820;
      final launch = _section(
        eyebrow: 'LANÇAMENTO ROCHA+',
        title: 'Entre em uma nova fase do entretenimento.',
        subtitle: 'TV aberta agora. Filmes e séries no futuro.',
        children: [
          if (checkout != null) const Text('O pagamento libera o período escolhido. A renovação depende de novo pagamento.'),
          if (statusMessage != null) Text(statusMessage!,
            key: const ValueKey('subscription-access-status')),
          if (onRefresh != null) OutlinedButton(
            onPressed: busy ? null : onRefresh,
            child: Text(busy ? 'Verificando…' : 'Já paguei / verificar acesso')),
          _PlanCard(
            title: 'Plano Fundador Mensal',
            price: 'R\$ 4,90',
            period: '/ mês',
            bullets: const ['7 dias de teste grátis', 'Preço de lançamento', 'Acesso à fase inicial com TV aberta', 'Benefício de fundador'],
            buttonLabel: 'Assinar mensal',
            onPressed: () => _openPlan(context, 'monthly', _monthlyCheckout),
          ),
          _PlanCard(
            title: 'Plano Fundador Anual',
            price: 'R\$ 55,00',
            period: '/ ano',
            bullets: const ['7 dias de teste grátis', 'Preço de lançamento', 'Acesso à fase inicial com TV aberta', 'Benefício de fundador'],
            buttonLabel: 'Assinar anual',
            onPressed: () => _openPlan(context, 'annual', _annualCheckout),
          ),
          const _FounderBenefit(),
        ],
      );
      final future = _section(
        eyebrow: 'ATUALIZAÇÃO FUTURA',
        title: 'Mais filmes. Mais séries. O mesmo compromisso com você.',
        subtitle: 'Veja como ficam os planos após a expansão.',
        children: const [
          _FutureCard(title: 'Assinantes fundadores', badge: 'PREÇO GARANTIDO',
            body: 'Mantém o preço antigo como benefício de fidelidade.'),
          _FutureCard(title: 'Novos assinantes', badge: 'APÓS A EXPANSÃO',
            body: 'Os valores desta etapa serão definidos antes da expansão.'),
        ],
      );
      return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120),
          child: horizontal ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: launch), const SizedBox(width: 20), Expanded(child: future),
          ]) : Column(children: [launch, const SizedBox(height: 24), future]))));
    })),
  );

  Widget _section({required String eyebrow, required String title,
    required String subtitle, required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: const Color(0xFF0C0912),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF2A2037))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(eyebrow, style: const TextStyle(color: RochaColors.gold,
        fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 20),
      ...children.expand((w) => [w, const SizedBox(height: 12)]),
    ]),
  );
}

class _PlanCard extends StatelessWidget {
  final String title, price, period, buttonLabel;
  final List<String> bullets;
  final VoidCallback onPressed;
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.bullets,
    required this.buttonLabel,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF171020),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF6E38A8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(price, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        Padding(padding: const EdgeInsets.only(bottom: 5), child:
          Text(period, style: const TextStyle(color: Colors.white60))),
      ]),
      const SizedBox(height: 12),
      ...bullets.map((b) => Padding(padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [const Icon(Icons.check_circle_outline, size: 17,
          color: RochaColors.gold), const SizedBox(width: 8), Expanded(child: Text(b))]))),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(buttonLabel),
        ),
      )),
    ]));
}

class _FounderBenefit extends StatelessWidget {
  const _FounderBenefit();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
      border: Border.all(color: RochaColors.gold),
      gradient: const LinearGradient(colors: [Color(0xFF2A2110), Color(0xFF15100A)])),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.workspace_premium_outlined, color: RochaColors.gold),
        SizedBox(width: 8), Expanded(child: Text('Recompensa pela fidelidade',
          style: TextStyle(fontWeight: FontWeight.w900)))]),
      SizedBox(height: 10),
      Text('PREÇO GARANTIDO', style: TextStyle(color: RochaColors.gold,
        fontWeight: FontWeight.w900)),
      SizedBox(height: 8),
      Text('Quem assinar agora mantém o preço atual mesmo após a chegada de filmes e séries, enquanto a assinatura permanecer ativa.'),
    ]));
}

class _FutureCard extends StatelessWidget {
  final String title, badge, body;
  const _FutureCard({required this.title, required this.badge, required this.body});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF171020),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: badge == 'PREÇO GARANTIDO' ? RochaColors.gold : const Color(0xFF6E38A8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(badge, style: TextStyle(color: badge == 'PREÇO GARANTIDO' ? RochaColors.gold : const Color(0xFFB56CFF),
        fontWeight: FontWeight.w900)),
      const SizedBox(height: 10), Text(body, style: const TextStyle(color: Colors.white70)),
    ]));
}

