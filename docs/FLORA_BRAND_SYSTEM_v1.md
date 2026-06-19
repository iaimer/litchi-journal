# Flora Brand System v1

> 荔枝日记（Flora）品牌视觉设计规范
>
> 版本：v1（草案 · 待确认后进入 SVG 设计）
> 日期：2026-06-19
> 依赖：Phase A（Theme System）· Phase B（SVG Icon System）

---

## 目录

1. [Illustration Style Spec](#1-illustration-style-spec)
2. [Empty State System](#2-empty-state-system)
3. [Brand Splash](#3-brand-splash)
4. [About Page Brand Area](#4-about-page-brand-area)
5. [App Icon Review](#5-app-icon-review)
6. [Flutter 集成计划](#6-flutter-集成计划)

---

## 1. Illustration Style Spec

### 1.1 基线溯源

当前 48 个 SVG 图标的风格基线（来自用户提供的 svgrepo 素材）：

| 属性 | 观测值 | 判定 |
|------|--------|------|
| viewBox | `0 0 24 24`（主流，42/48） | ✅ 作为规范 |
| stroke | `#000000` | ✅ 替换为 `currentColor` |
| stroke-width | `2` | ✅ 保持 |
| stroke-linecap | `round` | ✅ 保持 |
| stroke-linejoin | `round` | ✅ 保持 |
| fill | `none`（主流，40/48） | ✅ 默认 fill=none |
| 色彩 | 单色，无渐变，无半透明 | ✅ 保持 |

**异常文件（需在 Phase C 统一规范化）：**

| 文件 | 异常 | 处理 |
|------|------|------|
| `writing-notepad-svgrepo-com.svg` | viewBox=0 0 491 491, fill 模式 | 新设计替换 |
| `footsteps-silhouette-variant-svgrepo-com.svg` | viewBox=0 0 515 515, fill 模式 | 新设计替换 |
| `sunrise-svgrepo-com.svg` | fill=#0D0D0D 而非 stroke | 改为 stroke=currentColor, fill=none |
| `pin-list-svgrepo-com.svg` | 异常复杂结构 | 如需保留，至少改 viewBox 为 24×24 |

> **决议：Phase C 新增的品牌 SVG 严格遵循 24×24 stroke 规范；上述异常文件暂不阻塞 Phase C，列入 Phase B 后续优化清单。**

---

### 1.2 规范定义（Flora Illustration Style v1）

#### 画板

```
viewBox="0 0 24 24"
```

所有品牌插图（空状态、启动页、品牌元素）使用此画板。不做多尺寸变体。

#### 线宽

```
stroke-width="2"
```

全体统一。不区分 20px / 24px / 32px 渲染尺寸——线宽始终 `2`（在 24×24 画板内），Flutter 端通过 `FloraIcon(size:)` 控制渲染尺寸。

#### 线端与连接

```
stroke-linecap="round"
stroke-linejoin="round"
```

#### 色彩模式

```
fill="none"
stroke="currentColor"
```

- 单色，无渐变，无 opacity
- 运行时由 `FloraIcon(color: ...)` 或主题 `colorScheme` 注入
- 浅色模式注入 `AppColors.primary` 或 `textPrimary`
- 深色模式注入 `AppColors.darkPrimary` 或 `darkTextPrimary`

#### 双色例外规则

仅以下两类场景允许使用双色：

| 场景 | 主色 | 辅色 | 辅色占比 |
|------|------|------|----------|
| 空状态插图 | `currentColor`（主线条） | `var(--flora-accent-soft)` | ≤20% 面积 |
| 启动页品牌图 | `currentColor` | `var(--flora-accent)` | ≤30% 面积 |

辅色通过第二个 `<path>` 或 `<circle>` 实现，使用 `fill` 或不同 `stroke`，CSS class 注入：

```xml
<path class="flora-fill-soft" fill="var(--flora-accent-soft)" ... />
<path class="flora-stroke-accent" stroke="var(--flora-accent)" ... />
```

Flutter 端映射：

```dart
static const Color accentSoft = Color(0x1FA26B59);   // light
static const Color darkAccentSoft = Color(0x26CA9A84); // dark
```

#### 留白比例

- 图形内容区域 ≤ 画板的 **60%**（约 14×14 在 24×24 内）
- 图形居中，四周留白均匀
- 不要在边界贴边

理由：空状态插图需要视觉呼吸感，与导航/按钮图标的填充感（~80% 画板利用率）形成层级差异。

#### 深色模式适配

```
stroke="currentColor"
```

- 单色 SVG 天然适配——由 Flutter 主题注入颜色，无需 dark 变体文件
- 双色 SVG：需在 Flutter 端根据 `Theme.of(context).brightness` 切换辅色 class 映射

#### 风格关键词（所有新 SVG 设计时对照）

- **圆润**：优先使用弧线而非折线，避免锐角
- **有机**：自然形态（叶片、水滴、年轮）而非几何图形
- **克制**：线条最少化，不做装饰性填充
- **温暖**：不做冷感几何、不做机械对称
- **生命力**：曲线有生长感，并非静止的符号

---

## 2. Empty State System

### 2.1 通用规则

| 属性 | 规范 |
|------|------|
| 画板 | `0 0 24 24` |
| 线宽 | `2` |
| 色彩 | 主线条 `currentColor` + 可选辅色 `var(--flora-accent-soft)` |
| 渲染尺寸（Flutter） | 80×80 dp |
| 布局 | 图标居中，下方 24dp 间距 → 文案，下方 8dp → 副文案 |
| 字体 | 文案 16px / w600 / textPrimary；副文案 13px / w400 / textSecondary，居中 |
| 容器 | 上下各留 64dp 空白，左右各 32dp |

### 2.2 empty-past — 过往为空

**场景**：过往页无日记记录

**文案**：
- 主：「还没有旧时光」
- 副：「今天写下第一条记录吧」

**视觉方向**：种子 + 土壤 + 等待发芽

**SVG 设计稿方向**：

```
viewBox="0 0 24 24" fill="none" stroke="currentColor"
stroke-width="2" stroke-linecap="round" stroke-linejoin="round"

构图（14×14 居中区域）：
┌──────────────────────┐
│                      │
│       ◠  ◠          │  ← 两条弧线表示晨光/天空
│        │             │
│       ◐              │  ← 种子（水滴形，中心有胚芽弧线）
│    ─────────         │  ← 土壤线（水平弧线，略下弯）
│    ╲  ╱  ╲  ╱       │  ← 土壤颗粒（3-4 个小圆点）
│                      │
└──────────────────────┘
```

**关键元素**：
- 种子：一个圆润的水滴形（与 Flora 品牌种子意象一致），中心有一道向上的弧线表示胚芽
- 土壤：一条温暖的弧线（略向下弯），下方 3-4 个散落的小圆点
- 天空：上方两道极简弧线，暗示晨光

**不使用**：文件夹、空盒子、沙漏

**Tone of Voice 校对**：不说「暂无数据」，说「还没有旧时光」— 将「空」转化为「等待开始」而非「缺失」。

---

### 2.3 empty-tags — 标签为空

**场景**：标签设置页无标签

**文案**：
- 主：「还没有标签」
- 副：「成长会慢慢长出自己的名字」

**视觉方向**：嫩芽 + 第一片叶子

**SVG 设计稿方向**：

```
viewBox="0 0 24 24" fill="none" stroke="currentColor"
stroke-width="2" stroke-linecap="round" stroke-linejoin="round"

构图（14×14 居中区域）：
┌──────────────────────┐
│                      │
│       ◠  ◠          │  ← 晨光弧线
│        ╱             │
│       ╱  ◐          │  ← 嫩芽（从土壤向上弯曲）
│      ╱              │    一片小叶子向右侧展开
│     ╱               │
│   ─────────         │  ← 土壤线
│    ·  ·  · ·        │  ← 土壤颗粒
│                      │
└──────────────────────┘
```

**关键元素**：
- 嫩芽：一条从土壤左侧向上弯曲的茎，顶部一片心形/椭圆小叶向右展开
- 生长感：茎的曲率有向光性（略向左弯再向上）
- 辅色（可选）：小叶片用 `var(--flora-accent-soft)` 的浅色 `fill`，表示嫩绿感

**不使用**：标签牌、书签、文件夹

**Tone of Voice 校对**：不说「未分类」，说「成长会慢慢长出自己的名字」— 标签不是分类工具，是成长过程中自然浮现的印记。

---

### 2.4 empty-habits — 习惯为空

**场景**：习惯设置页无习惯

**文案**：
- 主：「还没有习惯」
- 副：「从最小的一步开始」

**视觉方向**：小植物 + 水滴 + 生长

**SVG 设计稿方向**：

```
viewBox="0 0 24 24" fill="none" stroke="currentColor"
stroke-width="2" stroke-linecap="round" stroke-linejoin="round

构图（14×14 居中区域）：
┌──────────────────────┐
│                      │
│        ☁            │  ← 小云朵（两条弧线）
│         │            │
│         💧           │  ← 水滴（下降中）
│          │           │
│       ◐  ◐          │  ← 两片小叶（从土壤长出）
│        ╱             │
│   ─────────          │  ← 土壤线
│    ·  ·  ·           │
│                      │
└──────────────────────┘
```

**关键元素**：
- 两片小叶：从土壤中对称长出，一左一右（像豆瓣发芽的瞬间）
- 水滴：从上方云朵落下，表示浇灌/呵护
- 云朵：两到三条叠加弧线，极简表达

**不使用**：checklist、日历、图表

**Tone of Voice 校对**：不说「添加第一个习惯」，说「从最小的一步开始」— 习惯不是任务，是成长的最小单元。

---

### 2.5 empty-search — 搜索为空

**场景**：搜索无结果

**文案**：
- 主：「没有找到相关记录」
- 副：「换个关键词试试看」

**视觉方向**：年轮 + 树叶纹理 + 探索

**SVG 设计稿方向**：

```
viewBox="0 0 24 24" fill="none" stroke="currentColor"
stroke-width="2" stroke-linecap="round" stroke-linejoin="round"

构图（14×14 居中区域）：
┌──────────────────────┐
│                      │
│     ╭──────╮        │  ← 年轮外圈
│     │ ╭──╮ │        │  ← 年轮中圈
│     │ │ ◐ │ │       │  ← 年轮内圈（实心或密集弧线）
│     │ ╰──╯ │        │
│     ╰──────╯        │
│          ╲          │  ← 一片树叶从年轮外缘探出
│       ◐             │  ← 叶尖
│                      │
└──────────────────────┘
```

**关键元素**：
- 年轮：3 个同心但略有偏移的椭圆/弧线——不完全正圆，表示自然生长的年轮
- 叶片：从年轮右上角探出，表示在已有轨迹中寻找新的方向
- 搜索感：叶片方向指向年轮中心之外——「换个方向看看」

**不使用**：放大镜作为主视觉

**Tone of Voice 校对**：不说「0 条结果」，说「换个关键词试试看」— 不是搜索失败了，是换个角度再找。

---

## 3. Brand Splash

### 3.1 当前状态

```
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/drawable-v21/launch_background.xml
```

两个文件均为 Flutter 默认模板（纯白 / `?android:colorBackground`），无品牌元素。

### 3.2 设计方向

**不采用**：Logo + App 名称的静态居中布局。

**采用**：品牌元素为中心的晨光意象构图。

### 3.3 浅色模式

```
背景：AppColors.background (#F7F5F0)
```

**SVG 主图形**（居中，约 120×120 dp 渲染）：

```
viewBox="0 0 24 24" fill="none"
stroke-linecap="round" stroke-linejoin="round"

构图：
┌──────────────────────────┐
│                          │
│     ◠  ◠  ◠            │  ← 晨光弧线 × 3（stroke=#A26B59, w=1.5）
│         │               │
│       ◐                 │  ← 种子（stroke=#A26B59, w=2）
│      ╱ ╲               │  ← 芽从种子破出
│     ◐   ◐              │  ← 两片小叶展开（fill=#A26B59, opacity 0.12）
│   ─────────             │  ← 土壤线（stroke=#8A8278, w=1.5）
│    ·  ·  ·  ·          │  ← 土壤颗粒（stroke=#8A8278）
│                          │
│       Flora             │  ← 品牌名称（16sp, w600, #3D3731）
│    记录 · 觉察 · 成长    │  ← tagline（12sp, w400, #8A8278）
│                          │
└──────────────────────────┘
```

**文案层（Flutter Text widget，非 SVG）**：
- 「Flora」：18sp, w700, `AppColors.textPrimary`
- 「记录 · 觉察 · 成长」：12sp, w400, `AppColors.textSecondary`, 字间距 0.08em

### 3.4 深色模式

```
背景：AppColors.darkBackground (#1C1B1A)
```

与浅色共用同一 SVG 文件，Flutter 端注入不同颜色：

| 元素 | 浅色 | 深色 |
|------|------|------|
| 晨光弧线 | `#A26B59` | `#CA9A84` |
| 种子/芽主线条 | `#A26B59` | `#CA9A84` |
| 小叶填充 | `#A26B59` 12% | `#CA9A84` 15% |
| 土壤线/颗粒 | `#8A8278` | `#9E948A` |
| 文案 Flora | `#3D3731` | `#E8E2DC` |
| tagline | `#8A8278` | `#9E948A` |

**避免**：深色模式不使用纯黑背景 (`#000`)。保留晨光意象——在深色画布上，锈红棕的种子仍然传递温暖的萌芽感。

### 3.5 启动行为

- 启动页显示 1.5–2.0 秒（或应用初始化完成后立即过渡）
- 过渡动效：fade out（300ms, ease-out）
- Android 12+：使用 SplashScreen API 的 `windowSplashScreenBrandingImage` 实现品牌图标居中

---

## 4. About Page Brand Area

### 4.1 当前状态

```
lib/screens/about_page.dart
```

现有实现：

- PNG 品牌图标 64×64（`brandIcon`）
- 「荔枝日记」标题
- 版本号
- 「Flutter 客户端」
- 「安静的日常日记 / 关心你每天的小事」

**问题**：

1. 「Flutter 客户端」暴露了技术栈——对用户无意义
2. 品牌说明的位置/语气有提升空间
3. 品牌区与更新日志之间无视觉分隔

### 4.2 设计方向

**布局（从上到下）：**

```
┌─────────────────────────────────┐
│  ← 返回         关于           │  ← AppBar
├─────────────────────────────────┤
│                                 │
│          [brand-splash]         │  ← SVG 品牌图, 80×80
│                                 │
│            Flora               │  ← 24sp, w700, textPrimary
│                                 │
│       记录 · 觉察 · 成长        │  ← 13sp, w400, textSecondary, 0.08em
│                                 │
│  ┌─────────────────────────┐   │
│  │                         │   │  ← Card（surface, 12px radius, 0.5px border）
│  │  Flora 不是效率工具。    │   │
│  │  它记录生活中的成长轨迹。│   │  ← 14sp, w400, textPrimary, center
│  │                         │   │
│  │  记录。觉察。成长。      │   │  ← 14sp, w600, primary, center
│  │                         │   │
│  └─────────────────────────┘   │
│                                 │
│          版本 v1.2.0            │  ← 11sp, w400, muted
│                                 │
│  ───────────────────────────── │  ← Divider
│                                 │
│  更新内容                       │  ← 16sp, w600, title
│  ...                            │
└─────────────────────────────────┘
```

### 4.3 文案

| 位置 | 文案 | 样式 |
|------|------|------|
| 标题 | Flora | headlineLarge（24sp, w700） |
| tagline | 记录 · 觉察 · 成长 | bodySmall（13sp, w400, textSecondary） |
| 品牌卡片 | Flora 不是效率工具。它记录生活中的成长轨迹。 | bodyMedium（14sp, w400, center） |
| 卡片强调句 | 记录。觉察。成长。 | bodyMedium（14sp, w600, primary, center） |
| 版本 | 版本 v1.2.0 (42) | caption（11sp, w400, muted） |

### 4.4 改动要点

1. 移除「Flutter 客户端」
2. 移除「安静的日常日记 / 关心你每天的小事」— 替换为品牌卡片
3. 品牌图标从 PNG 切换为 SVG `brandSplash`（80×80）
4. 新增品牌说明卡片（`surface` 背景、居中文案）
5. 版本号下移到卡片下方

---

## 5. App Icon Review

### 5.1 当前状态

| 平台 | 资产 | 状态 |
|------|------|------|
| Android | `mipmap-*/ic_launcher.png`（5 种密度） | ✅ 存在 |
| iOS | `AppIcon.appiconset/`（9 种尺寸） | ✅ 存在 |
| Adaptive Icon | 未检测到 `ic_launcher.xml` 或 `ic_foreground.png` | ❌ 缺失 |

### 5.2 审查维度

#### 品牌一致性

> ⚠️ 无法直接评估——当前图标为栅格 PNG，我无法读取图像文件。建议你人工确认：
>
> - [ ] 图标是否使用了 Flora 品牌核心视觉元素（种子/叶片/果实）？
> - [ ] 主色是否与 `AppColors.primary`（#A26B59）一致？
> - [ ] 风格是否与 Flora 极简、温暖、有机的品牌气质匹配？
> - [ ] 是否避免了科技感/工具感/系统感？

#### 小尺寸表现（48×48dp / 108×108px 通知栏）

> ⚠️ 无法自动评估。建议你：
>
> - [ ] 在 Android 模拟器/真机的通知栏/最近任务中查看 48dp 圆标表现
> - [ ] 检查细节是否糊掉（叶片脉络、文字笔画是否有断裂）
> - [ ] 对比 iOS 的 40×40pt Spotlight 图标
>
> **一般建议**：小尺寸下，Flora 品牌图标如含「荔枝」果实细节，应确保果壳纹理 ≥ 3px 线宽，< 3px 将不可见。

#### Android Adaptive Icon 兼容性

**当前状态**：❌ 未实现 Adaptive Icon。

Android 8.0+ 设备将看到带白色圆角背景的原始图标（可能被强制裁切为圆形、方圆形或泪滴形，取决于 OEM）。

**建议**：

```
res/mipmap-anydpi-v26/ic_launcher.xml   ← 新建
res/drawable/ic_foreground.xml           ← 新建（前景层）
res/drawable/ic_background.xml           ← 新建（背景层）
```

- **背景层**：纯色 `#F7F5F0` 或 `#A26B59`（视图标明暗而定）
- **前景层**：品牌图标核心图形（SVG → vector drawable），安全区域 66/108（约 61%）
- **安全裁切**：图标核心元素保持在前景层 66dp 安全区域内，避免被 OEM 形状裁掉

#### iOS App Icon 兼容性

**当前状态**：✅ 9 种尺寸均已提供。

**建议**：

- [ ] iOS 图标不需要背景色（iOS 自动添加圆角矩形）
- [ ] 确认无透明边缘裁切（图标内容应填满 1024×1024 画布，iOS 自动裁切圆角）
- [ ] 如需在 iOS 18 深色/浅色调图标模式下表现良好，考虑提供 `dark` 和 `tinted` 变体

### 5.3 优化建议优先级

| 优先级 | 建议 | 理由 |
|--------|------|------|
| P0 | 实现 Android Adaptive Icon | 当前在多数 Android 设备上显示为带白色背景的原始方形，与系统风格不统一 |
| P1 | 小尺寸可读性验证 | 如果果壳/叶片细节在 48dp 下不可见，需要简化 |
| P2 | iOS 深色/浅色调图标 | iOS 18 特性，非强制但提升品牌质感 |

---

## 6. Flutter 集成计划

### 6.1 文件产出清单

| 文件 | 类型 | 说明 |
|------|------|------|
| `assets/svg/empty-past.svg` | SVG | 过往为空插图 |
| `assets/svg/empty-tags.svg` | SVG | 标签为空插图 |
| `assets/svg/empty-habits.svg` | SVG | 习惯为空插图 |
| `assets/svg/empty-search.svg` | SVG | 搜索为空插图 |
| `assets/svg/brand-splash.svg` | SVG | 启动页/关于页品牌图 |
| `lib/widgets/flora_empty.dart` | Dart | 空状态通用组件 |
| `lib/widgets/flora_splash.dart` | Dart | 启动页品牌组件（可复用） |
| `lib/screens/about_page.dart` | Dart | 关于页品牌区改造（修改） |
| `android/.../ic_launcher.xml` + `ic_foreground/background.xml` | XML | Adaptive Icon（修改资源） |

### 6.2 FloraEmpty 组件 API

```dart
/// 通用空状态组件。
///
/// 使用方式：
///   FloraEmpty(
///     icon: FloraIcons.emptyPast,
///     title: '还没有旧时光',
///     subtitle: '今天写下第一条记录吧',
///   )
class FloraEmpty extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  // 内部：80×80 FloraIcon + 24dp gap + Text + 8dp gap + subtitle + action
}
```

### 6.3 FloraSplash 组件 API

```dart
/// 启动页品牌图组件（可复用于启动页和关于页）。
///
/// 使用方式：
///   FloraSplash()
///   FloraSplash(size: 80.0)
class FloraSplash extends StatelessWidget {
  final double size;  // 默认 120.0（启动页）/ 80.0（关于页）

  // 内部：FloraIcon(brandSplash, size:) + 16dp gap + 文案
}
```

### 6.4 渐近路线

| 步骤 | 依赖 | 产出 |
|------|------|------|
| 1. 确认本规范 | 用户审阅 | ✅ 本文档 |
| 2. 设计 5 个 SVG | 规范确认 | `assets/svg/empty-*.svg` + `brand-splash.svg` |
| 3. Flutter 集成 | SVG 就位 | `FloraEmpty` + `FloraSplash` + AboutPage 改造 |
| 4. Android Adaptive Icon | 图标审查 | `ic_launcher.xml` + foreground/background |
| 5. 真机验收 | 全部就位 | 逐页检查 + 深色模式对比 |

---

## 附录 A：品牌视觉元素速查

| 元素 | 语义 | 适用场景 |
|------|------|----------|
| 种子 | 起点、可能性 | emptyHabits, brandSplash |
| 芽 | 开始、成长 | emptyTags, emptyPast |
| 叶片 | 生命力、展开 | emptyHabits, emptyPast |
| 年轮 | 积累、时间 | emptySearch, about page |
| 晨光 | 新的一天、希望 | brandSplash, emptyPast |
| 果实 | 成果、收获 | App Icon（现用） |

## 附录 B：Tone of Voice 速查

| 场景 | 说 | 不说 |
|------|-----|------|
| 空状态文案 | 「还没有旧时光」 | 「暂无数据」 |
| 空状态副文案 | 「今天写下第一条记录吧」 | 「点击添加」 |
| 品牌说明 | 「Flora 不是效率工具。它记录生活中的成长轨迹。」 | 「一款高效的日记管理工具」 |
| 版本说明 | 「版本 v1.2.0」 | 「Flutter 客户端 v1.2.0」 |

---

> **下一步**：审阅确认后，进入 SVG 设计阶段。
