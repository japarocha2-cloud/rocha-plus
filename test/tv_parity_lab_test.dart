import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/tv_parity_lab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('shared Roku Android TV sample has twelve distinct HTTPS streams', () async {
    final channels = await TvParityLab.load();
    expect(channels.length, 12);
    expect(channels.map((c) => c.url).toSet().length, 12);
    expect(channels.every((c) => c.url.startsWith('https://')), true);
  });
}
