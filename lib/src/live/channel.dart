class Channel {
  final String name;
  final String url;
  final String? logo;
  final String group;
  final List<String> genres;
  final String? preferredEngine;
  const Channel({
    required this.name,
    required this.url,
    this.logo,
    this.group = 'Outros',
    this.genres = const [],
    this.preferredEngine,
  });
}
