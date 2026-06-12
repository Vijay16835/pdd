import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_mobile.dart';

Future<String?> saveAndLaunchFile(List<int> bytes, String fileName) =>
    saveAndLaunchFileImpl(bytes, fileName);
