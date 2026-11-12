import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop/tempo/demo_inventory.dart';
import '../lib/desktop/tempo/tools_catalog.dart';

void main() {
  test('Remote inventory survives terminal chunks and displays target identity', () {
    final decoder = TempoInventoryDecoder('123');
    final payload = base64Encode(utf8.encode(jsonEncode({
      'Computer': 'MUSTERI-SRV', 'SystemLocaleDisplay': 'Türkçe (Türkiye)',
      'SqlInstances': [{'Name': 'SQLEXPRESS', 'Version': '15.0'}], 'SSMS': []
    })));
    expect(decoder.add('echo\r\nTDI|other|$payload;'), isNull);
    expect(decoder.add('\u001b[32mTDI|123|${payload.substring(0, 20)}'), isNull);
    final result = decoder.add('${payload.substring(20)};\u001b[0m');
    final report = tempoInventoryText(result!);
    expect(report, contains('MUSTERI-SRV'));
    expect(report, contains('SQLEXPRESS'));
    expect(report, contains('Türkçe (Türkiye)'));
    expect(report, contains('Kurulu kayıt bulunamadı.'));
  });
  test('Report launch waits for read-only output instead of opening setup GUI', () {
    final command = buildTempoDemoLaunch('param()\nWrite-Host test', reportJob: '123');
    expect(command, contains('-ReportOnly -ReportJob 123'));
    expect(command, isNot(contains('Start-Process')));
    expect(command, isNot(contains('ExecutionPolicy')));
    expect(() => buildTempoDemoLaunch('', reportJob: 'x;bad'), throwsFormatException);
  });
}
