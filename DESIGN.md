---
name: 荔枝日记
description: 一册温暖、治愈、专注且会呼吸的生活手账
colors:
  paper-background: "#F7F2EA"
  paper-surface: "#FFF7ED"
  paper-soft: "#F8EBD8"
  ink-primary: "#5A4A36"
  ink-secondary: "#8D6E63"
  ink-muted: "#A48B7E"
  litchi-primary: "#A26B59"
  paper-border: "#E8DCC9"
  growth-green: "#7BA67A"
  error-red: "#E06A6A"
  night-background: "#1F1B18"
  night-surface: "#2B241E"
  night-elevated: "#3A3027"
  night-ink: "#F1E6D7"
  night-secondary: "#C8AA9A"
  night-primary: "#CA9A84"
  night-border: "#4B3D2D"
  rainbow-note: "#FF6B6B"
  rainbow-happiness: "#FF9F43"
  rainbow-anxiety: "#FFD43B"
  rainbow-reflection: "#51CF66"
  rainbow-coach: "#12B5CB"
  rainbow-tomorrow: "#4DABF7"
  rainbow-images: "#9775FA"
typography:
  headline:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.35
  body:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.6
  body-large:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.3
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  pill: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.litchi-primary}"
    textColor: "{colors.paper-surface}"
    typography: "{typography.title}"
    rounded: "{rounded.md}"
    padding: "12px 24px"
    height: "48px"
  input:
    backgroundColor: "{colors.paper-surface}"
    textColor: "{colors.ink-primary}"
    typography: "{typography.body-large}"
    rounded: "{rounded.md}"
    padding: "12px 16px"
    height: "48px"
  card:
    backgroundColor: "{colors.paper-surface}"
    textColor: "{colors.ink-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "16px"
  navigation-selected:
    backgroundColor: "{colors.paper-soft}"
    textColor: "{colors.ink-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    height: "48px"
  tag-chip:
    backgroundColor: "{colors.paper-soft}"
    textColor: "{colors.ink-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "6px 10px"
---

# Design System: 荔枝日记

## Overview

**Creative North Star: "会呼吸的生活手账"**

荔枝日记应像一本每天都愿意翻开的私人手账：暖色纸张承载内容，克制的留白让日期、文字和相片自然成为主角。设计靠近 iOS 的清晰排版、熟悉控件、轻量反馈和日期导航节奏，但不复制其他 App 的品牌外观。

界面以“柔和克制、原生清晰”为组件原则。暖色、Flora 图标和友好文案负责表达陪伴感；层级、状态和操作则保持直接、稳定、容易理解。系统拒绝冷峻办公感、密集仪表盘、装饰性玻璃、强烈渐变、复杂动效和无意义的卡片堆叠。

**Key Characteristics:**

- 暖色纸张与清楚墨色
- iOS 风格的信息密度和控件节奏
- 内容优先的留白与时间脉络
- 平面为主、轻抬起为辅
- Today Rainbow 只表达模块身份
- 浅色与深色均保持可读

## Colors

色彩来自米杏手账、荔枝果实和叶片成长意象；整体采用克制的暖中性色，模块色只在需要辨认语义的位置出现。

### Primary

- **荔枝陶红** (`#A26B59`): 主要按钮、焦点边框、选中状态和关键操作。
- **夜间荔枝陶红** (`#CA9A84`): 深色模式中的主要操作色，避免高饱和刺眼。

### Secondary

- **成长叶绿** (`#7BA67A`): 成功、完成和成长反馈。
- **提醒莓红** (`#E06A6A`): 错误与破坏性操作，不作为普通装饰色。

### Tertiary

- **Today Rainbow**: 随手记 `#FF6B6B`、小确幸 `#FF9F43`、焦虑 `#FFD43B`、觉察 `#51CF66`、人生教练 `#12B5CB`、明日寄语 `#4DABF7`、影像记录 `#9775FA`。仅用于模块识别、关联标签和轻量状态提示。

### Neutral

- **日记纸** (`#F7F2EA`): 浅色页面背景。
- **柔光纸面** (`#FFF7ED`): 卡片、输入区和主要内容表面。
- **纸页浅层** (`#F8EBD8`): 选中背景与次级分区。
- **主墨棕** (`#5A4A36`): 标题和正文。
- **次墨棕** (`#8D6E63`): 辅助说明和次要标签。
- **淡墨棕** (`#A48B7E`): 占位与弱提示。
- **纸页边线** (`#E8DCC9`): 0.5–1px 分隔与边框。
- **夜间纸背** (`#1F1B18`): 深色页面背景。
- **夜间纸面** (`#2B241E`): 深色卡片和输入区。
- **夜间墨色** (`#F1E6D7`): 深色主文字。

**The Rainbow Restraint Rule.** Today Rainbow 只表达模块语义，不写入 Markdown，也不扩散到无模块上下文的普通控件。

**The Readability Rule.** 柔和不等于低对比度；正文、日期、标签和操作提示必须优先保证清晰。

## Typography

**Display Font:** 平台系统字体（iOS 优先使用 SF Pro 系统呈现）
**Body Font:** 平台系统字体
**Label Font:** 平台系统字体

**Character:** 单一系统字体家族保持原生、安静和可信。层级通过字号、字重、行高和留白形成，不依赖装饰字体。

### Hierarchy

