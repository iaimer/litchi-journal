# 构建与发布

当前清单为 `1.9.1+40`。2026-10-18 的可靠性修复没有新增版本；用户随后授权合并主分支、构建内部 Android Release 并推送。现有安装继续使用原 Android applicationId `com.example.litchi_journal_flutter` 和原签名，iOS Bundle ID 也保持不变。

## 本地与 CI 验证

将 Flutter 加入 PATH，使用 Flutter `3.44.2`（Dart `3.12.2`）及 Node.js `22`：

```bash
flutter pub get
flutter analyze
flutter test
cd server
npm ci
npm test
npm run build
```

回到仓库根目录后运行 `git diff --check`。`.github/workflows/ci.yml` 在 push、pull request 和手动触发时分别验证 Flutter 与服务端，并确认锁文件未被改写；不部署、不生成商店包、不需要仓库保存任何签名或服务端密钥。新增设置路由测试只监听本机随机端口，读写临时 Vault。

`test/widget_test.dart` 保留 430 项原测试的注册入口，共享 fixture 位于 `test/support/widget_fixtures.dart`，按功能拆入同目录的 `widget_*.dart`。这些是 Dart part，不能单独执行；用 `flutter test test/widget_test.dart --plain-name 'QuickCaptureScreen'` 等名称过滤。新可靠性用例独立放在 `test/client_reliability_test.dart` 与 `test/write_reliability_test.dart`。

## 保留覆盖安装的内部包

```bash
flutter build apk --release
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
```

默认 `distribution=internal`，Release 模式仍使用 debug 签名。保留现有开发机的签名证书；相同包名、相同证书且不降版本时，`adb install -r` 可以覆盖安装并保留连接配置。不同机器重新生成的 debug 证书可能不同，不能用卸载重装来绕过签名冲突。内部 APK 不能提交商店。按 ABI 分发时可添加 `--split-per-abi`，安装前选择设备对应架构。

本轮构建验证不等于真机安装验收。验收需检查横屏／320dp／放大字体下计时按钮可达、认证失效与服务器错误提示、图文记录失败重试、过往刷新及保存后重启恢复分页。不要连接真实 Vault 做破坏性测试。

## 可选 Android 商店配置

用户本轮选择先保持现有安装兼容，因此不预设新的正式包名，不生成密钥、不迁移当前应用。需要商店包时先确定独立的正式 applicationId，并按 [Flutter Android 发布说明](https://docs.flutter.dev/deployment/android) 在本地创建和妥善备份上传密钥。

将 `android/key.properties.example` 复制为被 Git 忽略的 `android/key.properties`，仅在本机填写 `storeFile`（建议绝对路径）、`storePassword`、`keyAlias`、`keyPassword`。密钥库也被 `.gitignore` 排除；不要把密钥、密码或文件内容发到聊天、构建日志或 Git。保留一份独立的安全备份，后续升级继续使用原正式身份与证书。

```bash
ORG_GRADLE_PROJECT_distribution=store \
ORG_GRADLE_PROJECT_storeApplicationId=<已确认的正式applicationId> \
flutter build appbundle --release
```

`store` 模式要求显式提供非 `com.example.*` 的合法包名、完整本地签名配置和存在的密钥库；缺任一项即失败，不回退为 debug 签名。上架前核对最终产物的包名、版本、release 状态与证书。只有明确发布新版本时才修改版本和 `CHANGELOG.md`。

正式包名与当前内部包名不同，会成为另一款独立安装的应用，不能继承原应用私有配置。迁移应另外安排 Vault／服务端数据与连接配置验证，保留内部包直到用户确认，不卸载当前包来试验。正式分发前还需补齐商店隐私说明和截图；商店描述须保留 `Animated icons by Lordicon.com`。

## 权限与系统备份

Android 使用 `allowBackup=false`，并分别为旧版 Auto Backup 和 Android 12+ 的云备份／设备迁移设置排除规则，覆盖应用文件、数据库、SharedPreferences 和外部应用目录。这避免把加密后的 Token、AI Key 与短时草稿迁到缺失原密钥的设备。不同 OEM 对 `allowBackup` 的行为有差异，因此同时声明 [data-extraction-rules](https://developer.android.com/identity/data/autobackup)。应用重装或换机后手动设置连接；Vault 的外部同步／备份不受这些规则影响。阅读缓存仍位于系统私有缓存目录，不能替代备份。

iOS 已声明相册用途和局域网访问用途，ATS 仅添加 `NSAllowsLocalNetworking`，未开启全局任意明文访问。该键针对本地域名与本地地址，不代表任意公网 HTTP 地址可用，具体见 [Apple 官方说明](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)。远程连接优先 HTTPS；实际局域网 IP、mDNS、拒绝后从系统设置恢复权限及真机选图仍需设备验收。没有使用相机／麦克风，因此未申请对应权限。

iOS 正式发布仍需要完整 Xcode、开发团队、正式 Bundle ID、描述文件及证书，并实际构建、安装与验收。当前只通过 plist 语法检查，不能据此认定 iOS 可发布。

## 服务端交付

第一批修改了服务端写入与错误语义，客户端和服务端都更新后才能完整生效。部署前按既有外部方式备份 Vault，并在部署机器拉取经确认的分支或提交；保留私有 `server/config.json`，不要提交或打印 Token。

```bash
cd server
npm ci
npm test
npm run build
npm run pm2:restart
```

首次部署使用已有 `pm2:start` 流程。重启后检查 `/health` 和实际授权连接；用临时测试日记确认创建、记录、习惯、图文与操作重试，再恢复正常使用。旧 `.diary-ops.json` 只读兼容，损坏且无法确认操作状态时会拒绝重放，不能删除它来绕过保护。日记原子替换不提供外部编辑器／云盘冲突合并，也不恢复已撤回的 ZIP／WebDAV 备份功能。
