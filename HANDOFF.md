# 当前交接

## 阅读显示三处最小补修（2026-10-19，已合并并推送）

用户确认审查意见与浅深色对照预览后授权最小修复和重建测试 APK。随后授权将整轮阅读字号与外观更新 squash 合并到 `main` 并推送；清单保持 `1.9.1+40`，没有部署服务端或安装手机，真机验收仍由用户执行。只改 `JournalEntryActionSlot`、阅读 Markdown 内联样式和回顾按钮文字样式；三档字号、纸面选择器、照片、12dp 标签间距、数据及保存逻辑不变，不修改服务端。

先逐项跑失败回归再修复：操作槽原来固定 48dp，上边距随标签字体增大，4 倍时挤小图形；现在以 48dp 为最小高度，按首行标签中心给 18dp 图标／14dp 圆环留够空间。内联加粗／斜体／链接原来套完整正文样式，导致标题局部缩小、粗斜体丢失；现在仅定义各自效果并继承块级样式。回顾文字原来套 `bodyLarge`，覆盖了按钮状态色；现在继承原 16sp 按钮主题。三份失败日志 `/private/tmp/litchi-reading-minimal-{action,markdown,coach}-red-20261019.log`。

新增 `test/reading_typography_regression_test.dart` 39 项，覆盖 1–4 倍字体、照片／无照片、菜单／加载、首行标签实际对齐、连续时间轴及末条收尾；浅深色 × 三档的真实 Markdown 强调与链接继承，以及回顾启用／生成中颜色、字号和点击行为。旧测试移除对内联样式必须自行带字号的错误假设，改由实际渲染回归保护。相关 128 项、完整 Flutter 1060 项通过，静态检查零问题、差异检查通过。日志 `/private/tmp/litchi-reading-minimal-targeted-20261019.log`、`/private/tmp/litchi-reading-minimal-full-tests-20261019.log`、`/private/tmp/litchi-reading-minimal-analyze-20261019.log`。浅深色真实组件渲染已核对，截图 `/private/tmp/litchi-reading-minimal-actual-{light,dark}.png`；仅为本地渲染，不是真机安装验收。

正常入口 Release 构建通过，新测试包 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reading-minimal-fixes-release.apk`，65,349,064 字节（约 65.3MB），SHA-256 `dc00ac2363962ab1ca864566243f302934e7623b7b4becc62e61059243c0ac68`，与当前 `app-release.apk` 相同。已核对 `1.9.1`／code `40`、原包名 `com.example.litchi_journal_flutter`、无调试标记、三架构 AOT、APK v2 签名；证书 SHA-256 仍为 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`，可覆盖安装。arm64 AOT 校验值已确认不同于上一阶段 paper-segments 包，未误交旧构建。内部包仍为原 debug 签名，不用于商店；构建仅有既有 `package_info_plus` Kotlin 兼容提醒，没有升级依赖。构建日志 `/private/tmp/litchi-reading-minimal-apk-build-20261019.log`。

## 外观设置纸面三段选择（2026-10-19，未发布）

在原功能分支 `codex/reading-typography-20261018` 按用户最终确认替换胶囊滑块。仅客户端布局及其测试、文档改动，不改阅读页面、标签间距、设置存储、日记数据或服务端。版本仍为 `1.9.1+40`；本轮不写正式 CHANGELOG，不合并、推送、部署或装机。

外观与字号均使用原生 `SegmentedButton`，三等分、同宽同高、标签 14sp；正常视觉 40dp、热区 48dp，选中整格主题暖色实底且半粗，不显示勾号。移除旧 `appearance_capsule_controls.dart` 的圆点／轨道／拖动和滑移动画，页面私有尺寸及内容逻辑在 `appearance_segment_controls.dart`，只保留原生文字颜色的短过渡。减少动态效果或 Ticker 停用立即切换。保留控制器的实时更新、串行单字段保存与失败隔离回退；阅读档位仍为 14／16／18、默认 16，正文预览及 12dp 标签留白未变。

