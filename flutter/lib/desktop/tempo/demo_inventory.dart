import 'dart:convert';

class TempoInventoryDecoder {
  final String job;
  String _buffer = '';
  TempoInventoryDecoder(this.job);

  Map<String, dynamic>? add(String chunk) {
    _buffer += chunk;
    _buffer = _buffer.replaceAll(RegExp(r'\x1b\[[0-?]*[ -/]*[@-~]'), '');
    if (_buffer.length > 300000)
      _buffer = _buffer.substring(_buffer.length - 300000);
    final match =
        RegExp('TDI\\|${RegExp.escape(job)}\\|([A-Za-z0-9+/=\\r\\n]+);')
            .firstMatch(_buffer);
    if (match == null) return null;
    _buffer = _buffer.substring(match.end);
    try {
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(
          base64Decode(match[1]!.replaceAll(RegExp(r'\s'), '')))) as Map);
    } catch (_) {
      return null;
    }
  }
}

String tempoInventoryText(Map<String, dynamic> i) {
  String value(String key) => i[key]?.toString() ?? 'Okunamadı';
  String programs(String key) {
    final rows = i[key];
    if (rows is! List || rows.isEmpty) return 'Kurulu kayıt bulunamadı.';
    return rows
        .map((p) => p is Map
            ? p.entries.map((e) => '${e.key}: ${e.value ?? "—"}').join(' | ')
            : '$p')
        .join('\n');
  }

  return '''BİLGİSAYAR: ${value('Computer')}
Windows: ${value('Windows')} / ${value('WindowsVersion')} / ${value('Architecture')}
Konsol kullanıcısı: ${value('DesktopUser')}
Rapor hesabı: ${value('ReportUser')} / Yönetici: ${value('Admin')}

SQL INSTANCE / SÜRÜM / SERVİS
${programs('SqlInstances')}

SQL SERVER MANAGEMENT STUDIO
${programs('SSMS')}

DİL VE BÖLGE (raporu çalıştıran hesap)
Ülke: ${value('Country')}
Bölgesel biçim: ${value('CultureDisplay')} [${value('Culture')}]
Arayüz dili: ${value('UILanguage')}
Kullanıcı dilleri: ${value('UserLanguages')}
Unicode olmayan programlar: ${value('SystemLocaleDisplay')} [${value('SystemLocale')}]
ANSI kod sayfası: ${value('AnsiCodePage')} (65001: UTF-8)
Kısa tarih: ${value('ShortDate')} / Uzun tarih: ${value('LongDate')}
Kısa saat: ${value('ShortTime')} / Uzun saat: ${value('LongTime')}
Haftanın ilk günü: ${value('FirstDay')}
Ondalık / binlik / liste ayracı: ${value('DecimalSeparator')} / ${value('GroupSeparator')} / ${value('ListSeparator')}
Saat dilimi: ${value('TimeZone')}
Yeniden başlatma bekliyor: ${value('PendingRestart')}

JAVA / AKİS
${programs('JavaAkis')}

Bu kontrol ayar değiştirmez ve SQL kurulumu başlatmaz.''';
}
