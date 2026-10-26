# 当前交接

## 三种记录输入提示统一（2026-10-26，功能分支实施）

`codex/consistent-record-placeholders` 从已推送的 `main` 提交 `bcf7a8b` 建立。随手记占位文案为「有什么想记下来的？／一句话也可以。」；小确幸为「有什么让你开心的小事？／记下那个瞬间就好。」；觉察三问不变。三者共用原生占位样式：13sp、常规字重、1.7 行高、浅色 50%／深色 65% 透明度、高对比度完整颜色；输入后立即隐藏、清空恢复，不保留提示高度。无 API 或存储修改，版本保持 `1.9.2+41`。

新增随手记空白提示回归先在旧实现失败，然后完成客户端修改。新建、编辑和历史补录的输入／清空、浅深色与高对比度、320dp／1～3 倍字体、草稿和提交均通过；完整 Flutter 1177 项、`flutter analyze --no-pub` 无问题。`build/record-placeholder-preview/` 有三种记录 × 浅深色 × 空白／已输入，共 12 张实际 Flutter 本地预览，已核对两种新增提示的空白与输入状态；不是本轮真机截图。用户随后授权构建、合并和推送：已构建 `build/app/outputs/flutter-apk/litchi-journal-1.9.2-record-placeholders-release.apk`（SHA-256 `ed1f840f5791118e2eab92a75ca0bbc1c82619a1371c3e3c28e1e9db6be4f344`），并完成主线交付；未部署服务端。

## 恢复觉察、小确幸时间轴（2026-10-26，本地完成，已审核修复）

功能分支 `codex/consistent-entry-timeline` 从 `5d6c74a` 开始。两个模块的时间一直保存在日记中，本轮移除隐藏时间的列表分支，直接复用随手记 `JournalTimelineRow`；今天和历史详情生效。相邻时间记录连接，遇到领域模型中的 Markdown 正文、Callout 或小标题断开；无时间旧正文保留，不改写原文件。Parser 对时间记录后未缩进正文的既有多行归属保持不变，混排回归使用明确分隔表示独立旧正文。

新增三模块显示回归先因缺少觉察时间失败；既有阅读布局基线 74 项通过。恢复后针对性阅读、编辑、删除与布局 517 项通过，真实页面浅深色 4 项通过。三档字号和真实 320dp 元信息下 1／1.3／2／3 倍字体均验证时间、12dp 标签间距和末条收尾；迁移的 4 倍字操作回归也通过。共享时间轴原有固定 72dp 避让在 3 倍字产生 17px 溢出，已按实际宽度收敛；无法并排时上下排布，标签和操作必要时换行。

双轴审核已完成并复核。规范轴发现内容遍历四层嵌套，改为提前返回及 continue，现最多三层；需求轴核对超大字体上下排布发现节点遮挡时间和多条竖线间断，均先补失败回归再修复。节点按真实时间高度偏移，时间左缩进避开竖线，非首条竖线从行顶连续连接，末条仍在实际标签底部结束。相关 88 项通过，最终完整 Flutter 1147 项、`flutter analyze --no-pub` 与 `git diff --check` 通过，两轴最终未解决问题均为 0。

实际 Flutter 本地预览在 `build/consistent-entry-timeline-preview/`，today／history × light／dark，共 4 张；390dp，测试显式提供中文字体，不是 PLG110 真机截图。测试阴影和个别按钮文字的字体覆盖与实机存在差异，三个记录模块已逐项核对。