两组按外观最长标签实际换行高度统一增高，极大字体下图标可在格内上置，不缩字。实际中文渲染复核发现完整胶囊在 4 倍字体增高后变成椭圆，会裁掉左侧内容；先补失败断言，再改为固定 20dp 圆角。另补实际颜色断言复现：动画中途只改原生控件时长为零，仍会停留中间色；现在仅在减少动态效果／Ticker 状态变化时重建私有按钮子树，释放旧补间，设置控制器和滚动列表保持不变。失败复现日志为 `/private/tmp/litchi-paper-segments-rounding-red-20261019.log`、`/private/tmp/litchi-paper-segments-motion-red-20261019.log`。

浅深色普通字体与 3／4 倍字体共 6 张本地 Flutter 渲染已检查，无真实 Vault 或手机操作；不是本轮真机验收。截图在 `/private/tmp/litchi-paper-segments-{dark,light}-{1.0,3.0,4.0}.png`，渲染日志 `/private/tmp/litchi-paper-segments-preview-20261019.log`。

外观页 32 项通过，覆盖两组几何与不透明实色、点击不重复保存、横向拖动不切换、原生互斥／选中语义、字号数值朗读、颜色过渡中间帧及反向、减少动画、真实主题链路和持久化回归。浅深色 320dp 覆盖 1／1.3／1.6／2／2.5／3／4 倍字体，断言文字边界、等高和边缘点击。最终完整 Flutter 1021 项通过，静态检查零问题，`git diff --check` 通过；日志 `/private/tmp/litchi-paper-segments-full-tests-20261019.log`、`/private/tmp/litchi-paper-segments-analyze-final-20261019.log`，未运行远端 CI。

上一阶段正常入口 Release 构建通过，测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-paper-segments-release.apk`，65,349,064 字节（约 65.3MB），SHA-256 `5b9abbccc210e3e5dd561b5ad7fed74c438610e7013992c36b11aa09d88e1481`，不含后续阅读显示三处最小补修，不能当作最新 `app-release.apk`。已核对 `1.9.1`／code `40`、原包名 `com.example.litchi_journal_flutter`、无调试标记、三架构 AOT 和 APK v2 签名；证书 SHA-256 为 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`，与原安装身份一致。仍是 debug 签名内部包，不是商店包。构建日志 `/private/tmp/litchi-paper-segments-apk-build-20261019.log`，仅保留既有 `package_info_plus` Kotlin 兼容提醒，无依赖升级。中间的 `paper-segments-pre-review-release.apk` 不含减少动画补修，不作为验收包；其他旧命名包均保留。请用户自行覆盖安装并验收，本轮未合并、推送、部署或装机。

## 统一胶囊审核补修（2026-10-18，未发布）

用户要求审核并修复后再构建。固定审核范围为 `162610b...307ebfd`（胶囊更新本身），规范轴发现一项 P2，计划符合性轴未发现遗漏或越界。仍在 `codex/reading-typography-20261018`，不升版、不合并、不推送、不部署或装机，版本保持 `1.9.1+40`。

已用 Widget 回归在浅深色稳定复现：320dp、3 倍系统字体时，「跟随系统」与「浅色」热区重叠 67dp。原逻辑只防页面越界，端点内缩会进一步挤压居中选项。补修先检测自然宽度的相邻热区，仅不足时按分组三栏宽度重新测量并换行；两条轨道仍共用锚点，各组按自身标签高度自然增高，不把外观换行留白带入阅读组。未修改存储、服务、接口或阅读页。普通字体浅深色的本地 Flutter 渲染与修复前 SHA-256 完全一致，3／4 倍中文字体渲染也已检查；不是手机验收。

本轮新增 6 项（浅深色 × 2.5／3／4 倍字体），覆盖真实选项边缘点击、文字边界、热区独立、上下锚点和字号选择。修复前 3 倍回归失败，修复后完整 Flutter 1021 项通过，静态检查零问题，差异检查通过；双轴审查对补修再次只读复核，未发现新增阻断问题。最终日志 `/private/tmp/litchi-capsule-review-full-tests-20261018.log`、`/private/tmp/litchi-capsule-review-analyze-final-20261018.log`，复现日志 `/private/tmp/litchi-capsule-review-red-20261018.log`。

