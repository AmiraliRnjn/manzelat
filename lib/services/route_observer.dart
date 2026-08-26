import 'package:flutter/material.dart';

/// یک RouteObserver مشترک در کل اپ. صفحه‌هایی که باید بعد از برگشتن از
/// یک صفحه‌ی دیگر (مثلاً بعد از ثبت رسید یا بستن صفحه‌ی دوربین) اطلاعاتشان
/// را تازه کنند، با `with RouteAware` این را subscribe می‌کنند و متد
/// `didPopNext()` را override می‌کنند.
///
/// این فایل را باید هم در main.dart (برای دادن به MaterialApp.navigatorObservers)
/// و هم در هر صفحه‌ای که نیاز به رفرش خودکار دارد import کرد.
final RouteObserver<PageRoute<void>> appRouteObserver =
    RouteObserver<PageRoute<void>>();
