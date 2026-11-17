import 'dart:async';

import 'package:flutter/material.dart';

import '../app_release_policy.dart';
import '../auth/subscription_checkout.dart';
import '../auth/subscription_access.dart';
import '../theme/rocha_theme.dart';

/// Account access is checked by the backend, never inferred from a plan card.
class SubscriptionScreen extends StatefulWidget {
  final String? accountUid;
  final Widget? accountActions;
  final Future<SubscriptionAccessResult?> Function(String)? verifyAccess;
  /// Device clock (injectable for tests). Countdown is corrected by the server clock.
  final DateTime Function() clock;
  final Duration tick;

  const SubscriptionScreen({super.key, this.accountUid, this.verifyAccess, this.accountActions,
      this.clock = DateTime.now, this.tick = const Duration(seconds: 10)});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  bool checking = false;
  bool purchasing = false;
  SubscriptionAccessResult? result;
  bool attempted = false;
  int generation = 0;
  Timer? _ticker;
  bool _expiryRecheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _checkAccess(); });
    // Repaint the countdown; at zero ask the server once (access stays server-owned).
    _ticker = Timer.periodic(widget.tick, (_) {
      if (!mounted) return;
      final left = result?.remaining(widget.clock());
      if (result?.reason == 'trial' && left != null && left <= Duration.zero &&
          !_expiryRecheckDone && !checking) {
        _expiryRecheckDone = true;
        _checkAccess();
      }
      setState(() {});
    });
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
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _checkAccess(); });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(_clear);
      _checkAccess();
    }
  }

  @override
  void dispose() {
    generation++;
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _localLabel(DateTime value) {
    final date = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} às '
        '${two(date.hour)}:${two(date.minute)}';
  }

  List<Widget> _validity() {
    final current = result;
    final end = current?.expiresAt;
    if (current == null || end == null) return const [];
    final left = current.remaining(widget.clock());
    if (current.reason == 'trial') {
      final ended = left == null || left <= Duration.zero;
      return [
        const SizedBox(height: 12),
        Text(ended ? 'Teste gratuito encerrado' : remainingLabel(left),
            key: const ValueKey('trial-countdown'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: ended ? const Color(0xFFFF8A80) : RochaColors.gold)),
        const SizedBox(height: 4),
        Text('Vence em ${_localLabel(end)} (horário deste aparelho)'),
        Text('Validade informada pelo servidor (UTC): ${_dateLabel(end)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFBDB3CC))),
      ];
    }
    return [
      const SizedBox(height: 8),
      if (current.reason == 'paid')
        Text('Assinatura ativa até ${_localLabel(end)} (horário deste aparelho)',
            key: const ValueKey('paid-until')),
      Text('Validade informada pelo servidor (UTC): ${_dateLabel(end)}'),
    ];
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
      if (result?.reason == 'trial' &&
          (result!.remaining(widget.clock()) ?? Duration.zero) > Duration.zero) {
        _expiryRecheckDone = false;
      }
    });
  }

  Future<void> _purchase(String plan) async {
    final uid = widget.accountUid;
    if (purchasing || uid == null) return;
    setState(() => purchasing = true);
    try {
      await SubscriptionCheckout.open(uid, plan);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível abrir o checkout. Tente novamente mais tarde.')));
      }
    } finally {
      if (mounted) setState(() => purchasing = false);
    }
  }

  static const _cardBorder = Color(0xFFB445F4);

  Widget _glassCard({required Widget child, Color border = _cardBorder, Key? key}) => Container(
        key: key,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF2A0F4F), Color(0xFF120A26)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border.withValues(alpha: 0.85), width: 1.4),
          boxShadow: [BoxShadow(color: border.withValues(alpha: 0.28), blurRadius: 18)],
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF07040F),
        appBar: AppBar(title: const Text('Rocha+ • Assinaturas'), backgroundColor: const Color(0xFF130924)),
        body: SafeArea(
          child: Container(
          decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0.6, -1.0), radius: 1.6,
              colors: [Color(0xFF3A1270), Color(0xFF130924), Color(0xFF07040F)], stops: [0, 0.45, 1])),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.accountActions != null) widget.accountActions!,
                      // 1. Cosmic header
                      Container(
                        key: const ValueKey('subscription-header'),
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [Color(0xFF5A20A8), Color(0xFF24113D), Color(0xFF0D0820)]),
                          border: Border.all(color: RochaColors.gold.withValues(alpha: 0.7), width: 1.2),
                          boxShadow: [BoxShadow(color: const Color(0xFF7B2FF7).withValues(alpha: 0.35), blurRadius: 26)],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.auto_awesome, color: RochaColors.gold),
                            SizedBox(width: 10),
                            Expanded(child: Text('Rocha+ • Assinaturas',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white))),
                          ]),
                          const SizedBox(height: 10),
                          const Text('Lançamento Rocha+ • TV ao vivo agora. Filmes e séries no futuro.',
                              style: TextStyle(color: Color(0xFFE8DDF8), fontSize: 15, height: 1.3)),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      // 2. Account state (server-owned, unchanged logic)
                      _glassCard(
                        key: const ValueKey('subscription-account-state'),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estado da conta', style: TextStyle(color: Color(0xFFD8C7F1), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(
                                checking ? 'Consultando o servidor...'
                                    : result?.label ?? (attempted
                                        ? 'Não foi possível confirmar o acesso'
                                        : 'Assinatura ainda não verificada'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                              ),
                              ..._validity(),
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
                                  style: OutlinedButton.styleFrom(foregroundColor: RochaColors.gold,
                                      side: const BorderSide(color: RochaColors.gold)),
                                  onPressed: checking ? null : _checkAccess,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(checking
                                      ? 'Verificando...'
                                      : 'Verificar acesso'),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                Text(widget.accountUid == null
                                    ? 'Entre com sua conta para consultar sua assinatura.'
                                    : 'O serviço de consulta não está configurado neste aplicativo.'),
                              ],
                            ],
                          ),
                      ),
                      // 3-4. Founder plans (existing buttons and callbacks)
                      _sectionTitle('Planos'),
                      _PlanCard(name: 'Plano Fundador Mensal', price: 'R\$ 7,90 por mês',
                          onSubscribe: purchasing || widget.accountUid == null ? null : () => _purchase('monthly')),
                      _PlanCard(name: 'Plano Fundador Anual', price: 'R\$ 86,90 por ano',
                          onSubscribe: purchasing || widget.accountUid == null ? null : () => _purchase('annual')),
                      const SizedBox(height: 6),
                      // 5. Gold loyalty card (informative only)
                      Container(
                        key: const ValueKey('subscription-loyalty'),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF3A2306), Color(0xFF1C1003)]),
                          border: Border.all(color: RochaColors.gold, width: 1.6),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: RochaColors.gold.withValues(alpha: 0.25), blurRadius: 18)],
                        ),
                        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.workspace_premium, color: RochaColors.gold),
                            SizedBox(width: 8),
                            Expanded(child: Text('Recompensa pela fidelidade',
                                style: TextStyle(color: RochaColors.gold, fontWeight: FontWeight.w900, fontSize: 17))),
                          ]),
                          SizedBox(height: 6),
                          Text('Benefício fundador • preço de lançamento',
                              style: TextStyle(color: Color(0xFFFFE3A3), fontWeight: FontWeight.w700)),
                          SizedBox(height: 8),
                          Text('A manutenção do preço depende das condições comerciais do plano contratado e de sua assinatura permanecer ativa.',
                              style: TextStyle(color: Color(0xFFF5EBD6), height: 1.3)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Teste gratuito de até 7 dias para contas elegíveis. O prazo e a elegibilidade são confirmados pelo servidor.',
                        style: TextStyle(color: Color(0xFFE8DDF8)),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Pagamento único pelo período escolhido, sem renovação automática. A licença depende da confirmação financeira pelo servidor.',
                        style: TextStyle(color: Color(0xFFE8DDF8)),
                      ),
                      // 6-8. Future update (information only, no purchase)
                      _sectionTitle('Atualização futura — quando chegarem filmes e séries'),
                      const _InfoPriceCard(
                        key: ValueKey('future-founders'),
                        title: 'Assinantes fundadores',
                        monthly: 'R\$ 7,90', annual: 'R\$ 86,90',
                        note: 'Valores atuais do plano fundador.',
                        accent: Color(0xFFB445F4),
                      ),
                      const SizedBox(height: 12),
                      const _InfoPriceCard(
                        key: ValueKey('future-new-subscribers'),
                        title: 'Novos assinantes após a expansão',
                        monthly: 'R\$ 15,50', annual: 'R\$ 170,50',
                        badge: 'PREVISÃO FUTURA — INDISPONÍVEL PARA CONTRATAÇÃO',
                        note: 'Valores previstos, sujeitos a alteração. Não há contratação disponível.',
                        accent: Color(0xFF8A7AA8),
                      ),
                      // 9. Plans summary
                      _sectionTitle('Resumo dos planos'),
                      _glassCard(
                        key: const ValueKey('subscription-summary'),
                        child: Table(
                          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.2)},
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            _summaryRow(const ['Plano', 'Fundador', 'Após expansão*'], header: true),
                            _summaryRow(const ['Mensal', 'R\$ 7,90', 'R\$ 15,50']),
                            _summaryRow(const ['Anual', 'R\$ 86,90', 'R\$ 170,50']),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('* Previsão futura, indisponível para contratação.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFBDB3CC))),
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

  TableRow _summaryRow(List<String> cells, {bool header = false}) => TableRow(children: [
        for (final (i, text) in cells.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(text, style: TextStyle(
              fontWeight: header || i == 0 ? FontWeight.w800 : FontWeight.w600,
              color: header ? const Color(0xFFD8C7F1) : (i == 1 ? RochaColors.gold : Colors.white),
              fontSize: header ? 13 : 15,
            )),
          ),
      ]);
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;

  final VoidCallback? onSubscribe;
  const _PlanCard({required this.name, required this.price, this.onSubscribe});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF4A1585), Color(0xFF1B0B38)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC77DFF), width: 1.6),
          boxShadow: [BoxShadow(color: const Color(0xFF9D4EDD).withValues(alpha: 0.45), blurRadius: 20)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(name.contains('Anual') ? Icons.calendar_month_outlined : Icons.live_tv_outlined,
                color: RochaColors.gold, size: 34),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(price, style: const TextStyle(color: RochaColors.gold, fontWeight: FontWeight.w900, fontSize: 26)),
              ),
              const SizedBox(height: 6),
              const Text('Preço de lançamento • benefício fundador', style: TextStyle(fontSize: 12.5, color: Color(0xFFE4D7F2))),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: RochaColors.gold,
                  foregroundColor: const Color(0xFF1A0F00),
                  disabledBackgroundColor: const Color(0xFF5B4A2A),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: onSubscribe,
                child: const Text('Assinar com Mercado Pago'),
              ),
            ])),
          ]),
        ),
      );
}

/// Informative price card. Deliberately has no button or link.
class _InfoPriceCard extends StatelessWidget {
  final String title;
  final String monthly;
  final String annual;
  final String? badge;
  final String note;
  final Color accent;
  const _InfoPriceCard({super.key, required this.title, required this.monthly, required this.annual,
      this.badge, required this.note, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF140B26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent, width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF3B2A12), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D))),
              child: Text(badge!, style: const TextStyle(color: Color(0xFFFFD08A), fontWeight: FontWeight.w900, fontSize: 12)),
            ),
            const SizedBox(height: 10),
          ],
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(spacing: 18, runSpacing: 6, children: [
            Text('Mensal $monthly', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF2E9FF))),
            Text('Anual $annual', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF2E9FF))),
          ]),
          const SizedBox(height: 8),
          Text(note, style: const TextStyle(fontSize: 12.5, color: Color(0xFFBDB3CC))),
        ]),
      );
}
