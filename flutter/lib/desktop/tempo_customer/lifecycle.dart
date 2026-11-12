import 'crm_queue.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/platform_model.dart';

bool _closing = false;

Future<void> closeTempoCustomer() async {

  if (_closing) return;
  _closing = true;
  try { await TempoCrmQueue.instance.cancel().timeout(const Duration(seconds: 2)); } catch (_) {}

  try {
    await bind
        .mainSetOption(key: 'stop-service', value: 'Y')
        .timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('TempoDestek stop before exit: $e');
  }
  try {
    await bind.mainOnMainWindowClose().timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint('TempoDestek portable helper close: $e');
  }
  // The portable server runs in this UI process. Do not kill other RustDesk/Host processes.
  exit(0);
}
