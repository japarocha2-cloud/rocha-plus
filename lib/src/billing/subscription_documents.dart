import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/rocha_theme.dart';

class SubscriptionDocument {
  final String title;
  final String asset;
  final bool searchable;
  const SubscriptionDocument(this.title, this.asset, {this.searchable = false});
}
const subscriptionDocuments = [
  SubscriptionDocument('Termos de Uso — rascunho', 'docs/TERMOS-DE-USO-E-ASSINATURA-RASCUNHO.md'),
  SubscriptionDocument('Regulamento Fundador — rascunho', 'docs/REGULAMENTO-PLANO-FUNDADOR-RASCUNHO.md'),
  SubscriptionDocument('Política de Privacidade — rascunho', 'docs/POLITICA-DE-PRIVACIDADE-RASCUNHO.md'),
  SubscriptionDocument('Central de Ajuda', 'docs/FAQ-ASSINATURAS-RASCUNHO.md', searchable: true),
];

class SubscriptionDocumentScreen extends StatefulWidget {
  final SubscriptionDocument document;
  const SubscriptionDocumentScreen({super.key, required this.document});
  @override
  State<SubscriptionDocumentScreen> createState() => _SubscriptionDocumentScreenState();
}
class _SubscriptionDocumentScreenState extends State<SubscriptionDocumentScreen> {
  late final Future<String> _content = rootBundle.loadString(widget.document.asset);
  String _query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.document.title)),
    body: Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text(
        'Prévia para testes. Documentos em rascunho; sem venda ativa.',
        style: TextStyle(color: RochaColors.gold))),
      if (widget.document.searchable) Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(style: const TextStyle(color: RochaColors.silver),
          decoration: const InputDecoration(labelText: 'Buscar na ajuda',
            labelStyle: TextStyle(color: RochaColors.silver)),
          onChanged: (value) => setState(() => _query = value.toLowerCase().trim()))),
      Expanded(child: FutureBuilder<String>(future: _content, builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Documento indisponível. Tente novamente.', style: TextStyle(color: RochaColors.silver)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final sections = snapshot.data!.split(RegExp(r'(?=^## )', multiLine: true));
        final visible = sections.where((section) => _query.isEmpty || section.toLowerCase().contains(_query)).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (visible.isEmpty) const Text('Nenhuma resposta encontrada.', style: TextStyle(color: RochaColors.silver)),
          for (final section in visible) Padding(padding: const EdgeInsets.only(bottom: 16),
            child: SelectableText(section, style: const TextStyle(color: RochaColors.silver, height: 1.5))),
        ]);
      })),
    ]),
  );
}
