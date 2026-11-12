import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../common.dart';
import '../../common/formatter/id_formatter.dart' show formatID;
import '../../models/platform_model.dart';
import '../pages/desktop_setting_page.dart';
import '../pages/desktop_tab_page.dart';
import 'identity.dart';
import 'lifecycle.dart';
import 'crm_queue.dart';

class TempoCustomerPage extends StatefulWidget {
  const TempoCustomerPage({super.key});
  @override
  State<TempoCustomerPage> createState() => _TempoCustomerPageState();
}

class _TempoCustomerPageState extends State<TempoCustomerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _taxId = TextEditingController();
  final _person = TextEditingController();
  final _topic = TextEditingController();
  Timer? _crmTimer;
  bool _crmBusy = false;
  String _crmStatus = "";
  bool _ready = false, _busy = true;
  String _error = '', _deviceId = '';
  Timer? _idTimer;
  bool _readingId = false;

  @override
  void initState() {
    super.initState();
    _taxId.text = bind.mainGetLocalOption(key: 'tempo-tax-id');
    _person.text = bind.mainGetLocalOption(key: 'tempo-person');
    _prepare();
    _refreshId();
    _idTimer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshId());
  }

  Future<void> _refreshId() async {
    if (_readingId) return;
    _readingId = true;
    try {
      final id = (await bind.mainGetMyId()).trim();
      if (mounted && id != _deviceId) setState(() => _deviceId = id);
    } catch (e) {
      debugPrint('TempoDestek ID refresh: $e');
    } finally {
      _readingId = false;
    }
  }

  Future<void> _prepare() async {
    try {
      await bind.mainSetOption(key: 'stop-service', value: 'Y');
      await windowManager.setTitle('TempoDestek | Tempo Bilişim');
      await windowManager.setSize(const Size(560, 780));
      await windowManager.setMinimumSize(const Size(420, 650));
    } catch (e) {
      _error = 'Hazırlanamadı: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _start() async {
    try {
      final identity = customerIdentity(_taxId.text, _person.text);
      if (!RegExp(r'^[0-9]{10,11}$').hasMatch(identity['taxId']!)) {
        throw const FormatException('CRM için VKN 10, TCKN 11 rakam olmalıdır.');
      }
      setState(() {
        _busy = true;
        _error = '';
      });
      await bind.mainSetLocalOption(
          key: 'tempo-person', value: identity['person']!);
      await bind.mainSetLocalOption(
          key: 'tempo-tax-id', value: identity['taxId']!);
      await bind.mainSetOption(key: 'tempo-person', value: identity['person']!);
      await bind.mainSetOption(key: 'tempo-tax-id', value: identity['taxId']!);
      await bind.mainSetOption(
          key: 'preset-device-username', value: identity['display']!);
      await bind.mainSetOption(key: 'stop-service', value: '');
      if (mounted) setState(() { _ready = true; _crmStatus = 'Bağlantı hazır olunca CRM talebi gönderilecek…'; });
      _crmTimer?.cancel();
      _crmTimer = Timer.periodic(const Duration(seconds: 25), (_) => _syncCrm());
      await _refreshId();
      await _syncCrm();
    } catch (e) {
      if (mounted)
        setState(() =>
            _error = e is FormatException ? e.message : 'Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncCrm() async {
    if (!_ready || _crmBusy) return;
    _crmBusy = true;
    try {
      final queue = TempoCrmQueue.instance;
      final connected = customerConnectionReady(_ready, _deviceId, gFFI.serverModel.connectStatus);
      if (!queue.accepted) {
        if (!connected) return;
        await queue.submit(_person.text.trim(), _taxId.text.trim(), _topic.text.trim(), _deviceId);
      }
      final active = await queue.pulse(connected);
      if (mounted) setState(() => _crmStatus = active
          ? (connected ? '✓ CRM talebiniz alındı. Personel bağlantısını bekleyin.' : 'CRM talebi açık; bağlantı bekleniyor.')
          : 'Talep kapatıldı. Yeni destek için hazır durumundan çıkıp tekrar başlayın.');
      if (!active) _crmTimer?.cancel();
    } catch (_) {
      if (mounted) setState(() => _crmStatus = 'CRM’e ulaşılamadı. Otomatik yeniden denenecek.');
    } finally { _crmBusy = false; }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      _crmTimer?.cancel();
      try { await TempoCrmQueue.instance.cancel(); } catch (_) {}
      await bind.mainSetOption(key: 'stop-service', value: 'Y');
      if (mounted) setState(() => _ready = false);
    } catch (e) {
      if (mounted) setState(() => _error = 'Durdurulamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _idTimer?.cancel();
    _crmTimer?.cancel();
    _topic.dispose();
    _taxId.dispose();
    _person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ColoredBox(
      color: const Color(0xfff4f6fa),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Theme(
                    data: ThemeData.light(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset('assets/tempo-logo.png',
                                width: 180, height: 80, fit: BoxFit.contain)),
                        const SizedBox(height: 18),
                        const Text('Sizin Masaüstünüz',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),
                        AnimatedBuilder(
                            animation: gFFI.serverModel,
                            builder: (context, _) {
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Kimlik'),
                                    Row(children: [
                                      Expanded(
                                          child: SelectableText(
                                              _deviceId.isEmpty
                                                  ? 'Kimlik oluşturuluyor…'
                                                  : formatID(_deviceId),
                                              style: const TextStyle(
                                                  fontSize: 26))),
                                      IconButton(
                                          tooltip: 'Kimliği kopyala',
                                          onPressed: _deviceId.isEmpty
                                              ? null
                                              : () => Clipboard.setData(
                                                  ClipboardData(
                                                      text: _deviceId)),
                                          icon: const Icon(Icons.copy))
                                    ]),
                                    const SizedBox(height: 10),
                                    const Text('Tek kullanımlık parola'),
                                    const Text(
                                        '—  Bağlantı sizin onayınızla açılır.',
                                        style: TextStyle(
                                            color: Color(0xff52647a))),
                                  ]);
                            }),
                        const SizedBox(height: 24),
                        TextField(
                            controller: _person,
                            enabled: !_ready && !_busy,
                            maxLength: 80,
                            decoration: const InputDecoration(
                                labelText: 'Ad Soyad *',
                                hintText: 'Adınızı ve soyadınızı yazın',
                                border: OutlineInputBorder()),
                            textInputAction: TextInputAction.next),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _taxId,
                            enabled: !_ready && !_busy,
                            maxLength: 11,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11)
                            ],
                            decoration: const InputDecoration(
                                labelText: 'Firma VKN/TC *',
                                hintText: 'VKN veya TC numarası',
                                helperText:
                                    'Yalnızca rakam · En fazla 11 karakter',
                                border: OutlineInputBorder()),
                            onSubmitted: (_) {
                              if (!_ready && !_busy) _start();
                            }),
                        const SizedBox(height: 8),
                        TextField(controller: _topic, enabled: !_ready && !_busy, maxLength: 1000, decoration: const InputDecoration(labelText: 'Destek konusu (isteğe bağlı)', border: OutlineInputBorder())),
                        if (_crmStatus.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_crmStatus)),
                        const Text(
                            'Bilgiler bu cihazda hatırlanır ve destek operatörüne iletilir.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xff52647a))),
                        if (_error.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(_error,
                                  style: const TextStyle(color: Colors.red))),
                        const SizedBox(height: 18),
                        if (!_ready)
                          FilledButton.icon(
                              onPressed: _busy ? null : _start,
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xffff7900),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16)),
                              icon: const Icon(Icons.support_agent),
                              label: Text(_busy
                                  ? 'Hazırlanıyor…'
                                  : 'Destek iste')),
                        if (_ready)
                          AnimatedBuilder(
                              animation: gFFI.serverModel,
                              builder: (context, _) => Text(
                                  customerConnectionReady(_ready, _deviceId,
                                          gFFI.serverModel.connectStatus)
                                      ? '● Destek bağlantısına hazır'
                                      : _deviceId.isEmpty
                                          ? '○ Kimlik oluşturuluyor…'
                                          : '○ Sunucuya bağlanılıyor…',
                                  style: TextStyle(
                                      color: customerConnectionReady(
                                              _ready,
                                              _deviceId,
                                              gFFI.serverModel.connectStatus)
                                          ? const Color(0xff198547)
                                          : const Color(0xff8b6500)))),
                        if (_ready)
                          TextButton(
                              onPressed: _busy ? null : _stop,
                              child: const Text(
                                  'Hazır durumundan çık / bilgileri düzenle')),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                            onPressed: closeTempoCustomer,
                            icon: const Icon(Icons.power_settings_new),
                            label: const Text('Desteği bitir ve kapat')),
                        const Text(
                            'Bağlantı isteğini yalnızca Tempo Bilişim personeliyle görüştüğünüzde onaylayın.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xff52647a))),
                        Wrap(alignment: WrapAlignment.center, children: [
                          TextButton(
                              onPressed: () => DesktopTabPage.onAddSetting(
                                  initialPage: SettingsTabKey.network),
                              child: const Text('Bağlantı ayarları')),
                          TextButton(
                              onPressed: () => showAboutDialog(
                                      context: context,
                                      applicationName: 'TempoDestek',
                                      applicationVersion: 'Test 0.11 • CRM',
                                      children: [
                                        const Text(
                                            'RustDesk altyapısı · AGPL-3.0\nKaynak: github.com/emredelibalta/rustdesk')
                                      ]),
                              child: const Text('Hakkında')),
                        ]),
                      ],
                    )),
              )),
        )),
      ),
    );
  }
}
