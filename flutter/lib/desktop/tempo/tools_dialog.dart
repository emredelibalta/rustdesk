import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'tools_catalog.dart';

Future<void> showTempoTools(
        BuildContext context, Future<void> Function(String, String) run) =>
    showDialog<void>(context: context, builder: (_) => _ToolsDialog(run: run));

class _ToolsDialog extends StatefulWidget {
  final Future<void> Function(String, String) run;
  const _ToolsDialog({required this.run});
  @override
  State<_ToolsDialog> createState() => _ToolsDialogState();
}

class _ToolsDialogState extends State<_ToolsDialog> {
  TempoToolsCatalog _catalog = TempoToolsCatalog.empty();
  String _category = 'E-Uygulamalar', _error = '';
  bool _busy = true;
  File get _file {
    final root = Platform.environment['LOCALAPPDATA'];
    if (root == null || root.isEmpty)
      throw StateError('LocalAppData bulunamadı.');
    return File('$root/TempoAraclari/uygulamalar.json');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = _file;
      final catalog = await f.exists()
          ? TempoToolsCatalog.read(await f.readAsString())
          : TempoToolsCatalog.empty();
      if (mounted)
        setState(() {
          _catalog = catalog;
          _category = catalog.categories.contains(_category)
              ? _category
              : (catalog.categories.isEmpty ? '' : catalog.categories.first);
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

  Future<void> _save(TempoToolsCatalog catalog) async {
    final f = _file;
    await f.parent.create(recursive: true);
    if (await f.exists()) await f.copy('${f.path}.bak');
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(catalog.encode(), flush: true);
    await temp.rename(f.path);
    if (mounted)
      setState(() {
        _catalog = catalog;
        if (!catalog.categories.contains(_category))
          _category =
              catalog.categories.isEmpty ? '' : catalog.categories.first;
        _error = '';
      });
  }

  Future<void> _edit({bool header = false, TempoTool? old}) async {
    final name = TextEditingController(text: old?.name ?? '');
    final version = TextEditingController(text: old?.version ?? '');
    final url = TextEditingController(text: old?.url ?? '');
    var error = '';
    try {
      final result = await showDialog<Object>(
          context: context,
          builder: (c) => StatefulBuilder(
              builder: (c, update) => AlertDialog(
                      title: Text(header
                          ? 'Yeni başlık'
                          : old == null
                              ? 'Uygulama ekle'
                              : 'Uygulamayı düzenle'),
                      content: SizedBox(
                          width: 560,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            TextField(
                                controller: name,
                                decoration: InputDecoration(
                                    labelText: header
                                        ? 'Başlık adı'
                                        : 'Program adı (Java, AKİS vb.)')),
                            if (!header)
                              TextField(
                                  controller: version,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Sürüm / mimari (ör. Java x64)')),
                            if (!header)
                              TextField(
                                  controller: url,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'HTTPS EXE/MSI/ZIP/JAR indirme bağlantısı')),
                            if (error.isNotEmpty)
                              Text(error,
                                  style: const TextStyle(color: Colors.red)),
                          ])),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Vazgeç')),
                        FilledButton(
                            onPressed: () {
                              try {
                                if (header) {
                                  final value = name.text.trim();
                                  if (value.isEmpty ||
                                      _catalog.categories.contains(value))
                                    throw const FormatException(
                                        'Farklı bir başlık adı yazın.');
                                  Navigator.pop(c, value);
                                } else {
                                  Navigator.pop(
                                      c,
                                      TempoTool(
                                          old?.id ??
                                              DateTime.now()
                                                  .microsecondsSinceEpoch
                                                  .toString(),
                                          old?.category ?? _category,
                                          name.text.trim(),
                                          version.text.trim(),
                                          url.text.trim()));
                                }
                              } catch (e) {
                                update(() => error = '$e');
                              }
                            },
                            child: const Text('Kaydet'))
                      ])));
      if (result is String) {
        await _save(TempoToolsCatalog(
            [..._catalog.categories, result], _catalog.tools));
        if (mounted) setState(() => _category = result);
      }
      if (result is TempoTool) {
        await _save(TempoToolsCatalog(_catalog.categories,
            [..._catalog.tools.where((p) => p.id != result.id), result]));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      name.dispose();
      version.dispose();
      url.dispose();
    }
  }

  Future<void> _transfer(bool importing) async {
    try {
      if (importing) {
        final pick = await FilePicker.platform
            .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
        final path = pick?.files.single.path;
        if (path == null || !mounted) return;
        final value = TempoToolsCatalog.read(await File(path).readAsString());
        if (!mounted) return;
        final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                    title: const Text('Başlık ve uygulama listesini değiştir'),
                    content: Text(
                        '${value.categories.length} başlık ve ${value.tools.length} uygulama mevcut listenin yerine geçecek. Önceki liste yedeklenir.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Vazgeç')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('İçe aktar'))
                    ]));
        if (ok == true) await _save(value);
      } else {
        final path = await FilePicker.platform.saveFile(
            dialogTitle: 'Başlık ve uygulamaları dışa aktar',
            fileName: 'tempo-uygulamalar.json');
        if (path != null)
          await File(path).writeAsString(_catalog.encode(), flush: true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _download(TempoTool p) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text('${p.name} — müşteriye indir'),
                content: Text(
                    '${p.url}\n\nYeni terminal için müşteri onayı istenebilir. Dosya hedefte Masaüstü/MikroKurulum/Araclar içine indirilir. Kurulum otomatik başlamaz.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('İndir'))
                ]));
    if (ok == true) await widget.run(buildTempoToolDownload(p), p.name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('E-Uygulamalar ve özel başlıklar'),
          content: SizedBox(
              width: 880,
              height: 540,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Yerel liste • Diğer operatörlerle paylaşmak için dışa/içe aktarın. Merkezi eşitleme henüz bağlı değil.'),
                    Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<String>(
                              value: _category.isEmpty ? null : _category,
                              items: _catalog.categories
                                  .map((v) => DropdownMenuItem(
                                      value: v, child: Text(v)))
                                  .toList(),
                              onChanged: (v) => setState(() => _category = v!)),
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _edit(header: true),
                              child: const Text('Başlık oluştur')),
                          TextButton(
                              onPressed: _busy || _category.isEmpty
                                  ? null
                                  : () => _edit(),
                              child: const Text('Uygulama ekle')),
                          TextButton(
                              onPressed: () => _transfer(true),
                              child: const Text('İçe aktar')),
                          TextButton(
                              onPressed: () => _transfer(false),
                              child: const Text('Dışa aktar'))
                        ]),
                    if (_error.isNotEmpty)
                      Text(_error, style: const TextStyle(color: Colors.red)),
                    if (_category == 'E-Uygulamalar')
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                              'Java ve AKİS paketlerini burada ekleyin. Kullanacağınız Java mimarisi ve AKİS sürümü için doğrulanmış kurulum bağlantısını girin.')),
                    Expanded(
                        child: _busy
                            ? const Center(child: CircularProgressIndicator())
                            : ListView(children: [
                                for (final p in _catalog.tools
                                    .where((p) => p.category == _category))
                                  ListTile(
                                      title: Text('${p.name} ${p.version}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      leading: IconButton(
                                          tooltip: 'Düzenle',
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _edit(old: p)),
                                      trailing: TextButton(
                                          onPressed: () => _download(p),
                                          child: const Text('Müşteriye indir')))
                              ])),
                  ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'))
          ]);
}
