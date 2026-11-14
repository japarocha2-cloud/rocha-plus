import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/c7_catalog_policy.dart';
import 'package:rocha_plus/src/live/c7_selected_catalog.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

void main() {
  testWidgets('selected Portuguese groups appear once and legacy live route resolves', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final data=jsonEncode({'schema':'rocha.c7.selection.v1','provenance':{'kind':'owner-selection','reference':'test fixture only','sourceSha256':List.filled(64,'a').join()},'channels':[
      {'id':'live','name':'Selecionado ao vivo','url':'https://example.test/live','group':'TV ao Vivo'},
      {'id':'alpha','name':'Alpha selecionado','url':'https://example.test/alpha','group':'TV ao Vivo'},
      {'id':'sports','name':'Selecionado esporte','url':'https://example.test/sports','group':'Esportes'},
    ],'removals':[]});
    final repo=ChannelRepository(c7Selection:C7SelectedCatalog(read:() async=>data,expectedSha256:sha256.convert(utf8.encode(data)).toString()));
    await tester.pumpWidget(MaterialApp(theme:RochaTheme.dark,home:LiveTvScreen(repository:repo,laboratoryFeatures:true,initialGroup:'TV aberta')));
    await tester.pumpAndSettle();
    expect(find.text('Selecionado ao vivo'),findsOneWidget);
    expect(find.text('Alpha selecionado'),findsOneWidget);
    expect(tester.getTopLeft(find.text('Selecionado ao vivo')).dx, lessThan(tester.getTopLeft(find.text('Alpha selecionado')).dx), reason:'No secondary alphabetical sorting of the selected catalog');
    expect(find.text('Sports'),findsNothing);
    expect(find.text('TV aberta'),findsNothing);
    expect(tester.takeException(),isNull);
  },skip:!C7CatalogPolicy.enabled);
}
