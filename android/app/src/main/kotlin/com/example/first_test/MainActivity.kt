package com.example.manzelat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
        private const val PERMISSIONS_CHANNEL = "com.example.manzelat/permissions"
        private const val NFC_CHANNEL = "metro_ticket_native_nfc"
    }

    private var nfcAdapter: NfcAdapter? = null
    private var nfcMethodChannel: MethodChannel? = null
    private var nfcStateReceiver: BroadcastReceiver? = null

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

                "isNfcEnabled" -> {
                    result.success(nfcAdapter?.isEnabled == true)
                }

                "openNfcSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        registerNfcStateReceiver()
        sendNfcState()
    }

    private fun registerNfcStateReceiver() {
        if (nfcStateReceiver != null) return

        nfcStateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == NfcAdapter.ACTION_ADAPTER_STATE_CHANGED) {
                    sendNfcState()
                }
            }
        }

        val filter = IntentFilter(NfcAdapter.ACTION_ADAPTER_STATE_CHANGED)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                nfcStateReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(nfcStateReceiver, filter)
        }
    }

    private fun sendNfcState() {
        Handler(Looper.getMainLooper()).post {
            nfcMethodChannel?.invokeMethod(
                "onNfcState",
                mapOf(
                    "enabled" to (nfcAdapter?.isEnabled == true)
                )
            )
        }
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

        adapter.enableReaderMode(this, this, flags, Bundle())
    }

    private fun stopNfcReader() {
        try {
            nfcAdapter?.disableReaderMode(this)
        } catch (e: Exception) {
            Log.e(TAG, "disableReaderMode failed", e)
        }
    }

    override fun onTagDiscovered(tag: Tag) {
        try {
            val uid = tag.id

            if (uid == null || uid.isEmpty()) {
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
                        "ticketNumber" to ticketNumber
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
                        "error" to (e.message ?: "خطای ناشناخته")
                    )
                )
            }
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

        try {
            nfcStateReceiver?.let {
                unregisterReceiver(it)
            }
        } catch (_: Exception) {}

        nfcStateReceiver = null
        nfcMethodChannel?.setMethodCallHandler(null)
        nfcMethodChannel = null

        super.onDestroy()
    }
}