审核补修 Release 构建通过，上轮包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-appearance-reviewed-release.apk`，65,447,368 字节（约 65.4MB），SHA-256 `1e3141395c8e52aa3652aeadec152337f24f7fd478216c483e6cbc97bfa8b7b4`，不包含最新纸面三段按钮，不能当作当前 `app-release.apk`。已核对 `1.9.1`／code `40`、原包名 `com.example.litchi_journal_flutter`、无调试标记、三架构及 APK v2 签名；证书 SHA-256 仍为 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`，可覆盖安装。构建仅保留既有插件兼容提示，没有升级依赖。下方旧包保留，不含超大字体防误触补修；真机仍由用户安装验收，未合并、推送或装机。

## 外观设置统一胶囊（2026-10-18，未发布）

继续使用 `codex/reading-typography-20261018`，用户确认效果图后授权实施、验证和构建测试 APK；仍不升版、不合并、不推送、不部署或装机，清单为 `1.9.1+40`。本轮只改客户端外观页、Flora 图标映射及文档，不改变设置存储格式、阅读页面间距或任何 API／Markdown／服务端行为。

外观模式收拢为显示器／太阳／月亮三态胶囊，点击图标或文字选择；阅读字号仍为 14／16／18、默认 16，点击或拖动吸附。两条轨道同宽、24dp 高，共用锚点和标签测量；正常字体端点内缩 14dp、中档居中，20dp 外观圆底与 18dp 字号滑块均在轨道内。热区至少 48dp，大字体按标签实际宽度同步内缩，不重叠、不缩字；预览并入字号分组，移除嵌套边框及重复状态说明。`appearance_capsule_controls.dart` 是页面私有 part，复用原有控制器、串行保存及字段隔离回退。点击使用 `FloraMotion.fast`，拖动跟手，反向从当前进度转向，减少动态效果／Ticker 停用立即完成。

本轮新增 9 项回归，最终完整 Flutter 1015 项通过，静态检查零问题，差异检查通过。覆盖实际主题链路及系统亮度变化、图标／文字点击与重复选择、轨道尺寸和锚点、动画中间帧／反向／立即完成、拖动跟手、键盘及无障碍、保存失败回退；强化浅深色 320dp／1.3、1.6、2.0 倍字体下的标签边界和热区不重叠断言。用临时内存配置渲染浅深色 Flutter 截图检查，不连接真实 Vault；这些是本地渲染，不是真机截图。最终日志为 `/private/tmp/litchi-appearance-full-tests-final-20261018.log` 和 `/private/tmp/litchi-appearance-analyze-final-20261018.log`。

上轮正常入口 Release 包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-appearance-capsules-release.apk`，65,447,368 字节（约 65.4MB），SHA-256 `df76c7b2987dc5f928dbea7a26ef9a1afb81381b0e19b19ff85871d8118675a3`。已核对版本 `1.9.1`／code `40`、原包名、无调试标记、三架构及 APK v2 签名；证书 SHA-256 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`，与前轮一致，可覆盖安装。构建保留既有 `package_info_plus` Kotlin 插件兼容提示，不影响构建；没有升级依赖。此包不含随后审核的超大字体防误触补修，不能当作当前 `app-release.apk` 或最新验收包；本轮未安装、未运行云端 CI。

## 阅读字号调整（2026-10-18，未发布）

当前功能分支 `codex/reading-typography-20261018` 从干净的 `main` 提交 `12c424b` 建立。用户仅授权实施、验证和构建测试 Release APK，不包含升版、合并、推送、服务端部署或装机；清单保持 `1.9.1+40`，CHANGELOG 留待正式发布。本轮只修改客户端，不需要为字号功能重新部署 API。

