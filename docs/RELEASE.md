# Android 构建与交付

当前版本及最新内部包摘要只在 [HANDOFF.md](../HANDOFF.md) 维护，版本历史见 [CHANGELOG.md](../CHANGELOG.md)。本仓库仅保留 Android 客户端；服务端部署见 [server/DEPLOY.md](../server/DEPLOY.md)。

## 验证

开发与CI基线为 Flutter3.44.2／Dart3.12.2、Node.js22。客户端代码改动执行：

```bash
flutter pub get
flutter analyze
flutter test
git diff --check
```

服务端改动在 `server/` 执行 `npm ci`、`npm test`、`npm run build`。CI分别验证客户端和服务端，检查锁文件不被改写，不部署或生成商店包。文档改动还需按AGENTS检查链接和事实一致性。

`test/widget_test.dart` 是功能测试注册入口，共享fixture位于 `test/support/widget_fixtures.dart`；同目录 `widget_*.dart` 为part，不能单独执行。按名称筛选示例：`flutter test test/widget_test.dart --plain-name 'QuickCaptureScreen'`。服务端测试用系统临时目录，不读取真实配置或Vault。

## 内部包与覆盖安装

仅在用户授权构建、安装时执行相应命令：

```bash
flutter build apk --release
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
```

默认 `distribution=internal` 使用 `com.example.litchi_journal_flutter` 和原开发机debug证书。相同包名、相同证书且不降版本时，`adb install -r` 保留连接配置。保留已有证书，不用卸载来绕过签名冲突。需要分ABI时构建添加 `--split-per-abi`，安装前确认设备架构。

交付前核对版本、包名、证书、APK签名及摘要。构建成功不代表设备验收；真机应覆盖窄屏、大字、预测返回、键盘、缓存和上传失败恢复，详细待办见PLAN。验收数据与真实Vault隔离。

## 商店模式

内部debug签名包不用于商店。正式发布前明确独立applicationId并备份上传密钥；复制 `android/key.properties.example` 为本地 `android/key.properties`，填写 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`。这些文件和密钥库被Git忽略，禁止输出敏感内容。

```bash
ORG_GRADLE_PROJECT_distribution=store \
ORG_GRADLE_PROJECT_storeApplicationId=<已确认的正式applicationId> \
flutter build appbundle --release
```

store模式要求非 `com.example.*` 的合法包名、完整签名与存在的密钥库，缺项拒绝构建。新包名作为独立应用，不能自动继承内部包的私有配置；迁移单独验收，保留原包至确认完成。商店隐私说明与素材须齐全，描述保留 `Animated icons by Lordicon.com`。

只有明确准备发布新版本才修改 `pubspec.yaml` 和CHANGELOG；提交、合并、推送、构建、安装与部署分别依用户授权执行。

## 系统备份

Android关闭 `allowBackup`，并为旧版Auto Backup与Android12+云备份／设备迁移配置排除规则，避免加密凭据及短时草稿迁往缺少原密钥的设备。不同OEM行为需实机确认；重装或换机后手动配置连接。系统私有阅读缓存不替代备份，Vault的外部备份与同步独立维护。