用户随后授权构建并确认已装机。已从功能分支代码 `51971db` 的正常 `lib/main.dart` 入口构建内部 Android Release：`build/app/outputs/flutter-apk/litchi-journal-1.9.2-consistent-entry-timeline-release.apk`，65,332,756 字节，SHA-256 `3720c324d0c74342beb1ce6bb36fae0a59f893d7aec2e4a42aad441664bccaa0`。核对版本 `1.9.2+41`、原包名 `com.example.litchi_journal_flutter` 与原 Android Debug 证书（SHA-256 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`），APK v2 签名通过，可覆盖安装；构建只有既有 KGP 迁移提示。当前开始合并并推送；未部署。先前的 `startup-record-fab-release.apk` 不包含本轮时间轴更新。

## 冷启动加号变淡修复（2026-10-26，本地完成）

在 `codex/fix-startup-record-fab` 修复用户报告的启动期间加号变透明：首页用 `_verified ? 1 : 0.4` 将整组记录入口透明度绑定到日记联网确认状态，导致启动至请求成功前只有 40% 不透明度。移除这层 `Opacity`，保留原有 `IgnorePointer`、语义与联网写入边界；菜单展开时隐藏加号的独立规则保留。版本升至 `1.9.2+41`，已 squash 合并至 `main` 并推送。

新增真实 `MainScreen` 延迟日记响应回归，先复现实际绘制透明度 0.4，再确认初始帧、等待期间与响应后均为 1；同时验证响应前无法展开、成功后正常展开。该回归通过，完整 Flutter 1111 项、`flutter analyze --no-pub` 和差异检查通过。

内部 Android Release 包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.2-startup-record-fab-release.apk`，65,332,756 字节，SHA-256 `2d65fb68d305ac1d9479da916c8b26f568829c379a54d1b277f2fa7228ef105d`。包名 `com.example.litchi_journal_flutter`，versionCode 41；APK v2 签名验证通过，沿用原 Android Debug 证书 SHA-256 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`，可用于同身份覆盖安装，不是商店正式签名包。构建输出既有 `package_info_plus` Kotlin Gradle Plugin 迁移提示，构建成功。已推送 `main`；未装机或部署。

## main 交付：觉察整合与竖排记录菜单（2026-10-26）

用户授权合并、构建和推送后，功能分支 `codex/reflection-integration` 已 squash 合入 `main`。合并前验证：完整 Flutter 1110 项通过，`flutter analyze --no-pub` 无问题；服务端 160 项通过，`npm run build` 成功；`git diff --check` 通过。版本保持 `1.9.1+40`。

从该主线代码构建的内部 Android Release APK：`build/app/outputs/flutter-apk/litchi-journal-1.9.1-reflection-vertical-menu-release.apk`，65,332,680 字节，SHA-256 `0d029d99e810044b85e753fdd449974ec6e483ab275a09f173f8f1f601fb58d2`。包名 `com.example.litchi_journal_flutter`，versionCode 40；APK v2 签名验证通过，沿用原 Android Debug 证书（SHA-256 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`），可用于同身份覆盖安装，不是商店正式签名包。构建输出了既有 `package_info_plus` Kotlin Gradle Plugin 迁移提示，构建成功。

本轮交付后已核对本地 `main` 与 `origin/main`。未装机、未部署 API 服务；新日记模板移除焦虑段的行为需服务端部署新版后生效。PLG110 真机验收未执行。

## 竖排菜单二轮复审（2026-10-26，已修复并复核）

用户要求再次审查后，规范轴未发现新问题；需求轴发现两项并补回归复现：历史菜单自动继承 `PrimaryScrollController`，展开后同一控制器绑定正文与菜单两个 position；同帧两次外部 pointer-down 通过 toggle 先关闭再重开。菜单已设置 `primary: false` 独立滚动，将菜单及历史包装组件回调改为 `ValueChanged<bool> onExpandedChanged`，主加号请求 true、外部请求 false，两父页直接赋值。保持视觉、保存、目标日期与缓存行为。针对性菜单／实际页面／导航／背景 119 项通过，最终完整 Flutter 1110 项通过、`flutter analyze --no-pub` 零问题、`git diff --check` 通过。两路审核均复核修复，无未解决项。仅本地修复提交，不构建、装机、推送或部署。

## 今天与历史补录竖排菜单（2026-10-26，本地完成，未构建）

