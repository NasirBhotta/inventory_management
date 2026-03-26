import 'dart:io';

import '../errors/app_exceptions.dart';

Future<void> launchExternalUrl(String url) async {
  ProcessResult result;

  if (Platform.isWindows) {
    result = await Process.run('cmd', ['/c', 'start', '', url], runInShell: true);
  } else if (Platform.isMacOS) {
    result = await Process.run('open', [url]);
  } else if (Platform.isLinux) {
    result = await Process.run('xdg-open', [url]);
  } else {
    throw const AppException('External links are not supported on this platform');
  }

  if (result.exitCode != 0) {
    throw AppException('Could not open WhatsApp link', result.stderr);
  }
}
