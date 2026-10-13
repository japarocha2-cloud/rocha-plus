import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/widgets/channel_cover.dart';

void main() {
  testWidgets('missing logo renders an offline cover with the channel name', (tester) async {
    const channel = Channel(
      name: 'TV Exemplo (1080p) [Not 24/7]',
      url: 'https://example.com/live.m3u8',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(width: 260, height: 160,
        child: ChannelCover(channel: channel))),
    ));
    expect(find.text('TV Exemplo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long channel names fit inside compact TV cards', (tester) async {
    const channel = Channel(
      name: 'Canal Regional de Noticias e Entretenimento Muito Longo (720p)',
      url: 'https://example.com/regional.m3u8',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(width: 180, height: 120,
        child: ChannelCover(channel: channel))),
    ));
    expect(find.byType(RichText), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
