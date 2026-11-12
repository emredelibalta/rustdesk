import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../common.dart';
import '../../models/model.dart';
import '../../models/terminal_model.dart';
import '../../models/terminal_mouse_handler.dart';
import 'catalog.dart';

class TempoLibraryButton extends StatelessWidget {
  const TempoLibraryButton(
      {super.key, required this.peerId, required this.platform});
  final String peerId, platform;
  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows || platform != 'Windows')
      return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Tempo Kütüphanesi',
      icon: const Icon(Icons.library_books, color: Colors.orange),
      onPressed: () => showDialog<void>(
          context: context, builder: (_) => _LibraryDialog(peerId: peerId)),
    );
  }
}

class _LibraryDialog extends StatefulWidget {
  const _LibraryDialog({required this.peerId});
  final String peerId;
  @override
  State<_LibraryDialog> createState() => _LibraryDialogState();
}

class _LibraryDialogState extends State<_LibraryDialog> {
  List<TempoPackage> _records = [];
  final _selected = <String>{};
  String _product = 'Tümü', _query = '', _error = '';
  bool _loading = true;
  File get _file {
    final root = Platform.environment['LOCALAPPDATA'];
    if (root == null || root.isEmpty)
      throw StateError('LocalAppData bulunamadı.');
    return File('$root/TempoAraclari/kutuphane.json');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = _file;
      final list = await file.exists()
          ? readTempoCatalog(await file.readAsString())
          : _examples();
      if (mounted)
        setState(() {
          _records = list;
          _selected.clear();
          _error = '';
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  List<TempoPackage> _examples() =>
      ['Server', 'Client', 'e-Defter'].map((kind) {
        final token = kind == 'e-Defter' ? 'eDefter' : kind;
        return TempoPackage({
          'id': kind,
          'product': 'Fly',
          'major': 'V17',
          'version': '08b',
          'package': kind,
          'date': '2026-11-12',
          'status': 'Test ediliyor',
          'url':
              'https://cdn-mikro.atros.com.tr/mikro/v17/08b/Fly_v17xx_${token}_Setupx064.exe',
          'note': 'Kullanıcının bağlantısı. Gerçek yayın tarihi doğrulanmadı.'
        });
      }).toList();
  Future<void> _save(List<TempoPackage> records) async {
    final text = const JsonEncoder.withIndent('  ')
        .convert(records.map((p) => p.toJson()).toList());
    readTempoCatalog(text);
    final file = _file;
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.copy('${file.path}.bak');
    // Keep an existing file intact if validation or temporary writing fails.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(text, flush: true);
    await temporary.rename(file.path);
    if (mounted)
      setState(() {
        _records = records;
        _selected.clear();
        _error = '';
      });
  }

  Future<void> _edit([TempoPackage? old]) async {
    final values = old?.toJson() ??
        {
          'product': 'Fly',
          'major': 'V17',
          'version': '08b',
          'package': 'Client',
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'status': 'Test ediliyor',
          'url': '',
          'note': ''
        };
    final controls = {
      for (final key in ['major', 'version', 'date', 'url', 'note'])
        key: TextEditingController(text: values[key])
    };
    var product = values['product']!,
        kind = values['package']!,
        status = values['status']!;
    var error = '';
    final result = await showDialog<TempoPackage>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, update) {
              Widget pick(String label, String value, List<String> options,
                      void Function(String) change) =>
                  DropdownButtonFormField<String>(
                      value: value,
                      decoration: InputDecoration(labelText: label),
                      items: options
                          .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => update(() => change(v!)));
              return AlertDialog(
                  title: Text(old == null ? 'Paket ekle' : 'Paketi düzenle'),
                  content: SizedBox(
                      width: 580,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        pick('Ürün', product, ['Fly', 'Jump', 'Run', 'Müşavir'],
                            (v) => product = v),
                        for (final pair in [
                          ['major', 'Ana sürüm (V17)'],
                          ['version', 'Güncelleme (08b)'],
                          ['date', 'Yayın tarihi (yyyy-MM-dd)']
                        ])
                          TextField(
                              controller: controls[pair[0]],
                              decoration: InputDecoration(labelText: pair[1])),
                        pick(
                            'Paket',
                            kind,
                            ['Server', 'Client', 'e-Defter', 'Diğer'],
                            (v) => kind = v),
                        pick(
                            'Durum',
                            status,
                            ['Test ediliyor', 'Kullanıma hazır', 'Arşiv'],
                            (v) => status = v),
                        TextField(
                            controller: controls['url'],
                            decoration: const InputDecoration(
                                labelText: 'HTTPS EXE/MSI bağlantısı')),
                        TextField(
                            controller: controls['note'],
                            decoration:
                                const InputDecoration(labelText: 'Açıklama')),
                        if (error.isNotEmpty)
                          Text(error,
                              style: const TextStyle(color: Colors.red)),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () {
                          try {
                            final record = TempoPackage({
                              'id': old?.id ??
                                  DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                              'product': product,
                              'package': kind,
                              'status': status,
                              for (final e in controls.entries)
                                e.key: e.value.text.trim()
                            });
                            if (_records.any((p) =>
                                p.id != record.id && p.key == record.key))
                              throw const FormatException(
                                  'Bu paket zaten kayıtlı.');
                            Navigator.pop(dialogContext, record);
                          } catch (e) {
                            update(() => error = '$e');
                          }
                        },
                        child: const Text('Kaydet'))
                  ]);
            }));
    // Dialog route exit animations may still reference these controllers.
    // Let route-owned fields be disposed before releasing the controller objects.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final c in controls.values) {
      c.dispose();
    }
    if (result != null && mounted) {
      try {
        await _save([..._records.where((p) => p.id != result.id), result]);
      } catch (e) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _import() async {
    try {
      final picked = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      final path = picked?.files.single.path;
      if (path == null || !mounted) return;
      final records = readTempoCatalog(await File(path).readAsString());
      if (!mounted) return;
      final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Kütüphaneyi değiştir'),
                  content: Text(
                      '${records.length} kayıt mevcut listenin yerine geçecek. Önceki liste yedeklenir.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('İçe aktar'))
                  ]));
      if (ok == true) await _save(records);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _export() async {
    try {
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Kütüphaneyi dışa aktar',
          fileName: 'tempo-kutuphane.json');
      if (path != null)
        await File(path).writeAsString(
            const JsonEncoder.withIndent('  ')
                .convert(_records.map((p) => p.toJson()).toList()),
            flush: true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _download() async {
    try {
      final selected = _records.where((p) => _selected.contains(p.id)).toList();
      final command = buildTempoDownloadCommand(selected);
      final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: Text('Hedef cihaz: ${widget.peerId}'),
                  content: SingleChildScrollView(
                      child: Text(
                          '${selected.map((p) => '${p.label}\n${p.url}').join('\n\n')}\n\n'
                          '${selected.any((p) => p.status != "Kullanıma hazır") ? "TEST PAKETİ SEÇİLDİ.\n" : ""}'
                          'Yeni terminal oturumu açılır; parola veya müşteri onayı istenebilir. '
                          'Yetkilendirmeden sonra indirme otomatik başlar. Kurulum çalıştırılmaz. '
                          'İşlem bitene kadar terminal penceresini açık tutun.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Müşteri bilgisayarına indir'))
                  ]));
      if (ok != true || !mounted) return;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              _DownloadTerminal(peerId: widget.peerId, command: command));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _records
        .where((p) =>
            (_product == 'Tümü' || p.product == _product) &&
            '${p.label} ${p.note}'.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final newest = <String, TempoPackage>{};
    for (final p in shown.where((p) => p.status == 'Kullanıma hazır')) {
      final key = '${p.product} ${p.major}';
      if (!newest.containsKey(key) ||
          compareTempoVersions(p.version, newest[key]!.version) > 0)
        newest[key] = p;
    }
    return AlertDialog(
        title: Text('Tempo Kütüphanesi — ${widget.peerId}'),
        content: SizedBox(
            width: 940,
            height: 580,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Yerel kütüphane • Mikro sitesinden otomatik sürüm taraması yapılmaz.'),
              Wrap(spacing: 10, children: [
                DropdownButton<String>(
                    value: _product,
                    items: ['Tümü', 'Fly', 'Jump', 'Run', 'Müşavir']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() {
                          _product = v!;
                          _selected.clear();
                        })),
                TextButton(
                    onPressed: _loading ? null : () => _edit(),
                    child: const Text('Paket ekle')),
                TextButton(onPressed: _load, child: const Text('Yenile')),
                TextButton(onPressed: _import, child: const Text('İçe aktar')),
                TextButton(onPressed: _export, child: const Text('Dışa aktar'))
              ]),
              TextField(
                  decoration:
                      const InputDecoration(labelText: 'Sürüm / paket ara'),
                  onChanged: (v) => setState(() {
                        _query = v;
                        _selected.clear();
                      })),
              Text(
                  'Hazır sürümler: ${newest.entries.map((e) => "${e.key}: ${e.value.version}").join(" | ")}'),
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.red)),
              Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(children: [
                          for (final p in shown)
                            CheckboxListTile(
                                value: _selected.contains(p.id),
                                onChanged: p.status == 'Arşiv'
                                    ? null
                                    : (v) => setState(() {
                                          v == true
                                              ? _selected.add(p.id)
                                              : _selected.remove(p.id);
                                        }),
                                title: Text(p.label),
                                subtitle:
                                    Text('${p.status} • ${p.date}\n${p.url}'),
                                isThreeLine: true,
                                secondary: IconButton(
                                    tooltip: 'Düzenle',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _edit(p)))
                        ]))
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat')),
          FilledButton(
              onPressed: _selected.isEmpty || _loading ? null : _download,
              child: const Text('Seçili paketleri indir'))
        ]);
  }
}