已实现：真机反馈 18sp 正文偏大且缺乏标题层级后，用户确认小／中／大对应 14／16／18sp，默认中档 16；外观页改为 iOS 风格三档吸附滑动条及实时正文预览，朗读实际档位并可逐档增减。复用外观仓储并按顺序单字段写入，连续切换最后选择生效，失败仅恢复对应字段的最近成功值；旧无字段／非法字号默认 16，保留原主题和已保存合法字号。`DiaryReadingStyle` 保留其他主题扩展并覆盖各类日记阅读路径，不修改全局 `bodyMedium`、输入正文、TagPicker、习惯列表或 Dock。阅读标题 18、时间标签 14、操作与确认说明 16；设置行从固定 56 改为最小 56dp。系统字体继续放大，时间列随真实宽度调整并保持统一列宽。

用户同时反馈标签紧贴正文。间距回归先复现“预期 12dp，实际 2dp”，再把三类阅读条目及自定义时间条目的正文到标签调整为 12dp；照片到标签仍为 12dp，不重复叠加。标签菜单及加载反馈保持首行对齐、48dp 热区，末条时间轴跟随新的实际标签底部收尾。照片尺寸、Parser 及所有写入逻辑保持不变。

本功能相对主线新增 74 项回归，完整 `flutter test` 1006 项通过，`flutter analyze` 零问题，`git diff --check` 通过。覆盖三档／旧配置／非法值、重启、串行与交叉字段失败、原生滑动手势与无障碍逐档调整、即时预览、今天／历史各阅读路径、切换不请求或跳顶；覆盖浅深色、320dp 与 1.3／1.6／2.0 倍系统字体、菜单确认与输入隔离，以及 1／2／9 张照片、12dp 正文／照片到标签、换行标签和连续时间轴。所有请求使用测试替身，不接触真实 Vault。

上阶段正常入口 Release 测试包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reading-three-sizes-release.apk`，65,364,562 字节（约 65.4MB），SHA-256 `ab550f277796705a93c7e5e0af4cc1c3a06a270673f5cb542ba8d48834cf882d`。已核对 `1.9.1`／code `40`、包名 `com.example.litchi_journal_flutter`、无调试标记及三架构；APK v2 签名有效，证书与此前测试包一致，支持覆盖安装。此包包含三档滑动条、默认 16sp 和 12dp 正文标签留白，但不包含后续统一胶囊；新的 `app-release.apk` 由后续构建更新。

首轮两档阅读测试包 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reading-typography-release.apk` 保留，65,348,178 字节，SHA-256 `3e5383f7bd98efbd8d2724993cfb9c2939b5ba7c4148bb9faec54743e2310a2d`；不包含随后三档滑动条与 12dp 标签间距修正。该包 `1.9.1`／code `40`、原包名、无调试标记、三架构 AOT 和 APK v2 签名已核对。新的测试产物另行命名，不能再把旧包当作当前 `app-release.apk`。构建提示既有 `package_info_plus` Kotlin 插件兼容性警告，不阻断当前构建，后续 SDK 升级另行处理。

本轮未升版、合并或推送，也未运行云端 CI、部署或安装真机。PLG110 的安装与浅深色／大字体验收由用户进行，旧截图和旧 APK 不作为本轮验收证据。

## 上一轮可靠性补修背景

### 状态与范围

2026-10-18，交付源功能分支 `codex/reliability-followup-20261018`，从 `main` 提交 `c35ab1b` 建立；沿用用户本会话已授权的 squash 合并、内部 Release 构建与推送流程交付主线。用户确认先补 CI／非时间完整匹配／图片数据校验，再一起完成性能优化和旧代码整理。清单仍为 `1.9.1+40`，沿用现有 Android 包名和签名；不部署真实服务端、不安装手机、不迁移正式应用身份。

### 该轮实现

CI：首次主线 run 39075113504 的 Flutter 通过，服务端因测试写死 `/private/tmp` 在 Ubuntu 遇到 EACCES。三个实际文件写入 fixture 改用 `node:os.tmpdir()` + `mkdtempSync()`，只读 mock 不再引用平台绝对路径；不创建 CI 特权目录或依赖本机私有配置。

写入：服务端非时间记录也先确定完整条目边界，再核对 rawLine；只传首行或独立续行均 404，完整记录才允许修改／删除。覆盖列表、引用、Callout、checkbox 和图文关联；照片后手写说明保持独立。`imageData` 非字符串或空白时提前 400，不创建附件目录，不读取或修改日记。

