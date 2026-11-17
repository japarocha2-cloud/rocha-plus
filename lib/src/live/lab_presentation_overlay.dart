import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// LAB-only presentation layer over the pinned C7 selection.
///
/// It never edits the frozen catalog nor branding/c7/selection.json: it only
/// re-labels categories, hides rows and swaps a URL for a documented approved
/// one, keyed by the selection row `id`. It is bound to the exact SHA-256 of
/// the selection it was generated from; any mismatch disables it completely.
class LabPresentationOverlay {
  static const enabled = bool.fromEnvironment('ROCHA_LAB_PRESENTATION');
  static const asset = 'branding/lab/presentation_overlay.json';
  static const schema = 'rocha.lab.presentation.v1';

  /// Owner-agreed presentation order (2026-11-16).
  static const agreedOrder = <String>[
    'TV ao Vivo', 'Esportes', 'Infantil', 'Notícias', 'Documentários', 'Culinária',
    'Educação', 'Comédia', 'Filmes/Séries', 'PET', 'Outros', 'Não testados',
  ];

  final String baseSha256;
  final Map<String, LabRowOverride> rows;

  const LabPresentationOverlay._(this.baseSha256, this.rows);

  /// Parses and validates; returns null (overlay off) on any inconsistency.
  static LabPresentationOverlay? parse(String raw, {required String selectionSha256}) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['schema'] != schema || data['baseSelectionSha256'] != selectionSha256) return null;
      final order = List<String>.from(data['order'] as List);
      if (order.join('|') != agreedOrder.join('|')) return null;
      final rows = <String, LabRowOverride>{};
      for (final entry in (data['rows'] as Map<String, dynamic>).entries) {
        final row = entry.value as Map<String, dynamic>;
        final category = row['category'] as String;
        if (!agreedOrder.contains(category)) return null;
        final url = row['url'] as String?;
        if (url != null) {
          final uri = Uri.tryParse(url);
          if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty ||
              uri.userInfo.isNotEmpty || RegExp(r'\s').hasMatch(url) ||
              row['urlSource'] is! String || (row['urlSource'] as String).trim().isEmpty) {
            return null;
          }
        }
        rows[entry.key] = LabRowOverride(category: category, hidden: row['hidden'] == true, url: url);
      }
      return LabPresentationOverlay._(selectionSha256, rows);
    } catch (_) {
      return null;
    }
  }

  static Future<LabPresentationOverlay?> load(String selectionSha256,
      {Future<String> Function()? read}) async {
    if (!enabled && read == null) return null;
    try {
      final raw = await (read ?? () => rootBundle.loadString(asset))();
      return parse(raw, selectionSha256: selectionSha256);
    } catch (_) {
      return null;
    }
  }

  /// Rank used to order categories on screen; unknown groups go last.
  static int rank(String group) {
    final index = agreedOrder.indexOf(group);
    return index < 0 ? agreedOrder.length : index;
  }
}

class LabRowOverride {
  final String category;
  final bool hidden;
  final String? url;
  const LabRowOverride({required this.category, this.hidden = false, this.url});
}
