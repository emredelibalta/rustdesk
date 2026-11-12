import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop/tempo/catalog.dart';

Map<String, dynamic> record(
        {String version = '08b',
        String url = 'https://example.com/setup.exe',
        String status = 'Kullanıma hazır'}) =>
    {
      'id': 'test',
      'product': 'Fly',
      'major': 'V17',
      'version': version,
      'package': 'Client',
      'date': '2026-11-12',
      'status': status,
      'url': url,
      'note': 'Türkçe açıklama',
    };
void main() {
  test('Existing operator JSON imports and versions sort numerically', () {
    final text = '\ufeff${jsonEncode([record()])}';
    expect(readTempoCatalog(text).single.product, 'Fly');
    expect(compareTempoVersions('08b', '08c'), lessThan(0));
    expect(compareTempoVersions('09a', '10a'), lessThan(0));
    expect(() => readTempoCatalog(jsonEncode([record(), record()])),
        throwsFormatException);
    expect(() => TempoPackage(record(url: 'http://example.com/setup.exe')),
        throwsFormatException);
  });
  test(
      'Download command preserves Unicode and validated manifest without executing locally',
      () {
    final command = buildTempoDownloadCommand([TempoPackage(record())]);
    expect(command.length, lessThan(7800));
    final bytes = base64Decode(command.split(' ').last);
    final units = [
      for (var i = 0; i < bytes.length; i += 2) bytes[i] + 256 * bytes[i + 1]
    ];
    final bootstrap = String.fromCharCodes(units);
    final payload =
        RegExp("FromBase64String\\('([^']+)'\\)").firstMatch(bootstrap)![1]!;
    final ps = utf8.decode(gzip.decode(base64Decode(payload)));
    expect(ps, contains('Kurulum başlatılmadı'));
    expect(ps, contains('Get-AuthenticodeSignature'));
    expect(ps, isNot(contains('Read-Host')));
    final manifest =
        RegExp("FromBase64String\\('([^']+)'\\)").firstMatch(ps)![1]!;
    expect(
        (jsonDecode(utf8.decode(base64Decode(manifest))) as List)
            .single['product'],
        'Fly');
    expect(ps, isNot(contains('Start-Process')));
  });
  test('Archive and mixed product/version selections never produce commands',
      () {
    expect(() => buildTempoDownloadCommand([]), throwsFormatException);
    expect(
        () =>
            buildTempoDownloadCommand([TempoPackage(record(status: 'Arşiv'))]),
        throwsFormatException);
    expect(
        () => buildTempoDownloadCommand(
            [TempoPackage(record()), TempoPackage(record(version: '09a'))]),
        throwsFormatException);
  });
}
