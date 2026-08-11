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

  static void setTagListener(
    Future<void> Function(dynamic arguments) listener,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNfcTag') {
        await listener(call.arguments);
      }
    });
  }

  static void removeTagListener() {
    _channel.setMethodCallHandler(null);
  }
}
