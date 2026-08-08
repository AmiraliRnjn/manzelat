package com.example.first_test

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.first_test/permissions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {

        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->

            if (call.method == "openAllFilesAccessSettings") {

                try {

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {

                        // این نسخه‌ی عمومی (بدون مشخص کردن پکیج خاص) است؛
                        // به‌جای صفحه‌ی اختصاصی همین اپ، لیست همه‌ی اپ‌ها را نشان می‌دهد
                        // و روی امولاتورهایی که صفحه‌ی اختصاصی کرش می‌کند معمولاً پایدارتر است.
                        val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                        startActivity(intent)
                        result.success(true)

                    } else {

                        result.success(false)

                    }

                } catch (e: Exception) {

                    result.error("UNAVAILABLE", "امکان باز کردن این صفحه نیست", null)

                }

            } else {

                result.notImplemented()

            }

        }

    }

}
