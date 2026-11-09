class Channel {
  final String name;
  final String url;
  final String? logo;
  final String group;
  final List<String> genres;
  final String? preferredEngine;
  /// Approved alternatives, in the documented order; url remains preferred.
  final List<String> alternateUrls;
  const Channel({
    required this.name,
    required this.url,
    this.logo,
    this.group = 'Outros',
    this.genres = const [],
    this.preferredEngine,
    this.alternateUrls = const [],
  });
}
