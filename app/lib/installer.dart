import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'updates.dart';

Future<void> downloadAndInstall(BuildContext context, UpdateCheck update) async {
  if (update.apkUrl == null) {
    throw Exception('此版本没有 APK 附件。');
  }
  if (!Platform.isAndroid) {
    throw Exception('应用内安装仅支持安卓。');
  }
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DownloadDialog(update: update, messenger: messenger),
  );
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.update, required this.messenger});
  final UpdateCheck update;
  final ScaffoldMessengerState messenger;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final file = await _download(widget.update.apkUrl!, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      Navigator.pop(context);
      await _install(file.path);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      widget.messenger.showSnackBar(SnackBar(content: Text('更新失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('正在下载 ${widget.update.latest}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress <= 0 ? null : _progress.clamp(0, 1)),
          const SizedBox(height: 12),
          Text('${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

Future<File> _download(Uri url, void Function(double) onProgress) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/fx-sentinel-update.apk');
  if (await file.exists()) await file.delete();

  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    req.headers.set(HttpHeaders.userAgentHeader, 'fx-sentinel-app');
    req.followRedirects = true;
    final res = await req.close();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('下载失败 HTTP ${res.statusCode}');
    }
    final total = res.contentLength;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in res) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.close();
    onProgress(1);
    return file;
  } finally {
    client.close();
  }
}

Future<void> _install(String path) async {
  var status = await Permission.requestInstallPackages.status;
  if (!status.isGranted) {
    status = await Permission.requestInstallPackages.request();
  }
  if (!status.isGranted) {
    await openAppSettings();
    throw Exception('请允许「安装未知应用」，返回后再点检查更新。');
  }
  final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  if (result.type != ResultType.done && result.type != ResultType.noAppToOpen) {
    if (result.message.isNotEmpty) {
      throw Exception(result.message);
    }
  }
}
