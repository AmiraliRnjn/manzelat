
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../services/search_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const primaryBlue = Color(0xFF1565C0);
  static const background = Color(0xFFFAFBFF);
  static const darkText = Color(0xFF151A2B);
  static const secondaryText = Color(0xFF707789);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = const [];
  bool _loading = false;
  String _lastQuery = '';
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;
    final request = ++_requestId;

    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _runSearch(query, request);
  }

  Future<void> _runSearch(String query, int request) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || request != _requestId) return;

    final results = await SearchService.search(query);
    if (!mounted || request != _requestId) return;

    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _openResult(SearchResult result) async {
    if (result.isDirectory) {
      await _showPathDialog(result);
      return;
    }

    try {
      await OpenFilex.open(result.path);
    } catch (_) {
      if (mounted) await _showPathDialog(result);
    }
  }

  Future<void> _showPathDialog(SearchResult result) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          result.title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'Traffic',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          result.path,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن', style: TextStyle(fontFamily: 'Traffic')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'جستجوی مشتری',
          style: TextStyle(
            fontFamily: 'Traffic',
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'نام مشتری را وارد کنید',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search_rounded, color: primaryBlue),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _controller.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE1E6EF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE1E6EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: primaryBlue, width: 1.4),
                ),
              ),
              style: const TextStyle(fontFamily: 'Traffic', fontSize: 17),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: primaryBlue,
              backgroundColor: Color(0xFFEAF2FF),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.text.trim().isEmpty) {
      return const _EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'جستجوی سریع مشتری',
        subtitle: 'فقط نام مشتری جستجو می‌شود و نتیجه شامل پوشه مشتری و ZIP آن است.',
      );
    }

    if (!_loading && _results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'مشتری پیدا نشد',
        subtitle: 'نام دیگری را امتحان کنید.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (_, index) {
        final result = _results[index];
        return _ResultTile(result: result, onTap: () => _openResult(result));
      },
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isZip = result.type == SearchResultType.archive;
    final color = isZip ? const Color(0xFF6B7280) : const Color(0xFF1565C0);
    final icon = isZip ? Icons.folder_zip_rounded : Icons.folder_rounded;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172554),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 12.5,
                        color: Color(0xFF707789),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF9AA1AD)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(icon, color: const Color(0xFF1565C0), size: 43),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Traffic',
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172554),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Traffic',
                fontSize: 14,
                color: Color(0xFF707789),
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



