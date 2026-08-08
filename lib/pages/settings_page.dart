import 'package:flutter/material.dart';
import '../services/storage_settings_service.dart';
import '../services/permission_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {

  final TextEditingController pathController = TextEditingController();

  bool isLoading = true;
  bool hasPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    // وقتی کاربر از تنظیمات اندروید برمی‌گردد تو اپ (resume)،
    // دوباره وضعیت مجوز را چک می‌کنیم تا آیکون به‌روز شود.
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
    }

  }

  Future<void> _refreshPermissionStatus() async {

    final permission = await PermissionService.hasStoragePermission();

    if (!mounted) return;

    setState(() {
      hasPermission = permission;
    });

  }

  Future<void> _loadData() async {

    final path = await StorageSettingsService.getStoragePath();
    final permission = await PermissionService.hasStoragePermission();

    setState(() {
      pathController.text = path ?? '';
      hasPermission = permission;
      isLoading = false;
    });

  }

  Future<void> _requestPermission() async {

    final granted = await PermissionService.requestStoragePermission();

    setState(() {
      hasPermission = granted;
    });

    if (!mounted) return;

    if (!granted) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'مجوز داده نشد. برای فعال کردن دستی به تنظیمات اپ بروید.',
          ),
        ),
      );

    }

  }

  Future<void> _saveStoragePath() async {

    final path = pathController.text.trim();

    if (path.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً یک مسیر معتبر وارد کنید.')),
      );

      return;

    }

    if (!hasPermission) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ابتدا باید مجوز دسترسی به حافظه را فعال کنید.',
          ),
        ),
      );

      return;

    }

    await StorageSettingsService.setStoragePath(path);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('مسیر ذخیره‌سازی با موفقیت ذخیره شد.')),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('مدیریت / تنظیمات'),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const Text(
                    'مجوز دسترسی به حافظه',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [

                      Icon(
                        hasPermission ? Icons.check_circle : Icons.cancel,
                        color: hasPermission ? Colors.green : Colors.red,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        hasPermission
                            ? 'مجوز فعال است.'
                            : 'مجوز هنوز فعال نشده است.',
                      ),

                    ],
                  ),

                  const SizedBox(height: 12),

                  if (!hasPermission)
                    ElevatedButton.icon(
                      onPressed: _requestPermission,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('فعال‌سازی مجوز دسترسی به حافظه'),
                    ),

                  if (!hasPermission) const SizedBox(height: 8),

                  if (!hasPermission)
                    TextButton(
                      onPressed: () {
                        PermissionService.openAllFilesAccessSettingsList();
                      },
                      child: const Text(
                        'اگر دکمه‌ی بالا جواب نداد، از اینجا لیست عمومی را باز کنید',
                      ),
                    ),

                  const Divider(height: 40),

                  const Text(
                    'مسیر ذخیره‌سازی',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'مسیر کامل پوشه‌ای که می‌خواهید فایل‌ها در آن ذخیره شوند را وارد کنید.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: pathController,
                    decoration: const InputDecoration(
                      labelText: 'مسیر ذخیره‌سازی',
                      hintText: r'مثال: /storage/emulated/0/MiCardData',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _saveStoragePath,
                    icon: const Icon(Icons.save),
                    label: const Text('ذخیره مسیر'),
                  ),

                  const Divider(height: 40),

                  const Text(
                    'تاریخ کاری',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'این بخش در مرحله بعد (سیستم تقویم شمسی) اضافه می‌شود.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                ],
              ),
            ),

    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pathController.dispose();
    super.dispose();
  }

}