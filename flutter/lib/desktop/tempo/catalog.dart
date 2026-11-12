import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TempoPackage {
  final String id, product, major, version, package, date, status, url, note;
  TempoPackage(Map<String, dynamic> m)
      : id = m['id'] as String,
        product = m['product'] as String,
        major = m['major'] as String,
        version = m['version'] as String,
        package = m['package'] as String,
        date = m['date'] as String,
        status = m['status'] as String,
        url = m['url'] as String,
        note = m['note'] as String? ?? '' {
    if (!['Fly', 'Jump', 'Run', 'Müşavir'].contains(product) ||
        !RegExp(r'^V\d{1,3}$').hasMatch(major) ||
        !RegExp(r'^\d{1,4}[a-zA-Z]{0,2}$').hasMatch(version) ||
        !['Server', 'Client', 'e-Defter', 'Partner', 'Diğer']
            .contains(package) ||
        !['Test ediliyor', 'Kullanıma hazır', 'Arşiv'].contains(status)) {
      throw const FormatException('Ürün, sürüm, paket veya durum geçersiz.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        url.contains('\n') ||
        url.contains('\r') ||
        uri.pathSegments.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_. -]+\.(exe|msi)$', caseSensitive: false)
            .hasMatch(uri.pathSegments.last)) {
      throw const FormatException('Tam HTTPS EXE/MSI bağlantısı girin.');
    }
    if (url.length > 2048) throw const FormatException('Bağlantı çok uzun.');
  }
  Map<String, String> toJson() => {
        'id': id,
        'product': product,
        'major': major,
        'version': version,
        'package': package,
        'date': date,
        'status': status,
        'url': url,
        'note': note
      };
  String get key => '$product|$major|${version.toLowerCase()}|$package';
  String get label => '$product $major / $version / $package';
}

List<TempoPackage> readTempoCatalog(String text) {
  final decoded = jsonDecode(text.replaceFirst('\ufeff', ''));
  if (decoded is! List)
    throw const FormatException('Kütüphane JSON listesi olmalı.');
  final result = decoded
      .map((e) => TempoPackage(Map<String, dynamic>.from(e as Map)))
      .toList();
  final keys = <String>{};
  final ids = <String>{};
  for (final r in result) {
    if (!keys.add(r.key) || r.id.isEmpty || !ids.add(r.id)) {
      throw const FormatException('Yinelenen kayıt veya boş kimlik.');
    }
  }
  return result;
}

List<TempoPackage> withTempoPartnerPackages(List<TempoPackage> records) {
  final result = [...records];
  for (final product in ['Fly', 'Jump', 'Run', 'Müşavir']) {
    final partner = TempoPackage({
      'id': 'tempo-partner-v17-07d-$product',
      'product': product,
      'major': 'V17',
      'version': '07d',
      'package': 'Partner',
      'date': '',
      'status': 'Test ediliyor',
      'url':
          'https://cdn-mikro.atros.com.tr/mikro/v17/07d/v17xx_Partner_Setupx064.exe',
      'note': 'Kullanıcının sağladığı ortak Partner bağlantısı (07d).',
    });
    if (!result.any((p) => p.key == partner.key || p.id == partner.id)) {
      result.add(partner);
    }
  }
  return result;
}

int compareTempoVersions(String a, String b) {
  final re = RegExp(r'^(\d+)([a-zA-Z]*)$');
  final x = re.firstMatch(a)!, y = re.firstMatch(b)!;
  final n = int.parse(x[1]!).compareTo(int.parse(y[1]!));
  return n != 0 ? n : x[2]!.toLowerCase().compareTo(y[2]!.toLowerCase());
}

String buildTempoDownloadCommand(List<TempoPackage> selected, {String? jobId}) {
  jobId ??= DateTime.now().microsecondsSinceEpoch.toString();
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,40}$').hasMatch(jobId))
    throw const FormatException('Geçersiz indirme kimliği.');
  if (selected.isEmpty) throw const FormatException('Paket seçin.');
  final groups =
      selected.map((p) => '${p.product}|${p.major}|${p.version}').toSet();
  if (groups.length != 1 || selected.any((p) => p.status == 'Arşiv')) {
    throw const FormatException(
        'Aynı ürün ve sürümü seçin. Arşiv indirilemez.');
  }
  final manifest = base64Encode(utf8.encode(jsonEncode(selected
      .map((p) => {
            'product': p.product,
            'major': p.major,
            'version': p.version,
            'url': p.url
          })
      .toList())));
  final script = tempoDownloadScript
      .replaceAll('__MANIFEST__', manifest)
      .replaceAll('__JOB_ID__', jobId);
  // Compact the script so even a cmd.exe fallback shell stays below its input limit.
  final compressed = base64Encode(gzip.encode(utf8.encode(script)));
  final bootstrap =
      "\$m=New-Object IO.MemoryStream(,[Convert]::FromBase64String('$compressed'));"
      "\$g=New-Object IO.Compression.GZipStream(\$m,[IO.Compression.CompressionMode]::Decompress);"
      "\$r=New-Object IO.StreamReader(\$g,[Text.Encoding]::UTF8);"
      "try{& ([scriptblock]::Create(\$r.ReadToEnd()))}finally{\$r.Dispose();\$g.Dispose();\$m.Dispose()}";
  final bytes = ByteData(bootstrap.length * 2);
  for (var i = 0; i < bootstrap.length; i++) {
    bytes.setUint16(i * 2, bootstrap.codeUnitAt(i), Endian.little);
  }
  final command =
      'powershell.exe -NoProfile -EncodedCommand ${base64Encode(bytes.buffer.asUint8List())}';
  if (command.length > 7800)
    throw const FormatException('Komut çok uzun; daha az paket seçin.');
  return command;
}

