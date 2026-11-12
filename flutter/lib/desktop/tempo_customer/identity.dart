Map<String, String> customerIdentity(String company, String person) {
  company = company.trim().replaceAll(RegExp(r'\s+'), ' ');
  person = person.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (company.length < 2 || person.length < 2) {
    throw const FormatException(
        'Firma adı ve ad-soyad en az iki karakter olmalı.');
  }
  if (company.length > 80 || person.length > 80) {
    throw const FormatException('Her alan en fazla 80 karakter olabilir.');
  }
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(company + person)) {
    throw const FormatException('Geçersiz karakter.');
  }
  return {
    'company': company,
    'person': person,
    'display': '$company — $person'
  };
}