按用户确认计划在 `codex/reflection-integration` 实施：今天与历史详情共用竖排图文菜单（小确幸／觉察／随手记），加大图标、整行可点，展开隐藏加号，无关闭按钮；点击外部关闭，正文模糊和遮挡立即移除，加号恢复。历史补录使用原目标日期，过往画廊无入口；不改 API、存储、版本。当前基点 `c71dc7d`，交付限本地提交，不构建、装机、推送、合并或部署。已完成实现、本地渲染与双轴代码审核。规范轴发现新增测试 `_host` 超过 50 行，拆出动作夹具后为 48 行并经审核复核；需求轴未发现缺失、范围蔓延或实现错误，当前未解决项均为 0。最终复验完整 Flutter 1108 项、静态检查与 diff 检查均通过。

现有菜单 11 项基线通过；新增图文标签回归先在旧实现失败，再替换共用组件。针对性菜单／导航／记录测试 447 项通过，实际页面主题与 320dp 下 1／1.3／2／3 倍字体矩阵及历史返回 33 项通过。修复外部按下先关闭菜单、PopScope 尚未同步导致历史顶部返回需点两次的问题；更新与本轮即时恢复正文要求冲突的旧背景退场断言。完整 Flutter 1108 项通过，`flutter analyze --no-pub` 零问题，`git diff --check` 通过。仅客户端变化，不重跑服务端测试，不访问真实 Vault。

8 张真实 Flutter 本地预览在 `build/quick-record-menu-preview/`：today／history × light／dark × open／closed，390dp，测试显式传入中文字体；已检查展开时仅正文模糊和收起后正常阅读。不是 PLG110 真机验收，不包含在前轮已构建 APK 中。菜单本身另测超高内部滚动；实际页面 3 倍字矩阵使用无时间正文以隔离已有时间轴行的 17px 超大字溢出，未扩大本轮修改范围，不代表整页所有旧阅读组件均通过 3 倍字验收。

## 觉察三问改为空白输入提示（2026-10-26，本地完成，未重新构建）

本轮按用户确认计划替代前轮「给点提示」按钮与展开面板：空白觉察使用原生 `hintText` 显示三问，每问一个换行；输入后立即隐藏，清空后恢复。13sp、常规字重、1.7 行高，主题 `onSurfaceVariant` 浅色 50%、深色 65% 不透明度，系统高对比度使用完整颜色。实际正文及光标仍为 16sp，随手记和小确幸保持原样。

删除展开状态、专用 key、修订号和提示定位逻辑；共用编辑器、滚动控制器、照片定位、保存及缓存失效流程保留。提示不写 controller，不占用输入后的高度，不进入草稿、保存或润色请求；今天新建、编辑、历史补录及草稿恢复共用此行为，正文到已选标签继续为 12dp。

先运行旧提示 15 项基线并通过，再新增三问占位回归，确认因旧长文案而失败后实现。新提示针对性 32 项通过，覆盖输入／清空、有效光标与输入法组合区、草稿、提交、浅深色与高对比度、320dp 下 1／1.3／2／3 倍字体和标签键盘过渡。完整 Flutter 1060 项通过，`flutter analyze --no-pub` 无问题，`git diff --check` 通过；8 项实际预览导出通过并已核对浅深色、输入前后及大字换行。本轮只有客户端和文档变更，未重新运行服务端测试，也未运行云端 CI。

真实 Flutter 本地预览在 `build/reflection-placeholder-preview/`，浅深色各含空白／已输入状态，覆盖 390dp／1 倍与 320dp／2 倍，共 8 张；仅测试显式注入中文字体，未改产品字体。这些不是 PLG110 真机验收。当前版本仍为 `1.9.1+40`；本轮不构建 APK、装机、推送、合并或部署。下述已经交付的 `reflection-integration-release.apk` 不包含本轮三问占位更新，需后续另行授权构建。


## 焦虑入口收拢与觉察提示（2026-10-25，功能分支未发布）

以下保留前轮构建与兼容修复记录；展开式提示已由三问占位替代，扇形角度已由今天与历史共用竖排菜单替代。

