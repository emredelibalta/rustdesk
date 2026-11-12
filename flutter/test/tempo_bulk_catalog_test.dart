import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop/tempo/bulk_catalog.dart';

void main() {
  test('Version and filenames generate exact CDN URLs for bulk product updates',
      () {
    final result = tempoBulkPackages(
        [],
        'Jump',
        ' 07D ',
        [
          'Jump_v17xx_Server_Setupx064.exe',
          'Jump_v17xx_Client_Setupx064.exe',
          'v17xx_Partner_Setupx064.exe'
        ]);
    expect(result.length, 3);
    expect(result.last.url,
        'https://cdn-mikro.atros.com.tr/mikro/v17/07d/v17xx_Partner_Setupx064.exe');
    expect(result.every((p) => p.product == 'Jump'), isTrue);
    final updated = tempoBulkPackages(
        result, 'Jump', '07d', ['v17xx_Partner_Setupx064.exe']);
    expect(updated.single.id, result.last.id);
  });
  test('Only filenames are accepted and duplicate package types are refused',
      () {
    expect(() => tempoBulkPackages([], 'Fly', '../../bad', ['x.exe']),
        throwsFormatException);
    expect(
        () =>
            tempoBulkPackages([], 'Fly', '08b', ['https://example.com/x.exe']),
        throwsFormatException);
    expect(() => tempoBulkPackages([], 'Fly', '08b', ['x.exe', 'y.exe']),
        throwsFormatException);
  });
}
