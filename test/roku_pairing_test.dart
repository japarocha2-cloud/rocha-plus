import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/tv/roku_pairing_service.dart';
void main() {
  test('approval includes verified identity and normalized TV code', () async {
    final service = RokuPairingService(endpoint: 'https://example.com/pair',
      tokenProvider: () async => 'fixture-token', client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer fixture-token');
        expect(request.body, contains('ABCDEFGH'));
        return http.Response('{"status":"approved"}',200);
      }));
    await service.approve('abcd-efgh');
  });
  test('invalid code is rejected before requesting identity or network', () async {
    final service = RokuPairingService(endpoint: 'https://example.com/pair',
      tokenProvider: () async => throw StateError('Must not run'));
    await expectLater(service.approve('guess'), throwsA(isA<RokuPairingFailure>()));
  });
  test('insecure endpoint and absent account fail closed', () async {
    final insecure = RokuPairingService(endpoint: 'http://example.com/pair', tokenProvider: () async => 'fixture-token');
    await expectLater(insecure.approve('ABCDEFGH'),throwsA(isA<RokuPairingFailure>()));
    final anonymous = RokuPairingService(endpoint: 'https://example.com/pair',tokenProvider: () async => null);
    await expectLater(anonymous.approve('ABCDEFGH'),throwsA(isA<RokuPairingFailure>()));
  });
  test('expired and malformed server approvals do not appear successful', () async {
    for (final response in [http.Response('{"error":"expired"}',410),http.Response('broken',200)]) {
      final service = RokuPairingService(endpoint: 'https://example.com/pair',tokenProvider: () async => 'fixture-token',
        client: MockClient((_) async => response));
      await expectLater(service.approve('ABCDEFGH'),throwsA(isA<RokuPairingFailure>()));
    }
  });
}
