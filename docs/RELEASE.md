# 构建与发布

当前内部发布包为 `build/app/outputs/flutter-apk/litchi-journal-1.10.0-release.apk`（`1.10.0+42`），SHA-256 `f766100d8449ed12f1ed1abf57c78f6a8c8909251c3eec851ee0a474c6bfb25b`。原包名及Android Debug证书保持，APK v2验证通过，可覆盖安装；未安装设备、未部署服务端。下方1.9.2构建记录仅为历史。

2026-10-28 当前 UI／UX 整体优化及审查补修内部包：`build/app/outputs/flutter-apk/litchi-journal-1.9.2-uiux-reviewed-20261028-release.apk`，65,349,983 字节，SHA-256 `0d601468ec533d1ccdf290348161a6a2af6b9bffb73b5b631faef0a947695d1f`。从 `codex/habit-metric-labels-20261028` 当前未提交工作区构建正常入口；保持 `1.9.2+41`、原包名和与上一阅读补修包相同的 Android Debug 证书，三种 ABI 和 APK v2 签名已核对。仅构建校验，未安装真机、未提交或推送；当前交接见 HANDOFF.md。

2026-10-26 最新提示样式版本已构建并随 `main` 推送：`build/app/outputs/flutter-apk/litchi-journal-1.9.2-record-placeholders-release.apk`，SHA-256 `ed1f840f5791118e2eab92a75ca0bbc1c82619a1371c3e3c28e1e9db6be4f344`。版本 `1.9.2+41`，三种记录统一使用低透明度小字占位提示；沿用原包名和 Android Debug 证书，未部署服务端。

2026-10-28 阅读条目复审补修包从 `codex/reading-entry-alignment-20261027` 构建：`build/app/outputs/flutter-apk/litchi-journal-1.9.2-reading-entry-review-fixes-20261028-release.apk`，65,349,140 字节，SHA-256 `bc3a5a2d008cfa345b5e9d6c35ed5b3c8f5e1ac102d041d96cd61298f619f286`。保持 `1.9.2+41`、原包名和 Android Debug 证书，APK v2 签名与三种 ABI 验证通过；完整 Flutter 1284 项及静态分析通过。尚未安装真机。

此前清单为 `1.9.2+41`。2026-10-26 修复启动时记录加号变淡并升补丁版本；Android 内部 Release 沿用原 applicationId `com.example.litchi_journal_flutter` 和原签名，iOS Bundle ID 也保持不变。

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

`test/widget_test.dart` 是按功能拆分的测试注册入口（原 430 项，旧统计链路退役后保留 409 项当前有效用例），共享 fixture 位于 `test/support/widget_fixtures.dart`，按功能拆入同目录的 `widget_*.dart`。这些是 Dart part，不能单独执行；用 `flutter test test/widget_test.dart --plain-name 'QuickCaptureScreen'` 等名称过滤。新可靠性用例独立放在 `test/client_reliability_test.dart`、`test/write_reliability_test.dart`、`test/anxiety_draft_reliability_test.dart` 和 `test/gallery_refresh_performance_test.dart`。服务端测试使用系统临时目录，无需创建 `/private/tmp` 或复制真实配置。

## 保留覆盖安装的内部包

2026-10-26 最新测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.2-consistent-entry-timeline-release.apk`（65,332,756 字节），SHA-256 `3720c324d0c74342beb1ce6bb36fae0a59f893d7aec2e4a42aad441664bccaa0`。从功能分支代码 `51971db` 构建，三个记录模块统一显示时间轴，完整 Flutter 1147 项与静态检查通过、审核问题已修复。核对版本 `1.9.2+41`、原包名与证书及 APK v2 签名；用户确认已装机；本轮完成主线合并与推送，未部署。

前一个测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.2-startup-record-fab-release.apk`（65,332,756 字节），SHA-256 `2d65fb68d305ac1d9479da916c8b26f568829c379a54d1b277f2fa7228ef105d`。包含冷启动加号修复，不含后续统一时间轴；完整 Flutter 1111 项与 `flutter analyze --no-pub` 通过。此前 `1.9.1+40` 的 `litchi-journal-1.9.1-reflection-vertical-menu-release.apk` 不包含加号加载态修复。

