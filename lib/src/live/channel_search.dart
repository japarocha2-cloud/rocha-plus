import 'channel.dart';

/// Search keeps quality labels and accepts Portuguese accents/spacing.
String channelSearchText(String value) {
  var text = value.toLowerCase();
  const accents = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
  };
  accents.forEach((accent, plain) => text = text.replaceAll(accent, plain));
  return text.replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool channelMatchesSearch(Channel channel, String query) {
  final search = channelSearchText(query);
  return search.isEmpty ||
      channelSearchText(channel.name).contains(search) ||
      channelSearchText(channel.group).contains(search);
}
