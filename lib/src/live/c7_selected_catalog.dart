import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'channel.dart';
import 'c7_catalog_policy.dart';
import 'official_catalog_pin.dart';
import 'lab_presentation_overlay.dart';

class C7CatalogUnavailable implements Exception {
  final String message;
  const C7CatalogUnavailable(this.message);
  @override
  String toString() => message;
}

/// C7 selection is local, explicitly imported and pinned at build time.
/// No HTTP client, public-playlist fallback or candidate promotion exists here.
class C7SelectedCatalog {
  static const compiledSha256 = String.fromEnvironment('ROCHA_C7_CATALOG_SHA256', defaultValue: officialCatalogSha256);
  /// LAB evaluation builds may point to a validated candidate selection; its
  /// SHA-256 must then be supplied too. The official file is never replaced.
  static const selectionAsset = String.fromEnvironment('ROCHA_C7_SELECTION_ASSET',
      defaultValue: 'branding/c7/selection.json');
  final Future<String> Function() read;
  final String expectedSha256;
  /// LAB presentation layer source (tests inject it; builds need ROCHA_LAB_PRESENTATION).
  final Future<String> Function()? readOverlay;
  C7SelectedCatalog({Future<String> Function()? read, String? expectedSha256, this.readOverlay})
      : read = read ?? (() => rootBundle.loadString(selectionAsset)),
        expectedSha256 = expectedSha256 ?? compiledSha256;

  static const categories = {
    'TV ao Vivo','Esportes','Infantil','Notícias','Filmes','Séries','Documentários',
    'Música','Educação','Cultura','Entretenimento','Reality','Religiosos','Futebol',
    'Estilo de Vida','Viagens','Culinária','Comédia','Vida ao Ar Livre','Geral','Outros',
    // Portuguese labels of the remaining C7 (iptv-org) genres.
    'Legislativo','Clássicos','Compras','Negócios','Automotivo','Família','Animação',
    'Ciência','Clima','Interativo','Relaxamento','Esportes Radicais',
  };

  Future<List<Channel>> load() async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedSha256)) {
      throw const C7CatalogUnavailable('Seleção C7 não instalada: falta o SHA-256 do catálogo manual. Nenhuma playlist externa será importada.');
    }
    final String raw;
    try { raw = await read(); }
    catch (_) { throw const C7CatalogUnavailable('Arquivo da seleção C7 indisponível. Sem substituição por candidatos ou playlists externas.'); }
    if (sha256.convert(utf8.encode(raw)).toString() != expectedSha256) {
      throw const C7CatalogUnavailable('SHA-256 da seleção C7 não confere. Catálogo rejeitado sem fallback externo.');
    }
    // Bound to this exact pinned selection; null means "no LAB changes".
    final overlay = await LabPresentationOverlay.load(expectedSha256, read: readOverlay);
    try {
      final data = jsonDecode(raw) as Map<String,dynamic>;
      final provenance = data['provenance'] as Map;
      if (data['schema'] != 'rocha.c7.selection.v1' ||
          !{'owner-selection','c6-original'}.contains(provenance['kind']) ||
          provenance['reference'] is! String || (provenance['reference'] as String).trim().isEmpty ||
          provenance['sourceSha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(provenance['sourceSha256'] as String)) {
        throw const FormatException('Invalid selection provenance');
      }
      final removals = data['removals'] as List;
      final rows = data['channels'] as List;
      if (rows.isEmpty) throw const FormatException('Missing recovered selection');
      final seen = <String>{};
      final channels = <Channel>[];
      for (final value in rows) {
        final row = value as Map<String,dynamic>;
        final id = row['id'] as String;
        final name = row['name'] as String;
        final url = row['url'] as String;
        final group = row['group'] as String;
        final uri = Uri.tryParse(url);
        if (id.isEmpty || !seen.add(id) || name.trim().isEmpty ||
            uri == null || !{'http','https'}.contains(uri.scheme) || uri.host.isEmpty ||
            uri.userInfo.isNotEmpty || RegExp(r'\s').hasMatch(url) || !categories.contains(group)) {
          throw const FormatException('Invalid selected channel');
        }
        final alternatives = row['urls'] == null
            ? const <String>[] : List<String>.from(row['urls'] as List);
        if (alternatives.isNotEmpty) {
          final preferred = row['preferredUrlIndex'];
          if (preferred is! int || preferred < 0 || preferred >= alternatives.length ||
              alternatives[preferred] != url || alternatives.any((value) {
                final candidate = Uri.tryParse(value);
                return candidate == null || !{'http','https'}.contains(candidate.scheme) ||
                    candidate.host.isEmpty || candidate.userInfo.isNotEmpty ||
                    RegExp(r'\s').hasMatch(value);
              })) {
            throw const FormatException('Invalid approved alternatives');
          }
        }
        final key = C7CatalogPolicy.identity(name);
        final lab = overlay?.rows[id];
        final shownUrl = lab?.url ?? url;
        for (final value in removals) {
          final tombstone = value as Map;
          if (tombstone['id'] == id || (tombstone['identity'] == key &&
              (tombstone['blockIdentity'] == true || tombstone['url'] == url ||
               tombstone['url'] == shownUrl))) {
            throw const FormatException('Removed channel reinclusion');
          }
        }
        if (lab != null && lab.hidden) continue;
        // Declared additions that repeat a base card (same identity AND same URL)
        // are not shown twice. The pinned file and frozen source stay unchanged.
        if (row['sourceLayer'] == 'addition' &&
            channels.any((c) => C7CatalogPolicy.identity(c.name) == key && c.url == shownUrl)) {
          continue;
        }
        final genres = row['genres'] == null ? const <String>[] : List<String>.from(row['genres'] as List);
        channels.add(Channel(name:name, url:shownUrl, group:lab?.category ?? group,
            logo:row['logo'] as String?,
            genres:genres, preferredEngine:row['preferredEngine'] as String?,
            alternateUrls: lab?.url == null || alternatives.contains(shownUrl)
                ? alternatives : const <String>[]));
      }
      // Only CazéTV moves; every other relative position/field stays intact.
      final caze = channels.where(C7CatalogPolicy.isCaze).toList();
      if (caze.isEmpty) return channels;
      final rest = channels.where((c) => !C7CatalogPolicy.isCaze(c)).toList();
      final first = rest.indexWhere((c) => c.group == 'Esportes');
      rest.insertAll(first < 0 ? rest.length : first, caze);
      return rest;
    } catch (_) {
      throw const C7CatalogUnavailable('Seleção C7 inválida ou com reinclusão de canal removido. Nenhum inventário pendente será usado.');
    }
  }
}
