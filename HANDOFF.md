# 当前交接

## 状态与范围

2026-10-18，交付源功能分支 `codex/reliability-followup-20261018`，从 `main` 提交 `c35ab1b` 建立；沿用用户本会话已授权的 squash 合并、内部 Release 构建与推送流程交付主线。用户确认先补 CI／非时间完整匹配／图片数据校验，再一起完成性能优化和旧代码整理。清单仍为 `1.9.1+40`，沿用现有 Android 包名和签名；不部署真实服务端、不安装手机、不迁移正式应用身份。

## 本轮实现

CI：首次主线 run 39075113504 的 Flutter 通过，服务端因测试写死 `/private/tmp` 在 Ubuntu 遇到 EACCES。三个实际文件写入 fixture 改用 `node:os.tmpdir()` + `mkdtempSync()`，只读 mock 不再引用平台绝对路径；不创建 CI 特权目录或依赖本机私有配置。

写入：服务端非时间记录也先确定完整条目边界，再核对 rawLine；只传首行或独立续行均 404，完整记录才允许修改／删除。覆盖列表、引用、Callout、checkbox 和图文关联；照片后手写说明保持独立。`imageData` 非字符串或空白时提前 400，不创建附件目录，不读取或修改日记。

性能：过往页已访问分页按每批最多 3 个并发刷新，保留全部访问清单；同批按原游标顺序合并，避免响应乱序使旧图片复活。认证失败立即结束当前刷新，不再排后续批次；页面移除或请求代次变化后不应用旧结果。

清理：服务端启动后异步检查日记年月目录，只删除超过 24 小时、符合本程序日期＋UUID v4 临时命名、且与现存非空日记字节完全一致的副本。不跟随文件或目录符号链接；原文缺失／为空、内容不同、元信息变化或读取异常时保留。内容不同的临时文件可能包含崩溃前未提交记录，不能按扩展名一概删除；清理失败只记固定提示，不阻断 API 启动。

旧代码：移除无生产读取调用的 `HabitStatsService`、固定 key 的 `HabitStatsCacheRepository`、旧页面兼容缓存参数、仅被旧服务使用的并发工具，以及 `HabitHeatmapTabs`／`HabitRhythmGrid`／`HabitSummaryCard`／`MemoryCard`。保留当前趋势页需要的每日快照、习惯分组和追踪类型模型，API 写入继续使当前趋势缓存失效。删除仅验证旧实现的 21 项测试，保留全部当前趋势页用例和每日快照序列化测试。

## 验证与交付

新增服务端 19 项：12 项输入／非时间块边界、7 项临时副本清理；完整 `npm test` 146 项及 `npm run build` 通过。新增 Flutter 4 项真实过往页回归：六分页两批请求、最多三并发、乱序合并、认证失败及离开停止。完整 `flutter test` 932 项（949 - 21 + 4），`flutter analyze` 零问题。本轮所有文件操作测试只使用独立临时目录，不读取真实 Vault。

功能分支提交 `41c2b21` 的 [云端 CI 39076319336](https://github.com/iaimer/litchi-journal/actions/runs/39076319336) 已全部成功：Ubuntu 服务端测试及构建、Flutter 静态检查及完整测试、差异与锁文件检查均通过。首次主线 CI 的跨平台路径失败已在真实 Ubuntu runner 修复。

本轮正常入口 Release 构建通过，新包 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-followup-release.apk`，65,331,794 字节（约 65.3MB），SHA-256 `ff01b2ad031e833a4fac794ed15a260cc18891c33b103fc5317508ab208de0a1`。版本 1.9.1 / code 40、原包名、无调试标记与 Release AOT 已核对；APK v2 验证通过，证书与此前包一致。新包与当前 app-release.apk 相同，arm64 AOT 已确认不同于此前 reliability 包，支持 `adb install -r` 覆盖安装。

此前主线可靠性包 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reliability-release.apk` 不包含本轮补修，不得当作最新产物。原包为 65,331,794 字节，SHA-256 `465f02e7e605988524a0a0abdeb5a7b4f2664e8f5598779e5854c5ef6e5129fd`；旧 `litchi-journal-1.9.1-release.apk` 更早。构建与覆盖安装步骤见 [发布说明](docs/RELEASE.md)。本机没有完整 Xcode，iOS 未构建或装机；默认 Android 内部 Release 沿用 debug 证书，不是商店正式包。

第一轮三批及残留补修已在 `c35ab1b` squash 进入主线：日记原子替换、习惯增量更新、正文与操作标记同次提交、保守附件删除、计时持久幂等重试、输入与草稿保护、按尺寸图片、凭据隔离和画廊访问清单。旧 `.diary-ops.json` 只读兼容，损坏且不能确认操作状态时拒绝重放，不能删除它绕过保护。仍需用户部署新版 `server/` 并覆盖安装当前客户端才能完整生效；不提供离线写入、自动补交、外部编辑冲突合并或新的备份产品。

更早背景见 [交接档案](docs/archive/HANDOFF-20261018-before-reliability-cleanup.md)。`SESSION_LOG.md` 继续只读，不追加历史流水。
