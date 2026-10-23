import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/widgets/rocha_channel_card.dart';

void main() {
  const channel = Channel(
    name: 'Canal de teste',
    url: 'https://example.com/live.m3u8',
    group: 'TV aberta',
  );

  testWidgets('card without a logo displays a safe fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 230,
        height: 300,
        child: RochaChannelCard(
          channel: channel,
          onOpen: () {},
          onFavorite: () {},
        ),
      )),
    ));
    expect(find.byIcon(Icons.live_tv_outlined), findsOneWidget);
    expect(find.text('Canal de teste'), findsOneWidget);
  });

  testWidgets('favorite action is wired to the heart control', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 230,
        height: 300,
        child: RochaChannelCard(
          channel: channel,
          favorite: true,
          onOpen: () {},
          onFavorite: () => tapped++,
        ),
      )),
    ));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await tester.tap(find.byTooltip('Remover dos favoritos'));
    expect(tapped, 1);
  });
}
