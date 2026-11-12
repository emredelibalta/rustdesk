import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Public intake key selects a company; it is not an administrator credential.
class TempoCrmQueue {
  static final instance = TempoCrmQueue();
  static const endpoint = String.fromEnvironment('TEMPO_CRM_INTAKE',
      defaultValue: 'https://crm.tempobilisim.com/api/remote-support/intake/d3eff7ee-bd0f-4f97-bd52-4ba1e03c9cf7');
  Map<String, dynamic>? _request;
  bool accepted = false;
  String _hex(int length) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      throw const FormatException('CRM HTTPS adresi geçersiz.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw HttpException('CRM yanıtı: ${response.statusCode}. Talebinizi yeniden deneyin.');
      }
      final text = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 12));
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> submit(String name, String tax, String topic, String device) async {
    if (_request == null) {
      final h = _hex(16);
      _request = {
        'requestId': '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}',
        'requestSecret': _hex(32), 'contactName': name, 'taxNumber': tax,
        'topic': topic, 'deviceId': device, 'supportsHeartbeat': true,
      };
    }
    final result = await _post(endpoint, _request!);
    if (result['requestId'] != _request!['requestId']) {
      throw const FormatException('CRM talep yanıtı doğrulanamadı.');
    }
    accepted = true;
  }

  Future<bool> pulse(bool connected, {bool close = false}) async {
    final request = _request;
    if (request == null) return false;
    final response = await _post(endpoint.replaceFirst('/intake/', '/pulse/'), {
      'requestId': request['requestId'], 'requestSecret': request['requestSecret'],
      'connected': connected, 'close': close,
    });
    final active = response['status'] == 'Waiting' || response['status'] == 'Active';
    if (close || !active) { _request = null; accepted = false; }
    return active;
  }

  Future<void> cancel() async {
    try { await pulse(false, close: true); }
    finally { _request = null; accepted = false; }
  }
}
