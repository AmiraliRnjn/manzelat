import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'pages/home_page.dart';
import 'pages/charge_page.dart';
import 'pages/receipt_target_page.dart';
//import 'issue_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;

  @override
  void initState() {
    super.initState();
    _initShareIntentListener();
  }

  void _initShareIntentListener() {
    // وقتی برنامه در حافظه باز است و از اپ دیگری (مثلاً پیام‌رسان) روی
    // «اشتراک‌گذاری» با این اپ زده می‌شود.
    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedFiles,
      onError: (_) {},
    );

    // وقتی برنامه کاملاً بسته بوده و با «اشتراک‌گذاری» باز شده.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
      }
      // تا دوباره با هر بازشدن اپ همان عکس قدیمی پردازش نشود.
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    final imagePaths = files
        .where((f) => f.type == SharedMediaType.image)
        .map((f) => f.path)
        .toList();

    if (imagePaths.isEmpty) return;

    // کمی صبر می‌کنیم تا navigator کاملاً آماده باشد (خصوصاً موقع باز شدن سرد اپ).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ReceiptTargetPage(receiptImagePaths: imagePaths),
        ),
      );
    });
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,

      locale: const Locale("fa", "IR"),

      supportedLocales: const [
        Locale("fa", "IR"),
        Locale("en", "US"),
      ],

      localizationsDelegates: const [
        PersianMaterialLocalizations.delegate,
        PersianCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      initialRoute: '/',

      routes: {
        '/': (context) => HomePage(),
        '/first': (context) => ChargePage(),
        //'/second': (context) => IssuePage(),
      },
    );
  }
}