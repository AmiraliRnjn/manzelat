
import 'dart:io';

import '../services/storage_settings_service.dart';

enum SearchResultType { customer, archive }

class SearchResult {
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String path;
  final String? operation;
  final String? date;

  const SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.path,
    this.operation,
    this.date,
  });

  bool get isDirectory => type == SearchResultType.customer;
}

/// جستجوی سریع فقط بر اساس نام مشتری.
///
/// عمداً فایل‌های داخل پوشه مشتری، رسیدها، عکس‌ها و مسیرهای داخلی جستجو
/// نمی‌شوند. خروجی فقط شامل پوشه مشتری و ZIP هم‌نام آن است.
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

    final q = _normalize(query);
    if (q.isEmpty) return const [];
    _rootPathCache = root.path;

    final results = <SearchResult>[];

    try {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (results.length >= limit) break;

        final name = _nameOf(entity);
        if (name.isEmpty) continue;

        // فقط نام خود entity معیار جستجو است؛ مسیر والدها معیار نیست.
        final searchableName = _normalize(
          entity is File && name.toLowerCase().endsWith('.zip')
              ? name.substring(0, name.length - 4)
              : name,
        );
        if (!_matches(q, searchableName)) continue;

        if (entity is Directory && _isCustomerDirectory(entity)) {
          final info = _customerInfo(entity);
          results.add(
            SearchResult(
              type: SearchResultType.customer,
              title: name,
              subtitle: '${info.$1 ?? 'پوشه'} • ${info.$2 ?? 'تاریخ نامشخص'}',
              path: entity.path,
              operation: info.$1,
              date: info.$2,
            ),
          );
        } else if (entity is File && name.toLowerCase().endsWith('.zip')) {
          final info = _customerInfoForZip(entity);
          results.add(
            SearchResult(
              type: SearchResultType.archive,
              title: name.substring(0, name.length - 4),
              subtitle: 'ZIP • ${info.$1 ?? 'پوشه مشتری'} • ${info.$2 ?? 'تاریخ نامشخص'}',
              path: entity.path,
              operation: info.$1,
              date: info.$2,
            ),
          );
        }
      }
    } catch (_) {
      // دسترسی ناقص به یک زیرشاخه نباید کل جستجو را Crash کند.
    }

    results.sort((a, b) {
      final title = a.title.compareTo(b.title);
      if (title != 0) return title;
      return a.type.index.compareTo(b.type.index);
    });

    return results;
  }

  static bool _matches(String query, String name) {
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty);
    return tokens.every(name.contains);
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

  static bool _isCustomerDirectory(Directory directory) {
    final parts = _relativeParts(directory.path);
    return parts.length == 5 &&
        (parts.first == 'شارژ' || parts.first == 'صدور') &&
        _isFourDigit(parts[1]) &&
        _isTwoDigit(parts[2]) &&
        _isEightDigit(parts[3]);
  }

  static (String?, String?) _customerInfo(Directory directory) {
    final parts = _relativeParts(directory.path);
    if (parts.length != 5) return (null, null);
    return (parts[0], _formatDate(parts[1], parts[2], parts[3]));
  }

  static (String?, String?) _customerInfoForZip(File file) {
    final parts = _relativeParts(file.path);
    if (parts.length != 5 || !parts.last.toLowerCase().endsWith('.zip')) {
      return (null, null);
    }
    return (parts[0], _formatDate(parts[1], parts[2], parts[3]));
  }

  static String? _formatDate(String year, String month, String day) {
    if (!_isFourDigit(year) || !_isTwoDigit(month) || !_isEightDigit(day)) {
      return null;
    }
    return '$year/$month/${day.substring(6, 8)}';
  }

  static List<String> _relativeParts(String path) {
    final rootPath = _rootPathCache;
    if (rootPath == null) return const [];
    final root = rootPath.replaceAll('\\', '/').replaceFirst(RegExp(r'/$'), '');
    final normalized = path.replaceAll('\\', '/');
    final prefix = '$root/';
    if (!normalized.startsWith(prefix)) return const [];
    return normalized.substring(prefix.length).split('/');
  }

  // Root is read once per search. This avoids another async call in every item.
  static String? _rootPathCache;

  static String _nameOf(FileSystemEntity entity) {
    return entity.path.split(Platform.pathSeparator).last;
  }

  static bool _isFourDigit(String value) => RegExp(r'^\d{4}$').hasMatch(value);
  static bool _isTwoDigit(String value) => RegExp(r'^\d{2}$').hasMatch(value);
  static bool _isEightDigit(String value) => RegExp(r'^\d{8}$').hasMatch(value);
}



