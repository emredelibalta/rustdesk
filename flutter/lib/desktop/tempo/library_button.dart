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
import 'bulk_catalog.dart';
import 'download_progress.dart';
import 'demo_inventory.dart';
import 'tools_catalog.dart';
import 'tools_dialog.dart';
import 'package:flutter/services.dart';

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
  String _version = 'Tümü', _product = 'Tümü', _query = '', _error = '';
  String _notice = '';
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
      final list = withTempoPartnerPackages(await file.exists()
          ? readTempoCatalog(await file.readAsString())
          : _examples());
      if (mounted)
        setState(() {
          _records = list;
          if (!list.any((p) => '${p.major} / ${p.version}' == _version))
            _version = 'Tümü';
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
    records = withTempoPartnerPackages(records);
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
        if (!records.any((p) => '${p.major} / ${p.version}' == _version))
          _version = 'Tümü';
        _selected.clear();
        _error = '';
      });
  }

  Future<void> _bulkAdd() async {
    final version = TextEditingController(
        text: _version == 'Tümü' ? '08b' : _version.split(' / ').last);
    var product = _product == 'Tümü' ? 'Fly' : _product;
    final files = TextEditingController(
        text: tempoInstallerNames(_records, product).join('\n'));
    var error = '';
    try {
      final draft = await showDialog<List<TempoPackage>>(
          context: context,
          builder: (c) => StatefulBuilder(
              builder: (c, update) => AlertDialog(
                    title:
                        const Text('Sürüm paketlerini toplu ekle / güncelle'),
                    content: SizedBox(
                        width: 680,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              DropdownButtonFormField<String>(
                                  value: product,
                                  decoration:
                                      const InputDecoration(labelText: 'Ürün'),
                                  items: ['Fly', 'Jump', 'Run', 'Müşavir']
                                      .map((p) => DropdownMenuItem(
                                          value: p, child: Text(p)))
                                      .toList(),
                                  onChanged: (v) => update(() {
                                        product = v!;
                                        files.text = tempoInstallerNames(
                                                _records, product)
                                            .join('\n');
                                      })),
                              const SizedBox(height: 14),
                              TextField(
                                  controller: version,
                                  decoration: const InputDecoration(
                                      labelText: 'Güncelleme sürümü (ör. 08b)',
                                      border: OutlineInputBorder()),
                                  onChanged: (_) => update(() {})),
                              const SizedBox(height: 14),
                              Text(
                                  'Sabit adres: https://cdn-mikro.atros.com.tr/mikro/v17/${version.text.trim()}/'),
                              const SizedBox(height: 14),
                              TextField(
                                  controller: files,
                                  minLines: 4,
                                  maxLines: 7,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Kurulum dosya adları — her satır bir paket',
                                      border: OutlineInputBorder())),
                              const SizedBox(height: 12),
                              const Text(
                                  'Tam bağlantılar otomatik oluşturulur. Dosya adları kayıtlı paketlerden veya öneri şablonundan gelir; ilk kullanımda gerekirse düzeltin. Bulunmayan bağlantı kaydedilmez. Aynı ürün/sürüm/paket varsa güncellenir; diğer sürümler korunur.'),
                              if (error.isNotEmpty)
                                Text(error,
                                    style: const TextStyle(color: Colors.red)),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Vazgeç')),
                      FilledButton(
                          onPressed: () {
                            try {
                              Navigator.pop(
                                  c,
                                  tempoBulkPackages(
                                      _records,
                                      product,
                                      version.text,
                                      const LineSplitter()
                                          .convert(files.text)));
                            } catch (e) {
                              update(() => error = '$e');
                            }
                          },
                          child:
                              const Text('Bağlantıları denetle ve toplu ekle'))
                    ],
                  )));
      if (draft == null || !mounted) return;
      setState(() {
        _loading = true;
        _error = '';
        _notice = 'Bağlantılar denetleniyor…';
      });
      final valid = <TempoPackage>[], errors = <String>[];
      for (final package in draft) {
        if (!mounted) return;
        setState(() => _notice =
            'Denetleniyor: ${Uri.parse(package.url).pathSegments.last}');
        final problem = await checkTempoInstallerLink(package.url);
        if (problem == null) {
          valid.add(package);
        } else {
          errors.add('${package.package}: $problem');
        }
      }
      if (!mounted) return;
      if (valid.isNotEmpty) {
        final keys = valid.map((p) => p.key).toSet();
        await _save(
            [..._records.where((p) => !keys.contains(p.key)), ...valid]);
      }
      if (mounted)
        setState(() {
          _product = product;
          _version = 'V17 / ${version.text.trim().toLowerCase()}';
          if (!_records.any((p) => '${p.major} / ${p.version}' == _version))
            _version = 'Tümü';
          _notice = '${valid.length} paket eklendi/güncellendi.';
          _error = errors.join('\n');
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      version.dispose();
      files.dispose();
    }
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
                            [
                              'Server',
                              'Client',
                              'e-Defter',
                              'Partner',
                              'Diğer'
                            ],
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
      final jobId = DateTime.now().microsecondsSinceEpoch.toString();
      final command = buildTempoDownloadCommand(selected, jobId: jobId);
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
          builder: (_) => _DownloadTerminal(
              peerId: widget.peerId,
              command: command,
              progressJobId: jobId,
              progressLabels: selected.map((p) => p.label).toList()));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _runTool(String command, String title) async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DownloadTerminal(
            peerId: widget.peerId,
            command: command,
            taskTitle: title,
            sentStatus:
                'Komut gönderildi. İşlem hedef bilgisayarda çalışır; sonucu kontrol edin.'));
  }

  Future<void> _demo() async {
    try {
      final action = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Demo Kurulumu'),
                  content: const Text(
                      'Makine bilgilerini getir: karşı bilgisayarın SQL instance/sürüm, SSMS ve dil/bölge raporunu bu operatör ekranında gösterir. Ayar değiştirmez. Hedefte paneli aç: müşteri tarafında kurulum panelini açar. SQL 2019 Express kurulumu panelde ayrıca lisans ve kurulum onayı ister. Mevcut instance adları korunur; yeni ad seçilir. Yönetici yetkisi ve tam SQLEXPR kurulum medyası gerekir. Windows PowerShell komutları açık biçimde kullanılır.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, 'report'),
                        child: const Text('Makine bilgilerini getir')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, 'setup'),
                        child: const Text('Hedefte paneli aç'))
                  ]));
      if (action == null || !mounted) return;
      final script = await rootBundle.loadString('assets/tempo-demo.ps1');
      if (!mounted) return;
      if (action == 'report') {
        final job = DateTime.now().microsecondsSinceEpoch.toString();
        await showDialog<void>(context: context, barrierDismissible: false,
          builder: (_) => _DownloadTerminal(peerId: widget.peerId,
            command: buildTempoDemoLaunch(script, reportJob: job),
            inventoryJobId: job, taskTitle: 'Hedef makine bilgileri',
            sentStatus: 'Karşı bilgisayarın SQL ve bölge bilgileri okunuyor…'));
      } else {
        await _runTool(buildTempoDemoLaunch(script), 'Demo kurulumu');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _records
        .where((p) =>
            (_version == 'Tümü' || '${p.major} / ${p.version}' == _version) &&
            (_product == 'Tümü' || p.product == _product) &&
            '${p.label} ${p.note}'.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final versions =
        _records.map((p) => '${p.major} / ${p.version}').toSet().toList()
          ..sort((a, b) {
            final x = a.split(' / '), y = b.split(' / ');
            final major = int.parse(y[0].substring(1))
                .compareTo(int.parse(x[0].substring(1)));
            return major != 0 ? major : compareTempoVersions(y[1], x[1]);
          });
    return AlertDialog(
        title: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Tempo Kütüphanesi — ${widget.peerId}'),
              TextButton(onPressed: _demo, child: const Text('Demo Kurulumu')),
              TextButton(
                  onPressed: () => showTempoTools(context, _runTool),
                  child: const Text('E-Uygulamalar / Başlıklar'))
            ]),
        content: SizedBox(
            width: 940,
            height: 580,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Sürüm ve ürün seçin, indireceğiniz paketleri işaretleyin.'),
              Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Sürüm:'),
                    DropdownButton<String>(
                        value: _version,
                        items: ['Tümü', ...versions]
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (v) => setState(() {
                                  _version = v!;
                                  _selected.clear();
                                })),
                    const Text('Ürün:'),
                    DropdownButton<String>(
                        value: _product,
                        items: ['Tümü', 'Fly', 'Jump', 'Run', 'Müşavir']
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) => setState(() {
                              _product = v!;
                              _selected.clear();
                            })),
                    TextButton(
                        onPressed: _loading ? null : _bulkAdd,
                        child: const Text('Toplu paket ekle')),
                    TextButton(
                        onPressed: _loading ? null : () => _edit(),
                        child: const Text('Tek paket')),
                    TextButton(
                        onPressed: _loading ? null : _load,
                        child: const Text('Yenile')),
                    TextButton(
                        onPressed: _loading ? null : _import,
                        child: const Text('İçe aktar')),
                    TextButton(
                        onPressed: _export, child: const Text('Dışa aktar'))
                  ]),
              TextField(
                  decoration:
                      const InputDecoration(labelText: 'Sürüm / paket ara'),
                  onChanged: (v) => setState(() {
                        _query = v;
                        _selected.clear();
                      })),
              if (_notice.isNotEmpty) Text(_notice),
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
                                title: Text(p.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
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
  const _DownloadTerminal(
      {required this.peerId,
      required this.command,
      this.taskTitle = 'Mikro indirme',
      this.progressJobId,
      this.inventoryJobId,
      this.progressLabels = const [],
      this.sentStatus =
          'Komut gönderildi. İndirme sonucu aşağıdaki terminalde görünür.'});
  final String peerId, command, taskTitle, sentStatus;
  final String? progressJobId, inventoryJobId;
  final List<String> progressLabels;
  @override
  State<_DownloadTerminal> createState() => _DownloadTerminalState();
}

