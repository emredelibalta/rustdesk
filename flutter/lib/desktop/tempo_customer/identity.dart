Map<String, String> customerIdentity(String taxId, String person) {
  person = person.trim().replaceAll(RegExp(r'\s+'), ' ');
  taxId = taxId.trim();
  if (person.isEmpty) {
    throw const FormatException('Ad Soyad zorunludur.');
  }
  if (person.length > 80 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(person)) {
    throw const FormatException('Ad Soyad en fazla 80 karakter olabilir.');
  }
  if (!RegExp(r'^[0-9]{1,11}$').hasMatch(taxId)) {
    throw const FormatException(
        'Firma VKN/TC zorunludur; yalnızca rakam ve en fazla 11 karakter olmalıdır.');
  }
  return {
    'taxId': taxId,
    'person': person,
    'display': '$person — VKN/TC: $taxId'
  };
}

String peerCustomerLabel(Map<String, dynamic> additions) {
  final person = additions['tempo_full_name'];
  final taxId = additions['tempo_tax_id'];
  if (person is! String || taxId is! String) return '';
  try {
    return customerIdentity(taxId, person)['display']!;
  } on FormatException {
    return '';
  }
}
