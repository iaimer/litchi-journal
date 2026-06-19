# Flora UI 重构整合计划

> 来源整合：`/tmp/flora-handoff-to-codex.md`、`/Users/yezi/Downloads/DESIGN_SPEC.md`、`/Users/yezi/Downloads/DESIGN_PLAN_NEXT.md`、当前 Flutter 实现。
>
> 状态：执行版计划。后续 UI 改动以本文档为准。

## 1. 统一判断

荔枝日记是以日记为核心的个人成长 App。UI 目标是温暖、平静、有生命力、克制、不说教。它不是 Web 版复刻，也不是效率工具或任务管理器。

### 1.1 当前品牌资源状态

截至 2026-06-20，品牌源图已经收口到 `docs/design-reference/`：

- `splash.png`：启动页源图，派生为 `assets/icon/brand-splash-reference.png`。
- `icon.png`：App 图标与关于页品牌图源图，派生为 `assets/icon/app-icon.png`、`assets/icon/app-launcher.png` 和 Android launcher mipmap 资源。
- `reference.png`：整体视觉参考图，仅用于比对设计方向。

后续不要重新绘制或 AI 生成近似品牌图。启动页、桌面图标和关于页品牌图都应从以上源图派生。

当前三份设计资料的关系如下：

- `DESIGN_SPEC.md`：保留颜色、排版、间距、卡片、输入区、深色模式规则。其 Material Icon 替换方案属于 Phase A 过渡方案，不再作为最终方向。
- `DESIGN_PLAN_NEXT.md`：保留 Phase B-E 路线。Phase B/C 的大部分内容已经在仓库落地，后续只做收尾与验收。
- `flora-handoff-to-codex.md`：作为当前状态来源。P0 是品牌系统收口，P1 是启动页与空状态验收，Phase D/E 暂缓。

当前设计方向以 Flora 自定义 SVG 图标、品牌 PNG App Icon、`FloraIcon`、`FloraEmpty`、`FloraSplash` 和现有 `AppTheme` 为准。

## 2. 有效设计规则

### 2.1 视觉原则

- 页面只服务当前任务：今天页展示和记录，过往页回看，习惯页统计，设置页管理。
- 装饰必须服务信息层级或品牌表达，不做纯装饰。
- 保持系统字体，不引入自定义字体。
- 色彩策略为克制型：暖灰背景、纸感表面、荔枝棕 accent，强调色每屏少量使用。
- 深色模式不是反色，而是深暖灰底、低刺激对比、重点内容清楚可读。

### 2.2 Token 与组件基线

- 颜色、间距、圆角继续使用 `lib/theme/app_theme.dart` 中的 `AppColors`、`FloraSpacing`、`FloraRadius`。
- 图标继续使用 `lib/widgets/flora_icon.dart`，不要回退到 emoji 或批量引入 Material Icon。
- 空状态继续使用 `lib/widgets/flora_empty.dart`，文案保持温柔提示，不使用「暂无数据」。
- 启动品牌页使用 `lib/widgets/flora_splash.dart`，不引入 Lottie、Rive 或额外动画依赖。
- 日记领域组件继续消费领域模型，不把 Markdown 当 UI。

### 2.3 已被取代的旧规则

- `DESIGN_SPEC.md` 中“完全替换为 Material Icons”的规则已过期。
- 空状态使用 `Icons.inbox_outlined` 等 Material 图标的规则已过期，改用 Flora 品牌 SVG。
- 关于页“不是什么工具”式文案已被用户否定，后续使用正向品牌语句。
- Phase D 动效和 Phase E 成长体验暂缓，不在当前 UI 重构首轮实现。

## 3. 实施路线

### Phase 0：品牌系统收口与基线提交

目标：把当前未提交的品牌系统改动收成一个稳定基线，避免后续 UI 重构和历史改动混杂。

执行内容：

- 确认 App Icon 已使用清理黑角后的 `assets/icon/app-icon.png`。
- 确认 Android `ic_launcher.png` 与 `ic_launcher_foreground.png` 已使用 18% 安全留白版本。
- 真机重装验证桌面图标、关于页品牌图、关于页文案。
- 验收 4 个空状态：过往为空、搜索为空、标签为空、习惯为空。
- 通过后提交当前品牌系统收尾改动。

验收标准：

- 关于页图标无黑角。
- 桌面 App 图标主体不再过满。
- 关于页显示「记录生活中的成长轨迹」和「把每天的小事慢慢照亮」。
- `flutter analyze --no-pub`、`flutter test --no-pub` 通过。

### Phase 1：接入 FloraSplash

目标：补齐 Flutter 内部品牌启动过渡，避免进入 App 后缺少品牌表达。

执行内容：

- 在 `main.dart` 中接入 `FloraSplash`。
- 冷启动流程为：原生 Splash → Flutter `FloraSplash` → `AppEntry`。
- `FloraSplash` 显示时长建议 1.2-1.6 秒；配置读取完成更早时也至少展示短暂品牌过渡。
- 保持 SetupScreen、MainScreen、主题切换、API 配置加载逻辑不变。

验收标准：

- 已配置用户最终进入 MainScreen。
- 未配置用户最终进入 SetupScreen。
- 浅色和深色模式启动页都可读。
- 不出现无限转圈、不影响配置加载超时保护。

### Phase 2：页面骨架统一

目标：统一一级页和二级页的安全区、标题、滚动、底部留白，减少页面间割裂。

