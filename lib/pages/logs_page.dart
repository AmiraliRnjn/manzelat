
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/log_service.dart';

/// صفحه‌ی ساده‌ی نمایش لاگ‌های اپ. برای پشتیبانی/دیباگ: می‌شود لاگ را
/// دید، برای توسعه‌دهنده Share کرد یا کامل پاک کرد.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  static const primaryBlue = Color(0xFF1565C0);
  static const background = Color(0xFFFAFBFF);
  static const darkText = Color(0xFF151A2B);
  static const secondaryText = Color(0xFF707789);

  bool _loading = true;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await LogService.readAll();
    if (!mounted) return;
    setState(() {
      _content = text.trim().isEmpty ? 'لاگی ثبت نشده است.' : text;
      _loading = false;
    });
  }

  Future<void> _share() async {
    final path = await LogService.currentFilePath();
    final file = File(path);
    if (!await file.exists()) return;
    await Share.shareXFiles([XFile(path)], text: 'لاگ برنامه Manzelat');
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن لاگ'),
        content: const Text('همه‌ی لاگ‌های ذخیره‌شده پاک شوند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LogService.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: darkText,
        title: const Text(
          'لاگ برنامه',
          style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'اشتراک‌گذاری',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _loading ? null : _share,
          ),
          IconButton(
            tooltip: 'پاک کردن',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _loading ? null : _clear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7ECF5)),
                    ),
                    child: SelectableText(
                      _content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: secondaryText,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