性能：过往页已访问分页按每批最多 3 个并发刷新，保留全部访问清单；同批按原游标顺序合并，避免响应乱序使旧图片复活。认证失败立即结束当前刷新，不再排后续批次；页面移除或请求代次变化后不应用旧结果。

清理：服务端启动后异步检查日记年月目录，只删除超过 24 小时、符合本程序日期＋UUID v4 临时命名、且与现存非空日记字节完全一致的副本。不跟随文件或目录符号链接；原文缺失／为空、内容不同、元信息变化或读取异常时保留。内容不同的临时文件可能包含崩溃前未提交记录，不能按扩展名一概删除；清理失败只记固定提示，不阻断 API 启动。

旧代码：移除无生产读取调用的 `HabitStatsService`、固定 key 的 `HabitStatsCacheRepository`、旧页面兼容缓存参数、仅被旧服务使用的并发工具，以及 `HabitHeatmapTabs`／`HabitRhythmGrid`／`HabitSummaryCard`／`MemoryCard`。保留当前趋势页需要的每日快照、习惯分组和追踪类型模型，API 写入继续使当前趋势缓存失效。删除仅验证旧实现的 21 项测试，保留全部当前趋势页用例和每日快照序列化测试。

### 该轮验证与交付

新增服务端 19 项：12 项输入／非时间块边界、7 项临时副本清理；完整 `npm test` 146 项及 `npm run build` 通过。新增 Flutter 4 项真实过往页回归：六分页两批请求、最多三并发、乱序合并、认证失败及离开停止。完整 `flutter test` 932 项（949 - 21 + 4），`flutter analyze` 零问题。本轮所有文件操作测试只使用独立临时目录，不读取真实 Vault。

功能分支提交 `41c2b21` 的 [云端 CI 39076319336](https://github.com/iaimer/litchi-journal/actions/runs/39076319336) 已全部成功：Ubuntu 服务端测试及构建、Flutter 静态检查及完整测试、差异与锁文件检查均通过。首次主线 CI 的跨平台路径失败已在真实 Ubuntu runner 修复。

上一轮正常入口 Release 构建通过，包 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-followup-release.apk`，65,331,794 字节（约 65.3MB），SHA-256 `ff01b2ad031e833a4fac794ed15a260cc18891c33b103fc5317508ab208de0a1`。版本 1.9.1 / code 40、原包名、无调试标记与 Release AOT 已核对；APK v2 验证通过，证书与此前包一致。arm64 AOT 已确认不同于此前 reliability 包，支持 `adb install -r` 覆盖安装；不包含本轮阅读字号调整，后续 app-release.apk 会随新构建更新。

此前主线可靠性包 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reliability-release.apk` 不包含本轮补修，不得当作最新产物。原包为 65,331,794 字节，SHA-256 `465f02e7e605988524a0a0abdeb5a7b4f2664e8f5598779e5854c5ef6e5129fd`；旧 `litchi-journal-1.9.1-release.apk` 更早。构建与覆盖安装步骤见 [发布说明](docs/RELEASE.md)。本机没有完整 Xcode，iOS 未构建或装机；默认 Android 内部 Release 沿用 debug 证书，不是商店正式包。

第一轮三批及残留补修已在 `c35ab1b` squash 进入主线：日记原子替换、习惯增量更新、正文与操作标记同次提交、保守附件删除、计时持久幂等重试、输入与草稿保护、按尺寸图片、凭据隔离和画廊访问清单。旧 `.diary-ops.json` 只读兼容，损坏且不能确认操作状态时拒绝重放，不能删除它绕过保护。仍需用户部署新版 `server/` 并覆盖安装当前客户端才能完整生效；不提供离线写入、自动补交、外部编辑冲突合并或新的备份产品。

更早背景见 [交接档案](docs/archive/HANDOFF-20261018-before-reliability-cleanup.md)。`SESSION_LOG.md` 继续只读，不追加历史流水。
