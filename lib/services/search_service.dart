import 'dart:io';

import '../services/storage_settings_service.dart';

enum SearchResultType {
  customer,
  folder,
  image,
  file,
  receipt,
  archive,
  other,
}

class SearchResult {
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String path;
  final String? operation;
  final String? date;
  final int? size;

  const SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.path,
    this.operation,
    this.date,
    this.size,
  });

  bool get isDirectory => type == SearchResultType.customer ||
      type == SearchResultType.folder;
}

/// جستجوی واقعی روی تمام داده‌های ذخیره‌شده‌ی برنامه.
///
/// برای اینکه UI با تعداد زیاد فایل قفل نشود، جستجو asynchronous است و
/// حداکثر 250 نتیجه برمی‌گرداند.
class SearchService {
  static const int maxResults = 250;

  static Future<List<SearchResult>> search(
    String query, {
    int limit = maxResults,
  }) async {
    final rootPath = await StorageSettingsService.getStoragePath();
    if (rootPath == null || rootPath.trim().isEmpty) return const [];

    final root = Directory(rootPath);
    if (!await root.exists()) return const [];

    final q = _normalize(query.trim());
    if (q.isEmpty) return const [];

    final results = <SearchResult>[];

    try {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (results.length >= limit) break;

        final path = entity.path;
        final relative = _relative(root.path, path);
        if (relative.isEmpty) continue;

        final parts = relative.split('/');
        final name = parts.last;
        final normalizedName = _normalize(name);
        final normalizedPath = _normalize(relative);

        if (!_matches(q, normalizedName, normalizedPath)) continue;

        final operation = parts.isNotEmpty &&
                (parts.first == 'شارژ' || parts.first == 'صدور')
            ? parts.first
            : null;

        String? date;
        if (parts.length >= 5 &&
            _isFourDigit(parts[1]) &&
            _isTwoDigit(parts[2]) &&
            _isEightDigit(parts[3])) {
          date = '${parts[1]}/${parts[2]}/${parts[3].substring(4, 6)}/'
              '${parts[3].substring(6, 8)}';
        }

        if (entity is Directory) {
          final type = _isCustomerDirectory(parts)
              ? SearchResultType.customer
              : SearchResultType.folder;

          results.add(
            SearchResult(
              type: type,
              title: name,
              subtitle: _folderSubtitle(
                type,
                operation,
                date,
                relative,
              ),
              path: entity.path,
              operation: operation,
              date: date,
            ),
          );
        } else if (entity is File) {
          final lower = name.toLowerCase();
          final type = name.startsWith('رسید_')
              ? SearchResultType.receipt
              : lower.endsWith('.zip')
                  ? SearchResultType.archive
                  : _isImage(lower)
                      ? SearchResultType.image
                      : SearchResultType.file;

          final stat = await entity.stat();
          results.add(
            SearchResult(
              type: type,
              title: name,
              subtitle: _fileSubtitle(
                type,
                operation,
                date,
                relative,
              ),
              path: entity.path,
              operation: operation,
              date: date,
              size: stat.size,
            ),
          );
        }
      }
    } catch (_) {
      // دسترسی ناقص به یک زیرپوشه نباید کل جستجو را Crash کند.
    }

    return results;
  }

  static bool _matches(String query, String name, String path) {
    final tokens = query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    for (final token in tokens) {
      if (!name.contains(token) && !path.contains(token)) return false;
    }
    return true;
  }

  static String _normalize(String value) {
    return value
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ۀ', 'ه')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\u200c'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  static bool _isCustomerDirectory(List<String> parts) {
    return parts.length == 5 &&
        (parts.first == 'شارژ' || parts.first == 'صدور') &&
        _isFourDigit(parts[1]) &&
        _isTwoDigit(parts[2]) &&
        _isEightDigit(parts[3]);
  }

  static String _folderSubtitle(
    SearchResultType type,
    String? operation,
    String? date,
    String relative,
  ) {
    if (type == SearchResultType.customer) {
      return '${operation ?? 'پوشه'} • ${date ?? 'تاریخ نامشخص'}';
    }
    return 'پوشه • $relative';
  }

  static String _fileSubtitle(
    SearchResultType type,
    String? operation,
    String? date,
    String relative,
  ) {
    final label = switch (type) {
      SearchResultType.receipt => 'رسید',
      SearchResultType.archive => 'فایل ZIP',
      SearchResultType.image => 'تصویر',
      _ => 'فایل',
    };
    final extra = [
      if (operation != null) operation,
      if (date != null) date,
    ].join(' • ');
    return extra.isEmpty ? '$label • $relative' : '$label • $extra';
  }

  static bool _isImage(String name) {
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.heic');
  }

  static bool _isFourDigit(String value) => RegExp(r'^\d{4}$').hasMatch(value);
  static bool _isTwoDigit(String value) => RegExp(r'^\d{2}$').hasMatch(value);
  static bool _isEightDigit(String value) => RegExp(r'^\d{8}$').hasMatch(value);

  static String _relative(String root, String path) {
    final r = root.replaceAll('\\', '/').replaceFirst(RegExp(r'/$'), '');
    final p = path.replaceAll('\\', '/');
    final prefix = '$r/';
    return p.startsWith(prefix) ? p.substring(prefix.length) : p;
  }
}