- **Headline** (700, 24px, 1.25): 一级页面标题，如“今天”“过往”“习惯统计”。
- **Title** (600, 16px, 1.35): 卡片标题、关键按钮和二级标题。
- **Section Label** (600–700, 13px, 1.35): 模块标题与紧凑分组标签。
- **Body Large** (400, 16px, 1.5): 输入内容与需要舒展阅读的正文。
- **Body** (400, 14px, 1.6): 日记正文、说明与列表内容。
- **Label** (500–700, 12px, 1.3): 导航标签、日期辅助信息和紧凑状态。

**The Quiet Hierarchy Rule.** 不使用全大写、过度粗体或装饰字体制造层级；页面一级标题只保留一个。

## Elevation

系统采用“平面为主、轻抬起为辅”。页面、模块和普通卡片主要依靠色调层级、0.5–1px 细边框与留白区分，不使用常驻重阴影。只有浮动记录按钮、底部月历、菜单、活动滑块和开关拇指等临时或可操作层使用柔和环境阴影。

### Shadow Vocabulary

- **轻抬起** (`0 3px 8px rgba(0,0,0,0.12)`): 活动滑块、浮层中的选中面。
- **触控拇指** (`0 2px 5px rgba(0,0,0,0.30)`): 小型开关拇指，保持 iOS 式物理层次。
- **浮层环境光** (`0 10px 30px rgba(31,27,24,0.16)`): 底部月历、操作菜单和需要脱离页面的临时层。

**The Flat-by-Default Rule.** 静态内容不靠阴影区分；只有状态变化或临时浮层获得高度。

## Components

组件应柔和克制、原生清晰，具备完整的默认、按下、焦点、禁用、加载和错误状态。

### Buttons

- **Shape:** 12px 圆角；图标按钮与筛选可使用胶囊形。
- **Primary:** 荔枝陶红背景、柔光纸面文字，最小高度 48dp，水平 24dp、垂直 12dp。
- **Pressed / Focus:** 按下时轻微降低明度；键盘焦点使用清楚的主色轮廓，不使用发光特效。
- **Secondary / Ghost:** 次要操作使用无填充文字按钮或 0.5px 主色边框；破坏性操作只在确认语境中使用提醒莓红。

### Chips

- **Style:** 胶囊形，文字至少 12px；背景、边框和文字来自同一模块色的透明层级。
- **State:** 未选中保持低饱和，选中同时改变填充、边框或图标，不能只依赖色相。

### Cards / Containers

- **Corner Style:** 默认 12px，图片缩略图与内部小面使用 8px。
- **Background:** 浅色使用柔光纸面，深色使用夜间纸面；模块卡可叠加低透明度 Today Rainbow 色。
- **Shadow Strategy:** 默认无阴影，参照 Elevation。
- **Border:** 0.5px 纸页边线；带模块色时最多 1px。
- **Internal Padding:** 默认 16dp，紧凑分组可使用 12dp。

### Inputs / Fields

- **Style:** 纸面填充、12px 圆角、0.5–1px 边线，最小高度 48dp。
- **Focus:** 边框切换为荔枝陶红，状态明确但不改变布局尺寸。
- **Error / Disabled:** 错误使用提醒莓红并配合可操作文字；禁用态降低对比度但仍保持可辨认。

### Navigation

- 底部导航保留“今天、过往、习惯”三个核心工作区，使用 iOS 风格的稳定位置与轻量选中背景。
- 一级页标题左对齐；日期或设置等辅助操作位于头部右侧。
- 日期导航优先使用可理解的年月日文本、月历和左右切换，不发明陌生手势作为唯一入口。

### Timeline

- 时间是首要扫描锚点，条目按 Markdown 数据层中的 `HH:mm` 升序显示。
- 时间线细而轻，节点和模块色提供识别，不让装饰压过正文。
- 相片、标签、引用前缀和条目原始语义必须在视觉重排后保持完整。

### Calendar

- 月历遵循 iOS 式清晰日期网格与触控尺寸；有记录日期使用小圆点，并配合选中态区分。
- 小圆点只表示当天包含真实条目或相片，只有空模板的日期不显示。
- 今天和未来日期的可用状态必须清楚；加载、空月份和请求失败均需有稳定反馈。

## Do's and Don'ts

### Do:

- **Do** 使用 `#F7F2EA`、`#FFF7ED`、`#5A4A36` 构成主要浅色阅读层级。
- **Do** 保持 4/8/12/16/24/32dp 间距节奏和至少 48dp 点击区域。
- **Do** 借鉴 iOS 的日期导航、排版密度、控件状态和轻量反馈。
- **Do** 让 App 展示、交互结果和 Obsidian Markdown 始终一致。
- **Do** 在模块上下文中严格按 Today Rainbow 固定映射使用颜色。
- **Do** 为浅色、深色、字体放大和减少动态效果提供可用状态。

### Don't:

- **Don't** 做冷峻、办公化或数据仪表盘式的日记工具。
- **Don't** 使用装饰性玻璃、强烈渐变、复杂动效或密集卡片制造“高级感”。
- **Don't** 照搬 Web 页面结构，也不要逐像素复制其他日记 App。
- **Don't** 把“极简日记”的黑白视觉、品牌资源或独有控件直接复制到荔枝日记。
- **Don't** 给静态内容普遍添加重阴影、彩色侧边条或嵌套卡片。
- **Don't** 仅靠颜色表达记录状态、选中状态、错误或是否可操作。
- **Don't** 把模块色、标签色或其他视觉信息写入 Markdown。
