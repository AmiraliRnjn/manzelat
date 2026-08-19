import 'package:flutter/services.dart';

class NativeNfcService {
  static const MethodChannel _channel =
      MethodChannel('metro_ticket_native_nfc');

  static Future<void> startReader() async {
    await _channel.invokeMethod<void>('startNfcReader');
  }

  static Future<void> stopReader() async {
    await _channel.invokeMethod<void>('stopNfcReader');
  }

  static Future<bool> isNfcEnabled() async {
    final result = await _channel.invokeMethod<bool>('isNfcEnabled');
    return result ?? false;
  }

  static Future<bool> openNfcSettings() async {
    final result = await _channel.invokeMethod<bool>('openNfcSettings');
    return result ?? false;
  }

  static void setTagListener(
    Future<void> Function(dynamic arguments) listener,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNfcTag') {
        await listener(call.arguments);
      }
    });
  }
  // Use one native handler so tag and state events do not overwrite
  // each other. Call this when both listeners are needed.
  static void setListeners({
    required Future<void> Function(dynamic arguments) onTag,
    required Future<void> Function(bool enabled) onState,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNfcTag') {
        await onTag(call.arguments);
      } else if (call.method == 'onNfcState') {
        final arguments = Map<dynamic, dynamic>.from(
          (call.arguments as Map?) ?? const {},
        );
        await onState(arguments['enabled'] == true);
      }
    });
  }
  static void removeTagListener() {
    _channel.setMethodCallHandler(null);
  }
}