class _DownloadTerminal extends StatefulWidget {
  const _DownloadTerminal({required this.peerId, required this.command});
  final String peerId, command;
  @override
  State<_DownloadTerminal> createState() => _DownloadTerminalState();
}

class _DownloadTerminalState extends State<_DownloadTerminal> {
  late final FFI _ffi;
  late final TerminalModel _model;
  final _focus = FocusNode();
  Timer? _timeout;
  bool _sent = false, _expired = false;
  String _status =
      'Terminal bağlantısı bekleniyor. Gerekirse müşteri onayını/parolayı tamamlayın.';
  @override
  void initState() {
    super.initState();
    _ffi = FFI(null);
    _ffi.id = widget.peerId;
    _model = TerminalModel(_ffi, 0);
    _ffi.registerTerminalModel(0, _model);
    _model.addListener(_ready);
    _model.onClosed = () {
      if (mounted)
        setState(() => _status = 'Terminal kapandı. Logu kontrol edin.');
    };
    _ffi.start(widget.peerId, isTerminal: true);
    _timeout = Timer(const Duration(seconds: 60), () {
      if (mounted && !_sent)
        setState(() {
          _expired = true;
          _status =
              'Terminal 60 saniyede hazır olmadı. Komut gönderilmedi. Kapatıp tekrar deneyin.';
        });
    });
  }

