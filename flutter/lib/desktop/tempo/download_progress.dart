class TempoDownloadProgress {
  final int index, count, received, total;
  final String phase;
  const TempoDownloadProgress(
      this.index, this.count, this.received, this.total, this.phase);
  bool get finished => phase == 'A' || phase == 'F';
  double? get fraction => phase == 'F'
      ? 0
      : phase == 'A' || phase == 'C'
          ? 1
          : total > 0
              ? (received / total).clamp(0.0, 1.0)
              : null;
}

class TempoProgressDecoder {
  final String jobId;
  String _buffer = '', _last = '';
  TempoProgressDecoder(this.jobId);
  TempoDownloadProgress? add(String chunk) {
    _buffer += chunk;
    if (_buffer.length > 16384)
      _buffer = _buffer.substring(_buffer.length - 16384);
    final text = _buffer
        .replaceAll(RegExp(r'\x1b\[[0-?]*[ -/]*[@-~]'), '')
        .replaceAll(RegExp(r'\s+'), '');
    final matches = RegExp(
            'TDP\\|${RegExp.escape(jobId)}\\|(\\d+)\\|(\\d+)\\|(\\d+)\\|(-?\\d+)\\|([DVCEAF]);')
        .allMatches(text);
    if (matches.isEmpty) return null;
    final m = matches.last;
    if (m[0] == _last) return null;
    _last = m[0]!;
    final index = int.parse(m[1]!),
        count = int.parse(m[2]!),
        received = int.parse(m[3]!),
        total = int.parse(m[4]!);
    if (index > count || count < 1 || total < -1) return null;
    return TempoDownloadProgress(index, count, received, total, m[5]!);
  }
}
