# 构建与发布

## 环境

- Flutter stable（开发时为 3.47）、Android SDK、JDK 17
- Python 3.12+
- 发布到 GitHub 需要有 `repo` 权限的 Personal Access Token，且只存在于本机环境变量 `GH_TOKEN`

## 客户端

```bash
cd app
flutter pub get
flutter test
flutter analyze
flutter build apk --release
```

产物：`app/build/app/outputs/flutter-apk/app-release.apk`。

`android/app/build.gradle.kts` 里 release 目前指向 **debug 签名**。若要分发给他人或上架，需自备 keystore，用 `key.properties`（已 gitignore）配置，切勿把密钥提交进仓库。

## 机器人测试

```bash
cd bot
PYTHONPATH=. python3 -m unittest discover -s tests -v
```

## 打 GitHub Release

1. 更新 `app/pubspec.yaml` 的 `version` 与 [CHANGELOG.md](../CHANGELOG.md)。
2. 提交并推送到 `main`。
3. 构建 APK，重命名为 `fx-sentinel-<version>.apk`。
4. 打标签并创建 Release（示例）：

```bash
git tag v1.0.1
git push origin v1.0.1
gh release create v1.0.1 fx-sentinel-1.0.1.apk \
  --title "v1.0.1" \
  --notes-file CHANGELOG.md
```

私有仓的 Release 资源需要登录后才能下载。
