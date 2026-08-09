import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import 'pages/home_page.dart';
import 'pages/charge_page.dart';
//import 'issue_page.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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