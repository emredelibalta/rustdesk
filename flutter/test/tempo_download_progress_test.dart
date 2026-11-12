import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop/tempo/download_progress.dart';

void main() {
  test('Progress survives packet splits and ignores another job', () {
    final decoder = TempoProgressDecoder('job1');
    expect(decoder.add('TDP|old|1|1|100|100|C;TDP|job1|1|2|50'), isNull);
    final value = decoder.add('|100|D;');
    expect(value!.fraction, 0.5);
    expect(value.index, 1);
    expect(value.count, 2);
  });
  test('ANSI wrapping and unknown file size remain honest', () {
    final decoder = TempoProgressDecoder('job2');
    final value = decoder.add('\x1b[32mTDP|job2|1|1|1234|\r\n-1|D;\x1b[0m');
    expect(value!.fraction, isNull);
    expect(value.received, 1234);
  });
  test('Completed and failed job states are explicit', () {
    final decoder = TempoProgressDecoder('job3');
    expect(decoder.add('TDP|job3|0|2|0|0|A;')!.fraction, 1);
    expect(decoder.add('TDP|job3|0|2|0|0|F;')!.phase, 'F');
  });
}