const tempoDownloadScript = r'''
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$parsed=ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__MANIFEST__')))
$items=@($parsed)
$root=[Environment]::GetFolderPath('Desktop')
if([string]::IsNullOrWhiteSpace($root)){throw 'Masaüstü klasörü bulunamadı.'}
Write-Host ('Hedef: '+$env:COMPUTERNAME+' / '+[Environment]::UserName)
$failed=0;$ordinal=0
function Write-TempoProgress($index,$count,$received,$total,$phase){Write-Host ('TDP|__JOB_ID__|'+$index+'|'+$count+'|'+$received+'|'+$total+'|'+$phase+';')}
foreach($r in $items){
 $ordinal++
 if($r.product -notin @('Fly','Jump','Run','Müşavir') -or $r.major -notmatch '^V\d{1,3}$' -or $r.version -notmatch '^\d{1,4}[a-zA-Z]{0,2}$'){throw 'Geçersiz paket.'}
 $u=[Uri]$r.url
 if($u.Scheme -ne 'https' -or $u.UserInfo -ne ''){throw 'HTTPS gerekli.'}
 $name=[Uri]::UnescapeDataString([IO.Path]::GetFileName($u.AbsolutePath))
 if($name -notmatch '^[a-zA-Z0-9_. -]+\.(exe|msi)$'){throw 'Geçersiz dosya adı.'}
 $dir=Join-Path $root ('MikroKurulum\'+$r.version+'\'+$r.product)
 New-Item -ItemType Directory -Force -Path $dir | Out-Null
 $log=Join-Path $dir 'indirme.log'
 $out=Join-Path $dir $name
 $working=Join-Path $dir ('.indirme-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Force -Path $working | Out-Null
 (Get-Item -LiteralPath $working).Attributes = (Get-Item -LiteralPath $working).Attributes -bor [IO.FileAttributes]::Hidden
 $part=Join-Path $working $name
 $ok=$false
 try{
 for($attempt=1;$attempt -le 3;$attempt++){
  try{
   Write-Host ('İndiriliyor: '+$name+' / Deneme '+$attempt)
   $request=[Net.HttpWebRequest]::Create($r.url);$request.Timeout=30000;$request.ReadWriteTimeout=30000
   $response=$null;$inputStream=$null;$outputStream=$null
   try{
    $response=$request.GetResponse()
    if($response.ResponseUri.Scheme -ne 'https'){throw 'Indirme HTTPS disina yonlendirildi.'}
    $total=[long]$response.ContentLength;$received=[long]0
    Write-TempoProgress $ordinal $items.Count $received $total 'D'
    $inputStream=$response.GetResponseStream();$outputStream=[IO.File]::Create($part)
    $buffer=New-Object byte[] 65536;$last=[DateTime]::UtcNow;$started=$last
    while(($read=$inputStream.Read($buffer,0,$buffer.Length)) -gt 0){
     if(([DateTime]::UtcNow-$started).TotalSeconds -gt 1800){throw 'Indirme suresi asildi.'}
     $outputStream.Write($buffer,0,$read);$received+=$read
     if(([DateTime]::UtcNow-$last).TotalMilliseconds -ge 500){Write-TempoProgress $ordinal $items.Count $received $total 'D';$last=[DateTime]::UtcNow}
    }
    if($total -ge 0 -and $received -ne $total){throw 'Dosya boyutu eksik.'}
   }finally{if($outputStream){$outputStream.Dispose()};if($inputStream){$inputStream.Dispose()};if($response){$response.Close()}}
   Write-TempoProgress $ordinal $items.Count $received $total 'V' 
   $sig=Get-AuthenticodeSignature -LiteralPath $part
   if($sig.Status -ne 'Valid'){throw ('Dijital imza doğrulanamadı: '+$sig.Status)}
   $hash=(Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash
   Move-Item -LiteralPath $part -Destination $out -Force
   ((Get-Date -Format s)+' | BAŞARILI | '+$name+' | '+$hash+' | '+$sig.SignerCertificate.Subject) | Add-Content -LiteralPath $log -Encoding UTF8
   Write-Host ('Tamamlandı: '+$out) -ForegroundColor Green
   Write-TempoProgress $ordinal $items.Count $received $total 'C'
   $ok=$true;break
  }catch{
   ((Get-Date -Format s)+' | HATA | '+$name+' | '+$_.Exception.Message) | Add-Content -LiteralPath $log -Encoding UTF8
   Write-Warning $_.Exception.Message
   Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
  }
 }
 }finally{Remove-Item -LiteralPath $working -Recurse -Force -ErrorAction SilentlyContinue}
 if(-not $ok){$failed++;Write-TempoProgress $ordinal $items.Count 0 0 'E'}
}
if($failed -eq 0){Write-TempoProgress 0 $items.Count 0 0 'A'}else{Write-TempoProgress 0 $items.Count 0 0 'F'}
Write-Host ('İşlem bitti. Başarısız paket: '+$failed)
Write-Host 'Kurulum başlatılmadı. Ayrıntılar indirme.log dosyasında.'
''';
