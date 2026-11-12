import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop/tempo/tools_catalog.dart';

void main() {
  test('Custom headings and Java/AKIS links round trip locally', () {
    final catalog = TempoToolsCatalog([
      'E-Uygulamalar',
      'Özel araçlar'
    ], [
      TempoTool('java', 'E-Uygulamalar', 'Java', 'x64',
          'https://example.com/java.exe'),
      TempoTool(
          'akis', 'Özel araçlar', 'AKİS', 'x64', 'https://example.com/akis.msi')
    ]);
    final copy = TempoToolsCatalog.read(catalog.encode());
    expect(copy.categories, catalog.categories);
    expect(copy.tools.last.name, 'AKİS');
    expect(() => TempoToolsCatalog(['A', 'A'], []), throwsFormatException);
    expect(() => TempoTool('1', 'A', 'Java', '', 'http://example.com/java.exe'),
        throwsFormatException);
  });
  test('Downloads quote URL data and never start an installer', () {
    final command = buildTempoToolDownload(TempoTool(
        '1', 'A', 'Java', '', 'https://example.com/java.exe?name=O%27Brien'));
    expect(command, contains('Get-AuthenticodeSignature'));
    expect(command, contains('MikroKurulum\\Araclar'));
    expect(command, isNot(contains('Start-Process')));
    expect(command, isNot(contains('EncodedCommand')));
  });
  test('Demo launch writes a transparent script without bypassing policy', () {
    final command =
        buildTempoDemoLaunch("Write-Host 'test'\nWrite-Host 'second'");
    expect(command, contains("Write-Host ''test''"));
    expect(command, contains('WriteAllLines'));
    expect(command, isNot(contains('EncodedCommand')));
    expect(command, isNot(contains('ExecutionPolicy')));
  });
}
