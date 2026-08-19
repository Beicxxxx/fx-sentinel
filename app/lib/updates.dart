import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateCheck {
  UpdateCheck({
    required this.current,
    required this.latest,
    required this.hasUpdate,
    this.releaseUrl,
    this.notes,
    this.error,
  });

  final String current;
  final String latest;
  final bool hasUpdate;
  final Uri? releaseUrl;
  final String? notes;
  final String? error;
}

const githubRepo = 'Beicxxxx/fx-sentinel';

int _cmp(String a, String b) {
  List<int> parts(String v) {
    final cleaned = v.trim().replaceFirst(RegExp(r'^v'), '').split('+').first;
    return cleaned.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

Future<UpdateCheck> checkForUpdate({String githubToken = ''}) async {
  final info = await PackageInfo.fromPlatform();
  final current = info.version;
  final headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'fx-sentinel-app',
  };
  if (githubToken.trim().isNotEmpty) {
    headers['Authorization'] = 'Bearer ${githubToken.trim()}';
  }
  final uri = Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
  try {
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    if (res.statusCode == 404) {
      return UpdateCheck(
        current: current,
        latest: current,
        hasUpdate: false,
        error: githubToken.trim().isEmpty
            ? '私有仓库需要在设置里填写 GitHub Token 才能检查 Release。'
            : '没有找到 latest Release。',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return UpdateCheck(
        current: current,
        latest: current,
        hasUpdate: false,
        error: '检查更新失败（HTTP ${res.statusCode}）。',
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? current);
    final html = data['html_url'] as String?;
    return UpdateCheck(
      current: current,
      latest: tag,
      hasUpdate: _cmp(tag, current) > 0,
      releaseUrl: html == null ? null : Uri.parse(html),
      notes: data['body'] as String?,
    );
  } catch (e) {
    return UpdateCheck(
      current: current,
      latest: current,
      hasUpdate: false,
      error: '检查更新失败：$e',
    );
  }
}
