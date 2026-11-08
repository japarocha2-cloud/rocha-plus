import 'package:flutter/material.dart';

import '../app_release_policy.dart';
import '../auth/subscription_access.dart';
import '../theme/rocha_theme.dart';

/// Account access is checked by the backend, never inferred from a plan card.
class SubscriptionScreen extends StatefulWidget {
  final String? accountUid;
  final Widget? accountActions;
  final Future<SubscriptionAccessResult?> Function(String)? verifyAccess;

  const SubscriptionScreen({super.key, this.accountUid, this.verifyAccess, this.accountActions});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  bool checking = false;
  SubscriptionAccessResult? result;
  bool attempted = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _clear() {
    generation++;
    result = null;
    attempted = false;
    checking = false;
  }

  @override
  void didUpdateWidget(covariant SubscriptionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountUid != widget.accountUid ||
        oldWidget.verifyAccess != widget.verifyAccess) {
      _clear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(_clear);
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _dateLabel(DateTime value) {
    final date = value.toUtc();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  bool get canCheck {
    final uri = Uri.tryParse(SubscriptionAccess.endpoint);
    return widget.accountUid != null &&
        (widget.verifyAccess != null ||
            (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty));
  }

  Future<void> _checkAccess() async {
    if (checking || !canCheck) return;
    final revision = ++generation;
    final uid = widget.accountUid!;
    setState(() {
      checking = true;
      attempted = true;
      result = null;
    });
    SubscriptionAccessResult? response;
    try {
      response = await (widget.verifyAccess ?? SubscriptionAccess.check)(uid)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      response = null;
    }
    if (!mounted || revision != generation || uid != widget.accountUid) return;
    setState(() {
      result = response?.uid == uid ? response : null;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Rocha+ • Assinaturas'), backgroundColor: const Color(0xFF130924)),
        body: SafeArea(
          child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF130924), Color(0xFF080611)])),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.accountActions != null) widget.accountActions!,
                      Text('Rocha+ • Assinaturas',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estado da conta'),
                              const SizedBox(height: 8),
                              Text(
                                checking ? 'Consultando o servidor...'
                                    : result?.label ?? (attempted
                                        ? 'Não foi possível confirmar o acesso'
                                        : 'Assinatura ainda não verificada'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (result?.expiresAt != null) ...[
                                const SizedBox(height: 8),
                                Text('Validade informada pelo servidor (UTC): '
                                    '${_dateLabel(result!.expiresAt!)}'),
                              ],
                              const SizedBox(height: 12),
                              Text(RochaReleasePolicy.betaAccessIsFree
                                  ? 'Esta versão de testes permite assistir sem assinatura. O bloqueio por assinatura está desativado.'
                                  : 'O acesso depende da confirmação do servidor.'),
                              const SizedBox(height: 12),
                              const Text(
                                'Um pagamento já realizado precisa ser vinculado à conta e validado. Não pague novamente para tentar liberar o acesso.',
                              ),
                              if (canCheck) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: checking ? null : _checkAccess,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(checking
                                      ? 'Verificando...'
                                      : 'Verificar acesso'),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'A consulta da assinatura ainda não está disponível nesta versão.',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Lançamento Rocha+ • TV ao vivo agora. Filmes e séries no futuro.', style: TextStyle(color: Color(0xFFD8C7F1))),
                      const SizedBox(height: 14),
                      Text('Planos',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      const _PlanCard(
                          name: 'Plano Fundador Mensal', price: 'R\$ 7,90 por mês'),
                      const _PlanCard(
                          name: 'Plano Fundador Anual', price: 'R\$ 86,90 por ano'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF281605), border: Border.all(color: RochaColors.gold, width: 1.5), borderRadius: BorderRadius.circular(16)),
                        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Icon(Icons.workspace_premium, color: RochaColors.gold), SizedBox(width: 8), Expanded(child: Text('Benefício fundador • preço de lançamento', style: TextStyle(color: RochaColors.gold, fontWeight: FontWeight.bold)))]),
                          SizedBox(height: 8),
                          Text('A manutenção do preço depende das condições comerciais do plano contratado e de sua assinatura permanecer ativa.'),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Teste gratuito de até 7 dias para contas elegíveis. O prazo e a elegibilidade são confirmados pelo servidor.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Preços de lançamento para assinantes fundadores. A contratação depende da disponibilidade do checkout homologado. Não pague novamente para tentar liberar um acesso já contratado.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      );
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;

  const _PlanCard({required this.name, required this.price});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF381064), Color(0xFF170B31)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB445F4), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x553F0A80), blurRadius: 14)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(name.contains('Anual') ? Icons.calendar_month_outlined : Icons.live_tv_outlined,
                color: RochaColors.gold, size: 32),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(price, style: const TextStyle(color: RochaColors.gold, fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 6),
              const Text('Preço de lançamento • benefício fundador', style: TextStyle(fontSize: 12, color: Color(0xFFE4D7F2))),
            ])),
          ]),
        ),
      );
}
