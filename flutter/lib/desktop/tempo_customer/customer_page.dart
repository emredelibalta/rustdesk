import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../common.dart';
import '../pages/desktop_setting_page.dart';
import '../pages/desktop_tab_page.dart';
import 'identity.dart';

class TempoCustomerPage extends StatefulWidget {
  const TempoCustomerPage({super.key});
  @override
  State<TempoCustomerPage> createState() => _TempoCustomerPageState();
}

class _TempoCustomerPageState extends State<TempoCustomerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _company = TextEditingController();
  final _person = TextEditingController();
  bool _ready = false, _busy = true;
  String _error = '';
  @override
  void initState() {
    super.initState();
    _company.text = bind.mainGetLocalOption(key: 'tempo-company');
    _person.text = bind.mainGetLocalOption(key: 'tempo-person');
    _pauseInitially();
  }

  Future<void> _pauseInitially() async {
    try {
      await bind.mainSetOption(key: 'stop-service', value: 'Y');
      await windowManager.setTitle('TempoDestek | Tempo Bilişim');
      await windowManager.setSize(const Size(720, 780));
      await windowManager.setMinimumSize(const Size(560, 620));
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Hazırlanamadı: $e';
          _busy = false;
        });
    }
  }

  Future<void> _start() async {
    try {
      final identity = customerIdentity(_company.text, _person.text);
      setState(() {
        _busy = true;
        _error = '';
      });
      // These are device metadata, never operator account credentials.
      await bind.mainSetLocalOption(
          key: 'tempo-company', value: identity['company']!);
      await bind.mainSetLocalOption(
          key: 'tempo-person', value: identity['person']!);
      await bind.mainSetOption(
          key: 'preset-device-username', value: identity['display']!);
      await bind.mainSetOption(
          key: 'display-name', value: identity['display']!);
      await bind.mainSetOption(key: 'stop-service', value: '');
      if (mounted)
        setState(() {
          _ready = true;
          _busy = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _busy = false;
        });
    }
  }

  Future<void> _stop() async {
    try {
      setState(() => _busy = true);
      await bind.mainSetOption(key: 'stop-service', value: 'Y');
      if (mounted)
        setState(() {
          _ready = false;
          _busy = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _busy = false;
        });
    }
  }

  @override
  void dispose() {
    _company.dispose();
    _person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: const Color(0xfff4f6fa),
      child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 660),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.asset('assets/tempo-logo.png',
                                          height: 80,
                                          alignment: Alignment.centerLeft),
                                      const SizedBox(height: 18),
                                      const Text('Birlikte çözelim.',
                                          style: TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xff142c4b))),
                                      const SizedBox(height: 8),
                                      const Text('Tempo Bilişim uzaktan destek',
                                          style: TextStyle(
                                              fontSize: 17,
                                              color: Color(0xff52647a))),
                                    ])),
                            const SizedBox(height: 14),
                            Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              _ready
                                                  ? 'Destek bağlantısına hazırsınız'
                                                  : 'Sizi tanıyalım',
                                              style: const TextStyle(
                                                  fontSize: 21,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xff142c4b))),
                                          const SizedBox(height: 8),
                                          const Text(
                                              'Bilgileriniz, destek personelimizin cihazınızı listede bulmasına yardımcı olur.',
                                              style: TextStyle(
                                                  color: Color(0xff52647a))),
                                          const SizedBox(height: 18),
                                          TextField(
                                              controller: _company,
                                              enabled: !_ready && !_busy,
                                              maxLength: 80,
                                              decoration: const InputDecoration(
                                                  labelText: 'Firma adı',
                                                  hintText: 'Örn. ABC Tekstil',
                                                  border: OutlineInputBorder(),
                                                  prefixIcon: Icon(Icons
                                                      .business_outlined))),
                                          const SizedBox(height: 8),
                                          TextField(
                                              controller: _person,
                                              enabled: !_ready && !_busy,
                                              maxLength: 80,
                                              decoration: const InputDecoration(
                                                  labelText: 'Ad Soyad',
                                                  hintText:
                                                      'Örn. Muhammed Yılmaz',
                                                  border: OutlineInputBorder(),
                                                  prefixIcon: Icon(
                                                      Icons.person_outline)),
                                              onSubmitted: (_) {
                                                if (!_busy && !_ready) _start();
                                              }),
                                          if (_error.isNotEmpty)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12),
                                                child: Text(_error,
                                                    style: const TextStyle(
                                                        color: Colors.red))),
                                          if (!_ready)
                                            FilledButton.icon(
                                                onPressed:
                                                    _busy ? null : _start,
                                                style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xffff7900),
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 18)),
                                                icon: const Icon(
                                                    Icons.support_agent),
                                                label: Text(
                                                    _busy
                                                        ? 'Hazırlanıyor…'
                                                        : 'Desteğe Hazır Ol',
                                                    style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                          if (_ready)
                                            AnimatedBuilder(
                                                animation: gFFI.serverModel,
                                                builder: (context, _) {
                                                  final model =
                                                      gFFI.serverModel;
                                                  final online =
                                                      model.connectStatus > 0;
                                                  return Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              18),
                                                      decoration: BoxDecoration(
                                                          color: const Color(
                                                              0xffedf7f1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      14)),
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(children: [
                                                              Icon(
                                                                  online
                                                                      ? Icons
                                                                          .check_circle
                                                                      : Icons
                                                                          .hourglass_top,
                                                                  color: online
                                                                      ? Colors
                                                                          .green
                                                                      : Colors
                                                                          .orange,
                                                                  size: 20),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                  child: Text(
                                                                      online
                                                                          ? 'Destek sunucusuna bağlı'
                                                                          : 'Sunucu bağlantısı hazırlanıyor…',
                                                                      style: const TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .w600,
                                                                          color:
                                                                              Color(0xff142c4b))))
                                                            ]),
                                                            const SizedBox(
                                                                height: 12),
                                                            const Text(
                                                                'Bağlantı kimliğiniz',
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xff52647a))),
                                                            Row(children: [
                                                              Expanded(
                                                                  child: SelectableText(
                                                                      model
                                                                          .serverId
                                                                          .text,
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              28,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          color:
                                                                              Color(0xff142c4b)))),
                                                              IconButton(
                                                                  tooltip:
                                                                      'Kimliği kopyala',
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .copy),
                                                                  onPressed:
                                                                      () async {
                                                                    await Clipboard.setData(ClipboardData(
                                                                        text: model
                                                                            .serverId
                                                                            .text));
                                                                  })
                                                            ]),
                                                            const Text(
                                                                'Bu kimliği destek personelimize iletin. Operatör listesinin yenilenmesi birkaç saniye sürebilir.',
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xff52647a))),
                                                            TextButton(
                                                                onPressed: _busy
                                                                    ? null
                                                                    : _stop,
                                                                child: const Text(
                                                                    'Hazır durumundan çık / bilgileri düzenle')),
                                                          ]));
                                                }),
                                          const SizedBox(height: 16),
                                          const Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                    Icons
                                                        .verified_user_outlined,
                                                    size: 20,
                                                    color: Color(0xff52647a)),
                                                SizedBox(width: 8),
                                                Expanded(
                                                    child: Text(
                                                        'Bağlantı isteğini yalnızca Tempo Bilişim personeliyle görüştüğünüzde onaylayın. Desteğe hazır olmak ekran paylaşımını kendiliğinden başlatmaz.',
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xff52647a),
                                                            fontSize: 12)))
                                              ]),
                                        ]))),
                            const SizedBox(height: 8),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                      onPressed: () =>
                                          DesktopTabPage.onAddSetting(
                                              initialPage:
                                                  SettingsTabKey.network),
                                      child: const Text('Bağlantı ayarları')),
                                  const Text('•',
                                      style: TextStyle(color: Colors.grey)),
                                  TextButton(
                                      onPressed: () => showAboutDialog(
                                              context: context,
                                              applicationName: 'TempoDestek',
                                              applicationVersion: 'Test 0.4',
                                              children: [
                                                const Text(
                                                    'Tempo Bilişim müşteri destek arayüzü. RustDesk açık kaynak altyapısı kullanılır. Lisans: AGPL-3.0. Kaynak: github.com/emredelibalta/rustdesk')
                                              ]),
                                      child: const Text('Hakkında')),
                                ]),
                          ])),
                ),
              )),
    );
  }
}
