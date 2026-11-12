import 'dart:io';
import 'catalog.dart';

List<String> tempoInstallerNames(List<TempoPackage> records, String product) {
  final prefix = product == 'Müşavir' ? 'Musavir' : product;
  final names = <String, String>{
    'Server': '${prefix}_v17xx_Server_Setupx064.exe',
    'Client': '${prefix}_v17xx_Client_Setupx064.exe',
    'e-Defter': '${prefix}_v17xx_eDefter_Setupx064.exe',
    'Partner': 'v17xx_Partner_Setupx064.exe',
  };
  final saved = records
      .where((p) => p.product == product && p.major == 'V17')
      .toList()
    ..sort((a, b) => compareTempoVersions(a.version, b.version));
  for (final p in saved) {
    if (names.containsKey(p.package))
      names[p.package] = Uri.parse(p.url).pathSegments.last;
  }
  return names.values.toList();
}

List<TempoPackage> tempoBulkPackages(List<TempoPackage> records, String product,
    String version, List<String> files) {
  version = version.trim().toLowerCase();
  if (!['Fly', 'Jump', 'Run', 'Müşavir'].contains(product) ||
      !RegExp(r'^\d{1,4}[a-z]{0,2}$').hasMatch(version)) {
    throw const FormatException(
        'Ürün ve güncelleme sürümünü kontrol edin. Örnek: 08b.');
  }
  final result = <TempoPackage>[];
  final kinds = <String>{};
  for (final raw in files) {
    final file = raw.trim();
    if (file.isEmpty) continue;
    if (!RegExp(r'^[a-zA-Z0-9_. -]+\.(exe|msi)$', caseSensitive: false)
        .hasMatch(file)) {
      throw const FormatException(
          'Her satıra yalnızca EXE/MSI dosya adı yazın; tam bağlantı otomatik oluşturulur.');
    }
    final lower = file.toLowerCase();
    final kind = lower.contains('_server_')
        ? 'Server'
        : lower.contains('_client_')
            ? 'Client'
            : lower.contains('_edefter_')
                ? 'e-Defter'
                : lower.contains('_partner_')
                    ? 'Partner'
                    : 'Diğer';
    if (!kinds.add(kind))
      throw FormatException('$kind için birden fazla dosya yazıldı.');
    final url = Uri(
        scheme: 'https',
        host: 'cdn-mikro.atros.com.tr',
        pathSegments: ['mikro', 'v17', version, file]).toString();
    final old = records
        .where((p) =>
            p.product == product &&
            p.major == 'V17' &&
            p.version.toLowerCase() == version &&
            p.package == kind)
        .toList();
    result.add(TempoPackage({
      'id': old.isEmpty
          ? 'bulk-${DateTime.now().microsecondsSinceEpoch}-$kind'
          : old.first.id,
      'product': product,
      'major': 'V17',
      'version': version,
      'package': kind,
      'date': old.isEmpty ? '' : old.first.date,
      'status': old.isEmpty ? 'Test ediliyor' : old.first.status,
      'note': old.isEmpty
          ? 'Bağlantı şablondan oluşturuldu; erişilebilirlik kontrol edildi.'
          : old.first.note,
      'url': url,
    }));
  }
  if (result.isEmpty)
    throw const FormatException('En az bir kurulum dosyası seçin.');
  return result;
}

Future<String?> checkTempoInstallerLink(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 && response.statusCode != 206)
      return 'HTTP ${response.statusCode}';
    if (response.redirects
        .any((r) => r.location.hasScheme && r.location.scheme != 'https'))
      return 'HTTPS dışına yönlendirme';
    final bytes = await response
        .expand((b) => b)
        .take(2)
        .toList()
        .timeout(const Duration(seconds: 10));
    final msi = Uri.parse(url).path.toLowerCase().endsWith('.msi');
    if (bytes.length != 2 ||
        (msi
            ? bytes[0] != 0xcf || bytes[1] != 0xd0
            : bytes[0] != 0x4d || bytes[1] != 0x5a))
      return 'Kurulum dosyası başlığı bulunamadı';
    return null;
  } catch (e) {
    return 'Bağlantı doğrulanamadı: $e';
  } finally {
    client.close(force: true);
  }
}
