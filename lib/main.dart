import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'pages/home_page.dart';
import 'pages/charge_page.dart';
import 'pages/receipt_target_page.dart';
import 'services/backup_service.dart';
import 'services/log_service.dart';
//import 'issue_page.dart';

void main() {
  // در نسخه‌ی واقعی (Release) که دست کاربرهاست فقط warning/error ثبت
  // می‌شود (یعنی عملاً هیچ نوشتنی در حالت عادی انجام نمی‌شود). در حالت
  // توسعه، برای دیباگ کامل‌تر همه سطوح ثبت می‌شوند.
  LogService.minLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug;

  runZonedGuarded(() {
    // خطاهای فریم‌ورک فلاتر (مثلاً خطای build یک ویجت) را می‌گیرد و هم
    // در کنسول نشان می‌دهد و هم در فایل لاگ ثبت می‌کند.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      LogService.e('FlutterError', details.exceptionAsString(), details.exception, details.stack);
    };

    LogService.i('App', 'برنامه شروع به کار کرد');
    runApp(const MyApp());
  }, (error, stackTrace) {
    // هر خطای دیگری که در کل اپ (خارج از build فلاتر) رخ بدهد، مثلاً
    // در یک Future ناهماهنگ، اینجا گرفته می‌شود تا اپ خاموش کرش نکند
    // و اثری از آن در لاگ بماند.
    LogService.e('Uncaught', 'خطای مدیریت‌نشده', error, stackTrace);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initShareIntentListener();
    // Backup خودکار: تنظیمات آن در صفحه‌ی Backup ذخیره می‌شود، اما تا
    // اینجا هیچ‌جا صدا زده نمی‌شد و عملاً هیچ‌وقت اجرا نمی‌شد. حالا هم
    // موقع باز شدن برنامه و هم موقع برگشتن از پس‌زمینه بررسی می‌شود.
    BackupService.maybeRunAutoBackup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BackupService.maybeRunAutoBackup();
    } else if (state == AppLifecycleState.paused) {
      // موقع رفتن به پس‌زمینه لاگ‌های بافرشده را فوری روی دیسک می‌نویسیم
      // تا اگر سیستم‌عامل اپ را کامل ببندد چیزی از دست نرود.
      LogService.flushNow();
    }
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
    WidgetsBinding.instance.removeObserver(this);
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