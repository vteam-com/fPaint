import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/shell_model.dart';

Future<void> saveFile(
  final ShellModel shellModel,
  final AppModel appModel,
) async {
  final String fileName = shellModel.loadedFileName;
  final String extension = fileName.split('.').last.toLowerCase();

  switch (extension) {
    case 'png':
      await saveAsPng(appModel, fileName);
      break;
    case 'jpg':
    case 'jpeg':
      await saveAsJpeg(appModel, fileName);
      break;
    case 'ora':
      await saveAsOra(appModel, fileName);
      break;
  }
}
