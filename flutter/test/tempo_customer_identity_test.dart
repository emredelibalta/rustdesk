import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop/tempo_customer/identity.dart';

void main() {
  test('Required identity preserves Turkish names and leading zeroes', () {
    final result = customerIdentity('00123456789', ' Muhammet  Kapancı ');
    expect(result['person'], 'Muhammet Kapancı');
    expect(result['taxId'], '00123456789');
    expect(result['display'], 'Muhammet Kapancı — VKN/TC: 00123456789');
  });
  test('Empty names and empty, nonnumeric or long tax IDs are refused', () {
    expect(() => customerIdentity('123', ' '), throwsFormatException);
    for (final taxId in ['', '123456789012', '12a34', '1.5', '１２３']) {
      expect(() => customerIdentity(taxId, 'Muhammet'), throwsFormatException);
    }
    expect(() => customerIdentity('123', List.filled(81, 'A').join()),
        throwsFormatException);
  });
  test('Operator shows identity only for supported valid metadata', () {
    expect(
        peerCustomerLabel(
            {'tempo_full_name': 'Ali', 'tempo_tax_id': '0123456789'}),
        'Ali — VKN/TC: 0123456789');
    expect(peerCustomerLabel({}), '');
    expect(
        peerCustomerLabel({'tempo_full_name': 123, 'tempo_tax_id': '123'}), '');
  });
}
