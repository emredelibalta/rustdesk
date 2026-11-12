import 'dart:convert';

class TempoTool {
  final String id, category, name, version, url;
  TempoTool(this.id, this.category, this.name, this.version, this.url) {
    final uri = Uri.tryParse(url);
    if (id.isEmpty ||
        category.trim().isEmpty ||
        name.trim().isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        url.contains(RegExp(r'[\r\n]')) ||
        uri.pathSegments.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_. -]+\.(exe|msi|zip|jar)$', caseSensitive: false)
            .hasMatch(uri.pathSegments.last)) {
      throw const FormatException(
          'Başlık, program adı ve tam HTTPS EXE/MSI/ZIP/JAR bağlantısı gerekli.');
    }
  }
  Map<String, String> toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'version': version,
        'url': url
      };
}

class TempoToolsCatalog {
  final List<String> categories;
  final List<TempoTool> tools;
  TempoToolsCatalog(this.categories, this.tools) {
    if (categories.any((v) => v.trim().isEmpty) ||
        categories.toSet().length != categories.length ||
        tools.map((p) => p.id).toSet().length != tools.length ||
        tools.any((p) => !categories.contains(p.category))) {
      throw const FormatException(
          'Başlıklar/kayıtlar yineleniyor veya paket başlığı bulunamadı.');
    }
  }
  factory TempoToolsCatalog.empty() => TempoToolsCatalog(
      ['E-Uygulamalar', 'Mikro Demo Paketleri', 'Yardımcı Araçlar'], []);
  factory TempoToolsCatalog.read(String text) {
    final value = jsonDecode(text.replaceFirst('\ufeff', '')) as Map;
    return TempoToolsCatalog(
        List<String>.from(value['categories']),
        (value['tools'] as List)
            .map((p) => TempoTool(
                p['id'], p['category'], p['name'], p['version'], p['url']))
            .toList());
  }
  String encode() => const JsonEncoder.withIndent('  ').convert({
        'categories': categories,
        'tools': tools.map((p) => p.toJson()).toList()
      });
}

String tempoPsLiteral(String value) => "'${value.replaceAll("'", "''")}'";

String buildTempoToolDownload(TempoTool tool) {
  final filename = Uri.parse(tool.url).pathSegments.last;
  return "& { \$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; "
      "\$d=Join-Path ([Environment]::GetFolderPath('Desktop')) 'MikroKurulum\\Araclar'; New-Item -ItemType Directory -Force -Path \$d|Out-Null; "
      "\$f=Join-Path \$d ${tempoPsLiteral(filename)}; \$p=\$f+'.part'; try { Invoke-WebRequest -UseBasicParsing -Uri ${tempoPsLiteral(tool.url)} -OutFile \$p; "
      "if([IO.Path]::GetExtension(\$f) -in @('.exe','.msi')){ \$s=Get-AuthenticodeSignature -LiteralPath \$p; if(\$s.Status -ne 'Valid'){throw 'Gecerli uygulama imzasi yok. Dosya tamamlanmadi.'} } else { \$stream=[IO.File]::OpenRead(\$p); try{if(\$stream.ReadByte() -ne 80 -or \$stream.ReadByte() -ne 75){throw 'ZIP/JAR dosya basligi dogrulanamadi.'}}finally{\$stream.Dispose()} }; Move-Item -LiteralPath \$p -Destination \$f -Force; "
      "Write-Host ('Indirme tamamlandi: '+\$f); Write-Host 'Kurulum otomatik baslatilmadi.' } catch { Remove-Item -LiteralPath \$p -Force -ErrorAction SilentlyContinue; Write-Error \$_ } }";
}

String buildTempoDemoLaunch(String script) {
  final lines =
      const LineSplitter().convert(script).map(tempoPsLiteral).join(',');
  return "& { \$p=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TempoDestek\\Demo\\TempoDemo.ps1'; "
      "New-Item -ItemType Directory -Force -Path (Split-Path \$p)|Out-Null; "
      "[IO.File]::WriteAllLines(\$p,@($lines),(New-Object Text.UTF8Encoding(\$true))); "
      "Write-Host ('Demo paneli: '+\$p); Start-Process (Join-Path \$env:WINDIR 'System32\\WindowsPowerShell\\v1.0\\powershell.exe') -ArgumentList @('-NoProfile','-STA','-File', ('\"'+\$p+'\"')) }";
}
