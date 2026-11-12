import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop/tempo_customer/identity.dart';

void main() {
  test('Customer identity keeps Turkish names and normalizes whitespace', () {
    final result = customerIdentity('  ABC   Tekstil ', ' Muhammed  Yılmaz ');
    expect(result['company'], 'ABC Tekstil');
    expect(result['person'], 'Muhammed Yılmaz');
    expect(result['display'], 'ABC Tekstil — Muhammed Yılmaz');
  });
  test('Both customer fields are required', () {
    expect(() => customerIdentity('', 'Muhammed'), throwsFormatException);
    expect(() => customerIdentity('ABC', ''), throwsFormatException);
  });
  test('Names stay within the displayed and synchronized field limits', () {
    expect(() => customerIdentity(List.filled(81, 'A').join(), 'Muhammed'),
        throwsFormatException);
  });
}
