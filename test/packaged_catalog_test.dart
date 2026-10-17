import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the actual packaged catalogue loads without a network fallback', () async {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
    final channels = await ChannelRepository().loadBrazilPublicDirectory();
    expect(channels, isNotEmpty);
    expect(channels.where((c) => c.group == 'Notícias'), hasLength(5));
    expect(channels.where((c) => c.name.startsWith('SBC TV')), hasLength(1));
    expect(channels.where((c) => c.group == 'TV aberta').length, greaterThan(50));
  });
}
