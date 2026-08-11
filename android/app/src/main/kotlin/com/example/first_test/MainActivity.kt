package com.example.first_test

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareClassic
import android.nfc.tech.NfcA
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {

    companion object {
        private const val TAG = "NativeNfcDebug"
        private const val PERMISSIONS_CHANNEL = "com.example.first_test/permissions"
        private const val NFC_CHANNEL = "metro_ticket_native_nfc"
    }

    private var nfcAdapter: NfcAdapter? = null
    private var nfcMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "openAllFilesAccessSettings") {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
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

        nfcMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NFC_CHANNEL
        )

        nfcMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startNfcReader" -> {
                    try {
                        startNfcReader()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "startNfcReader failed", e)
                        result.error(
                            "NFC_START_ERROR",
                            e.message ?: "خطا در فعال‌سازی NFC",
                            null
                        )
                    }
                }

                "stopNfcReader" -> {
                    stopNfcReader()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        sendDebug(
            "NFC INITIALIZED",
            "Device: ${Build.MANUFACTURER} ${Build.MODEL}\n" +
                "Android: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})\n" +
                "NfcAdapter: ${nfcAdapter != null}\n" +
                "NFC enabled: ${nfcAdapter?.isEnabled == true}"
        )
    }

    private fun startNfcReader() {
        val adapter = nfcAdapter
            ?: throw IllegalStateException("NFC روی این گوشی در دسترس نیست.")

        if (!adapter.isEnabled) {
            throw IllegalStateException("NFC گوشی خاموش است.")
        }

        val flags =
            NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

        Log.d(TAG, "STARTING NFC READER MODE")

        sendDebug(
            "READER STARTED",
            "Reader Mode فعال شد.\n" +
                "منتظر Tag هستیم...\n\n" +
                "اگر بعد از نزدیک کردن کارت پیام TAG DISCOVERED نیامد، " +
                "Android کارت را به ReaderCallback تحویل نداده است."
        )

        adapter.enableReaderMode(this, this, flags, Bundle())
    }

    private fun stopNfcReader() {
        try {
            nfcAdapter?.disableReaderMode(this)
            sendDebug("READER STOPPED", "Reader Mode متوقف شد.")
        } catch (e: Exception) {
            Log.e(TAG, "disableReaderMode failed", e)
        }
    }

    override fun onTagDiscovered(tag: Tag) {
        Log.d(TAG, "========== TAG DISCOVERED ==========")

        try {
            val uid = tag.id

            if (uid == null || uid.isEmpty()) {
                sendDebug("TAG FOUND - NO UID", "Tag پیدا شد ولی UID خالی است.")
                return
            }

            val uidHex = uid.joinToString(":") {
                "%02X".format(Locale.US, it.toInt() and 0xFF)
            }

            val techNames = tag.techList.map {
                it.substringAfterLast(".")
            }

            val nfcA = NfcA.get(tag)

            val atqa = try {
                nfcA?.atqa?.joinToString(" ") {
                    "%02X".format(Locale.US, it.toInt() and 0xFF)
                } ?: ""
            } catch (_: Exception) {
                ""
            }

            val sak = try {
                nfcA?.let {
                    "0x%02X".format(Locale.US, it.sak.toInt() and 0xFF)
                } ?: ""
            } catch (_: Exception) {
                ""
            }

            val mifare = MifareClassic.get(tag)

            val mifareInfo = try {
                mifare?.let {
                    "Type: ${it.type}\n" +
                    "Size: ${it.size} bytes\n" +
                    "Sectors: ${it.sectorCount}\n" +
                    "Blocks: ${it.blockCount}"
                } ?: ""
            } catch (_: Exception) {
                ""
            }

            var ticketNumber = ""

            if (uid.size == 4) {
                val value =
                    (uid[0].toLong() and 0xFF) or
                    ((uid[1].toLong() and 0xFF) shl 8) or
                    ((uid[2].toLong() and 0xFF) shl 16) or
                    ((uid[3].toLong() and 0xFF) shl 24)

                ticketNumber = value.toString()
            }

            val debug = buildString {
                append("UID:\n$uidHex\n\n")
                append("UID length: ${uid.size} bytes\n\n")
                append("TECH LIST:\n")
                append(if (techNames.isEmpty()) "EMPTY" else techNames.joinToString("\n"))
                append("\n\nNFC-A: ${nfcA != null}\n")
                append("ATQA: ${if (atqa.isEmpty()) "N/A" else atqa}\n")
                append("SAK: ${if (sak.isEmpty()) "N/A" else sak}\n\n")
                append("MIFARE CLASSIC: ${if (mifare != null) "YES" else "NO"}\n")
                if (mifareInfo.isNotEmpty()) append("$mifareInfo\n")
                append("\nCALCULATED TICKET NUMBER: ")
                append(if (ticketNumber.isEmpty()) "NOT CALCULATED" else ticketNumber)
            }

            Log.d(TAG, debug)

            Handler(Looper.getMainLooper()).post {
                nfcMethodChannel?.invokeMethod(
                    "onNfcTag",
                    mapOf(
                        "uid" to uidHex,
                        "uidLength" to uid.size,
                        "techList" to techNames,
                        "nfcA" to (nfcA != null),
                        "atqa" to atqa,
                        "sak" to sak,
                        "mifareClassic" to (mifare != null),
                        "mifareInfo" to mifareInfo,
                        "ticketNumber" to ticketNumber,
                        "debug" to debug
                    )
                )

                nfcAdapter?.disableReaderMode(this)
            }
        } catch (e: Exception) {
            Log.e(TAG, "ERROR PROCESSING NFC TAG", e)

            Handler(Looper.getMainLooper()).post {
                nfcMethodChannel?.invokeMethod(
                    "onNfcTag",
                    mapOf(
                        "uid" to "",
                        "ticketNumber" to "",
                        "error" to (e.message ?: "خطای ناشناخته"),
                        "debug" to Log.getStackTraceString(e)
                    )
                )
            }
        }
    }

    private fun sendDebug(title: String, message: String) {
        Handler(Looper.getMainLooper()).post {
            nfcMethodChannel?.invokeMethod(
                "onNfcDebug",
                mapOf(
                    "title" to title,
                    "message" to message
                )
            )
        }
    }

    override fun onPause() {
        try {
            nfcAdapter?.disableReaderMode(this)
        } catch (_: Exception) {}
        super.onPause()
    }

    override fun onDestroy() {
        try {
            nfcAdapter?.disableReaderMode(this)
        } catch (_: Exception) {}

        nfcMethodChannel?.setMethodCallHandler(null)
        nfcMethodChannel = null
        super.onDestroy()
    }
}