此前测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reflection-vertical-menu-release.apk`（65,332,680 字节），SHA-256 `0d029d99e810044b85e753fdd449974ec6e483ab275a09f173f8f1f601fb58d2`。该包从功能分支代码 `381beec` 构建，包含三个快速记录入口、觉察静态提示和旧焦虑阅读修复；完整 Flutter 1110 项、服务端 160 项、静态分析、服务端构建及 Android Release 构建通过。已核对 `1.9.1+40`、原包名与证书和 APK v2 签名。未装机或部署；新日记模板须部署新版服务端后生效。

2026-10-19 上一轮测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reading-minimal-fixes-release.apk`（65,349,064 字节），SHA-256 `dc00ac2363962ab1ca864566243f302934e7623b7b4becc62e61059243c0ac68`。包含纸面三段设置及后续三处阅读补修：大字图标空间、标题强调继承与回顾按钮状态颜色。该阶段完整 Flutter 1060 项、静态检查、差异检查及 Release 构建通过，原安装包保留。

上一阶段测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-paper-segments-release.apk`（65,349,064 字节），SHA-256 `5b9abbccc210e3e5dd561b5ad7fed74c438610e7013992c36b11aa09d88e1481`，不含后续阅读显示三处最小补修，不能当作最新 `app-release.apk`。外观与阅读字号改为仅点击的纸面三段按钮，修复超大字体圆角裁切和动画中途停用后的中间颜色残留；该阶段完整 Flutter 1021 项、静态检查、差异检查与 Release 构建通过。保持 `1.9.1+40`、原包名及证书，APK v2 签名与三架构 AOT 已核对，可覆盖安装。`paper-segments-pre-review-release.apk` 为更早的中间包，不用于验收。

2026-10-18 统一胶囊审核补修已完成：超大系统字体空间不足时标签换行，避免选项热区重叠；正常字体布局不变。完整 Flutter 1021 项、静态检查、差异检查与 Release 构建通过，上一轮包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-appearance-reviewed-release.apk`（65,447,368 字节），SHA-256 `1e3141395c8e52aa3652aeadec152337f24f7fd478216c483e6cbc97bfa8b7b4`。保持 `1.9.1+40`、原包名与证书，APK v2 验证通过，支持覆盖安装；此包不含最新纸面三段按钮。

2026-10-18 外观设置按确认图收拢为统一胶囊，完整 Flutter 1015 项、静态检查、差异检查和 Release 构建通过。审核前测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-appearance-capsules-release.apk`（65,447,368 字节），SHA-256 `df76c7b2987dc5f928dbea7a26ef9a1afb81381b0e19b19ff85871d8118675a3`。版本仍为 `1.9.1+40`，原包名与证书未变，已验证 APK v2 签名有效；只在当前功能分支，不包含升版、合并、推送、部署或装机。浅深色本地渲染已检查，用户真机验收待完成。下面的旧测试包保留，不含统一胶囊。

2026-10-18 阅读字号功能根据真机反馈改为小／中／大 14／16／18sp 滑动条，默认中档，并增大正文到标签间距；该阶段完整 Flutter 1006 项、静态检查及 Release 构建通过。上阶段测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reading-three-sizes-release.apk`，仍为 `1.9.1+40`，仅在功能分支，不代表发布、合并或推送，构建校验见 `HANDOFF.md`。该轮授权不包含装机，下方安装命令仅供用户自行操作。原两档 `litchi-journal-1.9.1-reading-typography-release.apk` 和此前 `litchi-journal-1.9.1-followup-release.apk` 都保留，不包含最新三档与间距补修；更早的 `reliability-release.apk` 和原 `1.9.1-release.apk` 也不包含全部后续改动。

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