执行内容：

- 抽出轻量页面容器，例如 `FloraPageScaffold` 或等价小组件。
- 覆盖一级页：`HomeScreen`、`PastScreen`、`HabitStatsScreen`。
- 覆盖二级页：设置页与设置子页、`QuickCaptureScreen`、`AnxietyScreen`、`ReadOnlyDiaryScreen`。
- 标准化：SafeArea、页面 padding、AppBar、滚动底部留白、Dock/FAB 避让。

边界：

- 不改业务逻辑。
- 不改 API。
- 不改页面路由结构，除非只是为了修正页面容器一致性。

验收标准：

- 顶部不与状态栏重叠。
- 底部内容不被 NavigationBar 或 FAB 遮挡。
- 一级页标题层级一致。
- 二级页 AppBar 风格一致。

### Phase 3：卡片和内容组件统一

目标：统一日记阅读体验，但不改变内容结构或 Markdown 原文。

执行内容：

- 保留 `SectionCard` 基础规格：12px 圆角、0.5px 描边、surface 背景、16px 内容 padding。
- 逐步检查 `HabitCard`、`QuickNoteTimeline`、`AnxietyCard`、`GenericSectionCard`、`ImageSectionCard`、`MemoryCard`。
- 卡片 header 使用统一标题、图标、trailing 规则。
- 谨慎处理左侧 2px 强调线：普通内容卡片可以弱化或移除，提醒类/教练类卡片可保留强调。
- 时间、标签、正文行高按 `DESIGN_SPEC.md` 保留：正文 14px / 1.6，标签和时间使用 11-12px。

边界：

- 不修改 Parser。
- 不修改 `polisher_service.dart`。
- 不修改任何 Markdown 写入格式。

验收标准：

- 日记各 section 视觉节奏一致。
- 深色模式下正文、标签、输入答案都清楚可读。
- 过往页记忆卡与今日页内容卡片属于同一视觉语言。

### Phase 4：输入体验统一

目标：让随手记、小确幸、觉察、焦虑四问和编辑面板的输入体验一致。

执行内容：

- `QuickCaptureScreen` 保持二级页形态：AppBar、时间选择、输入区、标签区、润色、底部保存。
- `AnxietyScreen` 保持独立二级页，保留逐问润色。
- `EntryEditSheet` 保持底部面板，统一输入框、标签选择、取消/保存按钮。
- 输入框统一使用主题 `InputDecorationTheme`，避免硬编码浅蓝、纯白或低对比背景。

验收标准：

- 深色模式输入区文字可读。
- 键盘弹出不遮挡保存按钮。
- 保存、润色、失败提示行为不回归。

### Phase 5：空状态、加载态与错误反馈

目标：把空、加载、失败从“工程状态”改成 Flora 语气的产品状态。

执行内容：

- 空状态统一由 `FloraEmpty` 渲染。
- 加载态优先用局部 skeleton 或轻量文字，不在整页中心长期转圈。
- 错误反馈使用平静、可操作文案，例如「出了点小问题，再试一次？」。
- 不扩展新插画，本轮只使用已存在的 4 个空状态 SVG。

验收标准：

- 首页空日记仍可显示习惯卡并允许打卡。
- 过往搜索无结果显示 `emptySearch`。
- 标签和习惯为空时可见对应空状态。
- 错误文案不暴露 token、URL、异常堆栈。

### Phase 6：Motion 与 Growth 暂缓

目标：先记录方向，不进入实现。

后续动效点：

- FAB 展开/收起的轻量 stagger。
- 保存成功反馈。
- 习惯打卡反馈。
- 标签选择反馈。

后续成长体验：

- 30 天成长总结。
- 温和里程碑。
- 不制造焦虑的趋势回看。

本阶段不引入新依赖，不做 Lottie/Rive/Hero，不做增长型功能。

## 4. 首轮推荐任务

第一轮只做 Phase 0 + Phase 1。

顺序：

1. 验证当前品牌资源与关于页。
2. 提交品牌系统基线。
3. 接入 `FloraSplash`。
4. 补充启动流测试。
5. 真机安装验证。
6. 提交 Splash 接入。

首轮不做：

- 页面骨架大范围重构。
- 卡片样式全面调整。
- 动效系统。
- Growth Experience。
- 服务端和 Markdown 改动。

## 5. 测试与验收

每个 Phase 至少运行：

```bash
/Users/yezi/development/flutter/bin/flutter analyze --no-pub
/Users/yezi/development/flutter/bin/flutter test --no-pub
```

涉及原生图标、启动页或视觉体验时，还需：

```bash
/Users/yezi/development/flutter/bin/flutter build apk --release --no-pub
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

真机验收重点：

- PLG110 Android 16。
- 浅色/深色模式各看一次。
- 首页、过往、习惯、设置、关于页、快速记录、焦虑四问都至少打开一次。
- App 图标变化必须重装 APK 后查看，必要时清理启动器缓存或重启桌面。

## 6. 后续 Agent 注意事项

- 不要把 `DESIGN_SPEC.md` 的 Material Icon 方案当作当前目标。
- 不要重新引入 emoji。
- 不要为了统一 UI 修改服务端、Markdown 或数据模型。
- 不要扩大到 Phase D/E，除非用户明确启动。
- 当前仓库可能有未提交品牌系统改动，实施前必须先看 `git status -sb`。
- 修改视觉时优先改公共组件，避免每个页面单独堆样式。