  void _ready() {
    if (!mounted || _sent || _expired || !_model.terminalOpened) return;
    if (_ffi.ffiModel.pi.platform != 'Windows') {
      _expired = true;
      setState(() => _status = 'Hedef Windows değil. Komut gönderilmedi.');
      return;
    }
    _sent = true;
    _timeout?.cancel();
    // One dispatch per dialog, including reconnects. Never queue a download before authorization.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _ffi.closed || !_model.terminalOpened) return;
      try {
        await _model.sendVirtualKey('${widget.command}\r');
        if (mounted)
          setState(() => _status =
              'Komut gönderildi. İndirme sonucu aşağıdaki terminalde görünür.');
      } catch (e) {
        if (mounted) setState(() => _status = 'Komut gönderilemedi: $e');
      }
    });
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Terminal kapatılsın mı?'),
                content: const Text(
                    'İndirme sürüyorsa kesilebilir. Sonucu kontrol ederek kapatın.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Bekle')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Kapat'))
                ]));
    if (ok == true && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _model.removeListener(_ready);
    _ffi.dialogManager.dismissAll();
    _ffi.close().catchError((Object e) {
      debugPrint('Tempo terminal close: $e');
    });
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      child: AlertDialog(
          title: Text('Mikro indirme — ${widget.peerId}'),
          content: SizedBox(
              width: 960,
              height: 540,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_status),
                    const SizedBox(height: 10),
                    Expanded(
                        child: TerminalMouseInteraction(_model.terminal,
                            controller: _model.terminalController,
                            focusNode: _focus,
                            autofocus: true)),
                  ])),
          actions: [
            TextButton(onPressed: _close, child: const Text('Terminali kapat'))
          ]));
}