本轮在 `codex/reflection-integration` 修复上一轮审查发现的问题：App 结束焦虑四问新建、补答和编辑；新建日记模板删除焦虑段，已有文件（包括今日日记）不迁移、不重写。旧焦虑仍只读，用户可在 Obsidian 修改。服务端旧接口保留兼容；缺少焦虑章节时写在每日复盘前，替换已有章节时只保留原有分隔符，手写文件没有分隔符时不补写，重复替换不改变结构。新模板需部署新版 `server/` 后才实际生效，本轮未部署。

今天三个入口为随手记／觉察／小确幸，角度 180／142.5／105、半径 150dp，历史补录不变。觉察增加默认收起的「给点提示」，仅显示静态思考问题；展开时若提示在视口外会自动滚入可见区域，提示用轻微纸面底色与 12dp 圆角区别于正文。快速收起会取消定位动画；正文、光标、输入法连接和标签保持不变，不调用 AI、不进入正文或草稿。开合按钮名称、点击和展开状态在同一无障碍节点。

旧焦虑解析统一在 Parser 层，`AnxietySection.contents` 是唯一的不可变有序来源，卡片、空内容判断和回顾答案都从中派生。兼容旧写入器“首行引用、后续行不带引用符”的多行正文；Callout 保持独立，问答与旧正文按原序展示。标准问题使用领域枚举，回顾取每题最后一个非空回答；未知旧问题仍可读，非问答正文不进入 AI 上下文。解析器用独立 reader 方法分别处理逐行读取、问题收尾与正文收尾，各方法少于 50 行。旧模板、新模板由 Flutter 与服务端测试共用 `test/fixtures/diary_templates.json`；服务端测试因此依赖仓库根目录布局，单独抽离 `server/` 时须一并迁移夹具并更新引用路径，本轮接受这项测试布局依赖。

先让新增回归分别复现旧多行回答丢失、Callout 混入答案、长正文下提示不可见，以及服务端插入位置／分隔符错误，再修复。后续补充精确全文断言，先复现手写文件被额外补入分隔符，再修复。最新完整 Flutter 1043 项通过，`flutter analyze --no-pub` 无问题；服务端 160 项通过，`npm run build` 成功。新旧完整模板均覆盖“只改习惯仍隐藏、加入正文后显示、移除后再次隐藏”；服务端还覆盖新模板首条觉察写入、已有文件重复创建字节不变、旧接口插入和替换结构。觉察预览字体由显式参数提供；与本任务无关的习惯动效预览字体调整已撤回，该文件与上一轮审查修复前一致。`git diff --check` 通过；本轮未运行云端 CI。

本地 Flutter 截图位于 `build/reflection-preview/`，覆盖浅深色 390dp／1 倍及 320dp／2 倍字体；仅预览时通过参数注入中文测试字体，未改产品字体。截图不是 PLG110 真机验收。用户于 2026-10-26 确认角度与固定提示文案为已批准的规格调整，并授权推送 `codex/reflection-integration` 功能分支；远端与本地代码提交均核对为 `62833da`。清单仍为 `1.9.1+40`，未装机、合并或部署，也没有读取真实 Vault 或私有服务端配置。

用户随后授权先构建 App。已从 `62833da` 使用正常 `lib/main.dart` 入口构建内部 Android Release，安装包为 `build/app/outputs/flutter-apk/litchi-journal-1.9.1-reflection-integration-release.apk`，65,349,064 字节，SHA-256 `8fe211de70239c584db867df9339c624d68f6fd00afb4a93be396b5d68a99b0f`，与当前 `app-release.apk` 一致。核对 `1.9.1+40`、原包名 `com.example.litchi_journal_flutter`、无调试标记、三架构 AOT 和 APK v2 签名；证书 SHA-256 与上一包相同，仍为 `4b15b79943c8e123ab288bfcb76e6235d59cc265b9e56e40660eb69af499c433`，支持覆盖安装。arm64 AOT 与上一轮 reading-minimal-fixes 包不同，确认本次产物包含新代码。构建只有既有 `package_info_plus` Kotlin 兼容提醒；未升级依赖。构建记录仅本地提交，本次未再次推送；服务端待部署，新模板尚未线上生效。


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
