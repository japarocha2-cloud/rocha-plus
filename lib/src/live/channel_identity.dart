String channelIdentity(String name) {
  var value = name.trim().toLowerCase()
      .replaceAll(RegExp(r'\s*\(\d+p\)'), '')
      .replaceAll(RegExp(r'\s*\[not 24/7\]'), '');
  const accents = {'á':'a','à':'a','ã':'a','â':'a','é':'e','ê':'e',
    'í':'i','ó':'o','ô':'o','õ':'o','ú':'u','ç':'c'};
  accents.forEach((key, replacement) => value = value.replaceAll(key, replacement));
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
