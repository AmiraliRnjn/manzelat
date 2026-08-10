import 'dart:io';
import 'package:flutter/material.dart';
import '../operation_type.dart';
import '../services/file_manager_service.dart';

class FileManagerPage extends StatefulWidget {
  final OperationType operationType;

  const FileManagerPage({super.key, required this.operationType});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  List<Directory> customerFolders = [];
  List<File> zipFiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final folders = await FileManagerService.getCustomerFolders(
      widget.operationType,
    );
    final zips = await FileManagerService.getCustomerZipFiles(
      widget.operationType,
    );

    if (!mounted) return;

    setState(() {
      customerFolders = folders;
      zipFiles = zips;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.operationType == OperationType.charge
        ? 'شارژ این تاریخ'
        : 'صدور این تاریخ';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'فایل اصلی'),
              Tab(text: 'ZIP'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildCustomerFoldersList(),
                  _buildZipFilesList(),
                ],
              ),
      ),
    );
  }

  Widget _buildCustomerFoldersList() {
    if (customerFolders.isEmpty) {
      return const Center(child: Text('هنوز مشتری‌ای برای این تاریخ ثبت نشده'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: customerFolders.length,
        itemBuilder: (context, index) {
          final folder = customerFolders[index];
          final fileCount = folder.listSync().whereType<File>().length;

          return ListTile(
            leading: const Icon(Icons.folder, color: Colors.amber),
            title: Text(FileManagerService.displayName(folder)),
            subtitle: Text('$fileCount فایل'),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('این بخش در مرحله بعد اضافه می‌شود')),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildZipFilesList() {
    if (zipFiles.isEmpty) {
      return const Center(child: Text('هنوز فایل ZIP‌ای برای این تاریخ ساخته نشده'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: zipFiles.length,
        itemBuilder: (context, index) {
          final zip = zipFiles[index];

          return ListTile(
            leading: const Icon(Icons.folder_zip, color: Colors.deepOrange),
            title: Text(FileManagerService.displayName(zip)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('این بخش در مرحله بعد اضافه می‌شود')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}