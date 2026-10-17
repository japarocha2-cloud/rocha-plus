import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all four mobile class covers are bundled and decode as WebP', () async {
    const covers = [
      'branding/categories/tv_ao_vivo.webp',
      'branding/categories/esportes.webp',
      'branding/categories/infantil.webp',
      'branding/categories/noticias.webp',
    ];
    for (final asset in covers) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(1000), reason: asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThanOrEqualTo(120), reason: asset);
      expect(frame.image.height, greaterThanOrEqualTo(68), reason: asset);
      frame.image.dispose();
      codec.dispose();
    }
  });
  test('approved illustrations retain their original landscape resolution', () async {
    for (final name in ['tv_ao_vivo', 'esportes', 'infantil', 'noticias']) {
      final data = await rootBundle.load('branding/categories/mobile/$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1672);
      expect(frame.image.height, 941);
      expect(frame.image.width / frame.image.height, closeTo(16 / 9, .003));
      frame.image.dispose();
      codec.dispose();
    }
  });

}
