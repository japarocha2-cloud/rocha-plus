import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    backgroundColor: const Color(0xFF102633),
    appBar: AppBar(title: Text(widget.document.title)),
    body: Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text(
        'Prévia para testes. Documentos em rascunho; sem venda ativa.',
        style: TextStyle(color: Color(0xFFFFD67A)))),
      if (widget.document.searchable) Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Buscar na ajuda',
            labelStyle: TextStyle(color: Color(0xFF70E6F2))),
          onChanged: (value) => setState(() => _query = value.toLowerCase().trim()))),
      Expanded(child: FutureBuilder<String>(future: _content, builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Documento indisponível. Tente novamente.', style: TextStyle(color: Colors.white)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final sections = snapshot.data!.split(RegExp(r'(?=^## )', multiLine: true));
        final visible = sections.where((section) => _query.isEmpty || section.toLowerCase().contains(_query)).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (visible.isEmpty) const Text('Nenhuma resposta encontrada.', style: TextStyle(color: Colors.white)),
          for (final section in visible) Padding(padding: const EdgeInsets.only(bottom: 16),
            child: SelectableText(section, style: const TextStyle(color: Colors.white, height: 1.5))),
        ]);
      })),
    ]),
  );
}
