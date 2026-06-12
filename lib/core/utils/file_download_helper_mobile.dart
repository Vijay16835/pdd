import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String?> saveAndLaunchFileImpl(List<int> bytes, String fileName) async {
  // Check permission on Android
  if (Platform.isAndroid) {
    if (!await Permission.storage.isGranted && !await Permission.manageExternalStorage.isGranted) {
      final storageResult = await Permission.storage.request();
      if (!storageResult.isGranted) {
        final manageResult = await Permission.manageExternalStorage.request();
        if (!manageResult.isGranted) {
          throw Exception('Permission denied to save files.');
        }
      }
    }
  }

  // Get download directory
  Directory? dir;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    dir = await getDownloadsDirectory();
  }
  if (Platform.isAndroid) {
    final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
    if (externalDirs != null && externalDirs.isNotEmpty) {
      dir = externalDirs.first;
    }
  }
  dir ??= await getApplicationDocumentsDirectory();

  final savePath = '${dir.path}${Platform.pathSeparator}$fileName';
  final file = File(savePath);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);

  // Launch file using OpenFilex
  await OpenFilex.open(savePath);

  return savePath;
}