class _DownloadTerminalState extends State<_DownloadTerminal> {
  late final FFI _ffi;
  late final TerminalModel _model;
  TempoInventoryDecoder? _inventoryDecoder;
  String? _inventoryReport;
  TempoProgressDecoder? _decoder;
  TempoDownloadProgress? _progress;
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
    if (widget.progressJobId != null) {
      _decoder = TempoProgressDecoder(widget.progressJobId!);
      _model.onRemoteData = (text) {
        if (!mounted || _progress?.finished == true) return;
        final progress = _decoder!.add(text);
        if (progress != null) setState(() => _progress = progress);
      };
    }
    if (widget.inventoryJobId != null) {
      _inventoryDecoder = TempoInventoryDecoder(widget.inventoryJobId!);
      _model.onRemoteData = (text) {
        if (!mounted || _inventoryReport != null) return;
        final report = _inventoryDecoder!.add(text);
        if (report != null) setState(() {
          _inventoryReport = tempoInventoryText(report);
          _status = 'Karşı bilgisayar bilgileri alındı. Ayarlar değiştirilmedi.';
        });
      };
    }
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
        if (mounted) setState(() => _status = widget.sentStatus);
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
                    'İşlem sürüyorsa kesilebilir. Sonucu kontrol ederek kapatın.'),
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
    _model.onRemoteData = null;
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
          title: Text('${widget.taskTitle} — ${widget.peerId}'),
          content: SizedBox(
              width: 960,
              height: 540,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_status),
                    if (_progress != null) ...[
                      const SizedBox(height: 8),
                      Text(_progress!.phase == 'A'
                          ? 'Tüm indirmeler tamamlandı'
                          : _progress!.phase == 'F'
                              ? 'İndirme bitti; başarısız paket var. Terminal kaydını kontrol edin.'
                              : 'Dosya ${_progress!.index}/${_progress!.count}: ${_progress!.index > 0 && _progress!.index <= widget.progressLabels.length ? widget.progressLabels[_progress!.index - 1] : ""}'),
                      LinearProgressIndicator(value: _progress!.fraction),
                      Text(_progress!.phase == 'V'
                          ? 'Dosya indirildi, dijital imza doğrulanıyor…'
                          : _progress!.phase == 'A'
                              ? '%100'
                              : '${_progress!.fraction == null ? "Boyut bilinmiyor" : "%${(_progress!.fraction! * 100).floor()}"} • ${(_progress!.received / 1048576).toStringAsFixed(1)} MB${_progress!.total > 0 ? " / ${(_progress!.total / 1048576).toStringAsFixed(1)} MB" : ""}'),
                    ],
                    const SizedBox(height: 10),
                    if (_inventoryReport != null)
                      Expanded(child: SingleChildScrollView(
                        child: SelectableText(_inventoryReport!)))
                    else Expanded(
                        child: TerminalMouseInteraction(_model.terminal,
                            controller: _model.terminalController,
                            focusNode: _focus,
                            autofocus: true)),
                  ])),
          actions: [
            TextButton(onPressed: _close, child: const Text('Terminali kapat'))
          ]));
}
