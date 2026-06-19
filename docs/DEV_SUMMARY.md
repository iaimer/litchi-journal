# 荔枝日记 Flutter 端开发过程文档

## 1. 项目定位与总体原则

荔枝日记 Flutter 端最初的目标，是把已有 Web 端的核心日记能力迁移到移动端，让手机成为日常记录的主入口。随着开发推进，项目原则逐渐从"复刻 Web UI"转向"功能与数据行为对齐，UI 后续用 Open Design 重新设计"。

Web 端继续作为功能、API、Markdown 格式、标签体系、AI 提示词和设置结构的参考来源，但 Flutter 端不再追求 1:1 视觉复刻。Flutter 的重点是更适合手机端的高频记录体验：快速输入、AI 润色、标签自动选择、习惯更新、焦虑四问、编辑删除、草稿保护和 Obsidian 后台同步。

当前项目已经进入"文字记录功能对齐版"阶段。也就是说，主要文字记录闭环已经完成：新的一天能自动创建日记，随手记、觉察、小确幸和焦虑四问都能写入，记录可以润色、打标签、编辑、删除，习惯可以更新，Obsidian 后台数据同步正常。

---

## 2. Sprint 1：Flutter 项目初始化与远程客户端闭环

项目从标准 Flutter 工程开始。

对应提交：

```text
91ed2ab Initial Flutter project
4beadf4 feat: implement first-runnable remote-client loop
```

这一阶段完成了 Flutter 项目基础结构，包括平台目录、测试框架、App 入口和最小运行环境。随后实现了第一个可以运行的远程客户端闭环，让 Flutter App 能够连接原有日记服务端，完成基础请求和响应验证。

这个阶段的重点不是复杂 UI，而是确认 Flutter 可以作为 Web 之外的独立客户端运行。它为后续读取 Obsidian 日记、写入记录、同步服务端数据奠定了基础。

阶段结束时，Flutter 端已经具备最小远程访问能力，可以作为移动端客户端继续扩展。

---

## 3. Sprint 2：结构化 Markdown 读取与基础解析

对应提交：

```text
3aa3433 feat: structured Markdown reading view for litchi diary
d8b3877 fix: review findings - YAML stripping, markdown paragraphs, preamble filtering, colors, regex
```

这一阶段开始处理 Obsidian Markdown 日记文件。Flutter 不再只是显示普通文本，而是开始读取日记 Markdown，并尝试把它解析成结构化内容。

主要工作包括：剥离 YAML frontmatter，过滤模板前言或无效 preamble，处理 Markdown 段落，修复正则解析，调整颜色和基础展示方式。

这个阶段是 `MarkdownParser` 和 `DiaryDocument` 思路的起点。它解决的问题是：如何把服务端返回的 Obsidian Markdown 转换成 Flutter 可以理解和渲染的结构。

阶段结束时，Flutter 端具备了结构化读取日记的基础能力。

---

## 4. Sprint 3：设计系统与 section-oriented UI 迁移

对应提交：

```text
9abb320 feat: UI migration batch 1 - design system and section-oriented components
```

这一阶段开始建立 Flutter 端自己的设计系统和 section-oriented 组件体系。日记内容不再作为一整段 Markdown 展示，而是按不同 section 拆分，用不同组件显示。

这一阶段可能包括基础颜色、卡片、标题、间距、section 容器等 UI 基础设施。它的重点不是最终视觉设计，而是让今日页可以按照日记结构进行组织。

后续的 `QuickNoteTimeline`、`HabitCard`、`AnxietyCard`、`GenericSectionCard`、`ReviewCard` 等组件，都是在这一阶段建立的 section-oriented 思路上继续扩展的。

阶段结束时，Flutter 今日页从"Markdown 阅读器"向"原生日记界面"过渡。

---

## 5. Sprint 4：领域模型、原生 section widgets 与随手记输入起点

对应提交：

```text
364eddb Add diary domain model and native section widgets
17dac4c feat: Sprint 4 + 4.1 - QuickNoteComposer component and timestamp fix
```

这一阶段进一步补齐日记领域模型和原生 section widgets。Flutter 开始拥有较清晰的领域对象，而不是只依赖解析后的散乱文本。

同时，`QuickNoteComposer` 出现，标志着 Flutter 从只读展示进入写入阶段。用户可以在今日页直接添加随手记。随后修复了时间戳问题，确保写入 Markdown 的时间正确。

这一阶段的 QuickNoteComposer 还只是早期版本，不包含后来的标签选择、AI 润色、草稿保护、多入口选择、自适应输入框、编辑删除等能力。但它完成了一个关键突破：Flutter 可以向日记写入第一类内容。

阶段结束时，Flutter 端已经具备远程读取、结构化展示和基础随手记写入能力。

---

## 6. Sprint 5：标签系统迁移

对应提交：

```text
0d7acf6 Add tag config model and fetch API
5ca854a Add TagRepository with local cache support
084cb63 Suppress prefer_initializing_formals lint for TagRepository
02c86d7 Add standalone tag picker
db00b20 feat: Sprint 5 - tag system integration
```

这一阶段解决标签体系迁移问题。Web 端标签结构是三层：领域 domain、主题 topic、方法 method。规则是至少选择一个领域和一个主题，方法可选。

Flutter 端先新增 `TagConfig`、`TagDomain`、`TagTopic`、`TagMethod` 模型，并实现 `ApiClient.fetchTagConfig()`，从服务端 `GET /api/v1/settings/tags` 拉取标签配置。

之后新增 `TagRepository`，使用 `FlutterSecureStorage` 做本地缓存。读取策略是缓存优先，没有缓存时再远程拉取，拉取成功后写入缓存。

随后实现独立 `TagPicker`。它支持领域单选、主题联动、方法可选 toggle。集成到 QuickNoteComposer 后，记录可以提交标签数组，例如：

```text
["亲子", "亲子沟通", "反思"]
```

这一阶段让 Flutter 从"只能显示已有标签"变成"能同步标签配置、选择标签、写入标签"。

---

## 7. Sprint 6：今日页输入体验优化

对应提交：

```text
aeba4da feat: Sprint 6 - daily usability improvements
```

这一阶段重点优化今日页日常使用体验。

保存随手记后，原本会触发全页 loading，导致页面闪烁。后来改为静默刷新：保存成功后显示 SnackBar"已保存"，页面内容后台更新，不再全页 spinner。

TagPicker 改为默认折叠，避免三行标签芯片长期占用输入区。标签加载失败时也不再完全无声，而是显示轻量提示"标签暂不可用"。

另外修复了提交成功后 TagPicker 没有自动收起的问题。QuickNoteComposer 清空 selectedTags 后，会触发 TagPicker 同步重置为折叠状态。

这一阶段的目标是让输入过程更轻、更稳定，不再因为保存或标签选择造成视觉干扰。

---

## 8. Sprint 7：多入口快速记录

对应提交：

```text
63ea7f0 Phase 7A: add multi-entry ApiClient methods (reflection/happiness/anxiety)
d18c0b0 Phase 7B: add HappinessSection model, parser, dispatch, tests
ace9ece Fix happiness timeline parsing and slogan rendering
8caebbf feat: Phase 7E+7F-A - AnxietyComposer and template filtering
0d977dc feat: Phase 7F - draft protection and anxiety back navigation
445e375 feat: Phase 7F-B3 - QuickNoteComposer draft protection
1d46414 fix: Phase 7D.1 - happiness callout body stops at timeline lines
```

这一阶段扩展记录入口。原本 Flutter 只能写随手记，但真实日常还需要觉察、小确幸和焦虑。

Flutter 端新增三个 API 方法：

```text
appendReflection
appendHappiness
appendAnxiety
```

它们与 `appendQuickNote` 共用 payload 模式，统一发送 date、content、tags、time 和 operationId。

随后新增 `HappinessSection`，并修复小确幸解析。小确幸在 Markdown 中使用 blockquote 格式：

```markdown
> **09:30** 内容 #标签
```

原 parser 只识别 `- **HH:MM**`，导致小确幸 time 和 tags 混在正文。后来扩展正则，同时支持 `-` 和 `>`，让小确幸也解析为 `TimelineContent`。

接着新增 `EntryTypeSelector`，支持四个入口：随手记、觉察、小确幸、焦虑。前三者共用 QuickNoteComposer，焦虑后来改为独立 `AnxietyComposer`。

焦虑四问参考 Web 端 RecordWizard，使用四步问答：

```markdown
- 今天什么时候我感到焦虑/紧张？
> 回答

- 当时我在担心什么？（具体到一句话）
> 回答

- 我做了什么？
> 回答

- 这个应对是帮我面对了，还是帮我躲开了？
> 回答
```

焦虑入口不使用标签。

之后修复了焦虑模板与真实回答同时显示的问题。只有没有真实回答时，才显示模板四问；已有真实回答时隐藏空模板。

这一阶段完成了 Flutter 端多入口快速记录能力。

---

## 9. Sprint 7F：草稿保护与焦虑回退

对应提交：

```text
0d977dc feat: Phase 7F - draft protection and anxiety back navigation
445e375 feat: Phase 7F-B3 - QuickNoteComposer draft protection
07f665d feat: Draft TTL - 2-minute expiration for quick and anxiety drafts with auto-clear
```

真实使用中发现，焦虑四问填写到一半，如果 App 刷新、切换入口或短暂离开，草稿会丢失。

因此新增 `DraftRepository`。普通入口草稿保存 content 和 tags，焦虑草稿保存 step 和 answers。草稿使用 `FlutterSecureStorage` 持久化。

最初草稿长期保存，后来发现会污染下一次记录，于是加入 TTL。当前草稿默认保留 2 分钟。草稿的定位是短时保护，不是长期草稿箱。

过期草稿读取时自动清除。提交成功后也立即清除草稿。

焦虑四问还新增"上一步"。用户可以返回前面问题修改答案。每次前进或后退都会先保存当前回答到草稿。

这一阶段保证输入过程中的短时安全性。

---

## 10. Sprint 8：习惯追踪录入闭环

对应提交：

```text
158c1c0 feat: Phase 8A - habit counter model, parser, and API
faa7576 feat: Phase 8B - interactive HabitCard with checkbox toggle, water quick-add, steps edit
e8fad39 fix: code review - catch exceptions in _update, fresh status in steps dialog, deduplicate field matching
```

Web 端习惯系统包括 checkbox 和 counter 两类。Flutter 原本只能只读展示习惯。

这一阶段先扩展模型：`HabitItem` 新增 `HabitKind`、`value` 和 `unit`。Parser 可以识别饮水和运动：

```markdown
- 🥛🥤🥤饮水 500 mL
- 🧘 运动/拉伸/快走 8000 步
```

它们解析为 counter。阅读、学语言、补充剂等解析为 checkbox。

随后新增 `HabitStatus`，把当前习惯状态映射成服务端需要的五个字段：

```text
water
steps
reading
language
supplements
```

`ApiClient.updateHabits()` 调用 `POST /api/v1/diary/habit`，服务端替换整个习惯区块。

`HabitCard` 改成交互式。阅读、学语言、补充剂点击 toggle；饮水提供快捷按钮；运动使用编辑弹窗录入步数。更新成功后只在对应习惯后显示短暂 loading，不全页刷新。

后续 code review 修复了异常导致 spinner 永久存在、steps dialog 读到 stale status、字段匹配重复等问题。

这一阶段让习惯追踪真正可录入。

---

## 11. Sprint 9：AI 润色与自动标签

对应提交：

```text
b0f849f feat: Phase 9A - PolishResult model and PolishResultParser for AI polish tag parsing
c00ffca feat: Phase 9B - AIConfig model, AIConfigRepository, PolisherService with prompt builder
e02e1da feat: Phase 9C - AI config entry in SetupScreen with editable fields and secure storage
4757fdf feat: Phase 9D - polish button in QuickNoteComposer with AI callback, HomeScreen wiring
31e5b30 feat: Phase 9C - SettingsScreen with AI config, AIConfig name field, presets, baseUrl normalize
e144074 fix: Phase 9D.1 - strengthen polish prompt hashtag rules, add coachPrompt field, SettingsScreen prompt inputs
9f717f2 fix: prompt redesign - polishPrompt/coachPrompt are complete prompts, defaults are fallbacks not appendages
7785652 feat: Phase 9E - AnxietyComposer per-step polish current answer with plain text AI
8d98ca7 test: add tag auto-selection tests for all three polish entry types
4f29c2f feat: Phase 9D.2 - retry polish with stronger tag prompt when first response has no valid tags
b09b161 fix: reflection polish prompt guidance - guide AI to output domain+topic not just method
cae4051 chore: fix MultiResponseHttpClient analyzer infos
```

AI 润色分成两条链路。

普通入口包括随手记、觉察、小确幸，调用 `PolisherService.polish()`，返回 `PolishResult(content, tags)`。AI 需要输出润色正文和标签，Flutter 解析合法标签并回填 TagPicker。

焦虑入口调用 `polishPlainText()`，只润色当前回答，不加标签。

AI 配置从 SetupScreen 移到独立 SettingsScreen。AIConfig 包含 enabled、name、baseUrl、apiKey、model、polishPrompt、coachPrompt。SettingsScreen 支持预设、API Key 隐藏、提示词编辑和恢复默认。

提示词语义后来修正为：`polishPrompt` 和 `coachPrompt` 是完整提示词本体，不是追加在默认提示词后的补充。默认提示词只是 fallback。标签规则仍由系统动态追加，以保证自动标签稳定。

自动标签曾出现不稳定。修复策略是：如果第一次 AI 返回没有合法 tags，就追加更强标签约束重试一次。对于觉察入口，又额外提示 AI 不能只输出 `#反思`，必须先判断领域，再选择主题，最后才可选方法。

目前真机验证：随手记、小确幸、觉察的 AI 润色与自动标签都已稳定。焦虑四问润色当前回答，不加标签。

---

## 12. Sprint 9F：焦虑四问单日唯一与编辑

对应提交：

```text
33abaa5 feat: Phase 9F-B - anxiety edit mode with replaceAnxiety API and parseAnswers
```

用户明确规则：每天只允许一条焦虑四问，但允许编辑。

服务端新增：

```http
POST /api/v1/diary/anxiety/replace
```

用于替换当天唯一焦虑四问，而不是追加第二条。Flutter 端新增 `replaceAnxiety()`。

`AnxietyComposer` 支持 `initialAnswers` 和 `isEdit`。HomeScreen 判断当天是否已有真实焦虑回答：没有则新建，保存走 appendAnxiety；已有则编辑，保存走 replaceAnxiety。

草稿优先级是：未过期草稿优先，其次才是服务端已有回答。

真机验证通过：编辑焦虑后 Obsidian 后台只替换原四问，不追加第二条；刷新后 App 显示修改后的内容。

---

## 13. 输入框自适应高度修复

对应提交：

```text
a9a4b98 fix: QuickNoteComposer TextField auto-expand from 3 to 8 lines
6d43d60 fix: AnxietyComposer TextField auto-expand from 2 to 8 lines
```

真实使用中发现，长文本输入时 TextField 高度固定，需要在小框内滚动，体验不好。

QuickNoteComposer 改为初始 3 行，最多 8 行。随手记、觉察、小确幸都受益。

AnxietyComposer 改为初始 2 行，最多 8 行。焦虑四问每步保持轻量，但长回答可以自动增高。

---

## 14. Sprint 10A：编辑/删除 API helper 与行重建工具

对应提交：

```text
7562c53 feat: Phase 10A - ApiClient editEntry/deleteEntry + rebuildTimelineLine helper
```

Web 端已有 edit-entry 和 delete-entry。Flutter 新增 `ApiClient.editEntry()` 和 `ApiClient.deleteEntry()`。

因为服务端按精确文本匹配，Flutter 必须使用记录原始 rawLine 作为 target 或 line，不能用 content 反推。

新增 `rebuildTimelineLine()`，用于编辑时保留原时间和前缀，只替换正文和标签。

随手记和觉察保持：

```markdown
- **09:30** 内容 #标签
```

小确幸保持：

```markdown
> **09:30** 内容 #标签
```

---

## 15. Sprint 10B：今日页条目删除

对应提交：

```text
9b864c7 feat: Phase 10B - entry delete with confirm dialog, wired through QuickNoteTimeline and GenericSectionCard
7f72816 fix: move timeline delete button to tags row, stop squeezing content width
9bba2a2 test: add ReviewCard delete chain verification tests
0ff48ec test: verify ReviewSection with SubSectionContent renders delete button correctly
edb3de6 fix: treat known ### sections as standalone, not SubSectionContent - fixes reflection delete button
```

这一阶段实现随手记、觉察、小确幸的删除。

删除通过条目右侧 `⋯` 菜单触发，点击后确认，再调用 `deleteEntry(date, section, line)`。section 映射为：

```text
quick_notes
reflection
happiness
```

中途发现觉察没有删除按钮。根因是 MarkdownParser 把所有 `###` 标题都当成上一个 `##` section 的子章节，导致 `### 💡 觉察与迭代` 被挂在 `AnxietySection` 下。后来新增 `_isStandaloneSubSection()`，让觉察、人生教练、荔枝喵说、明日寄语、影像等 `###` 标题作为独立 section 解析。修复后觉察成为独立 ReviewSection，删除按钮正常出现。

同时修复了 `⋯` 按钮挤占正文宽度的问题，把操作入口移到标签行右侧。

---

## 16. Sprint 10C：今日页条目编辑

对应提交：

```text
1111e4c feat: Phase 10C - entry edit with BottomSheet, PopupMenu, and rebuildTimelineLine
55f486b fix: EntryEditSheet keyboard overflow with SafeArea+ScrollView, strip # from tags for TagPicker
f16aae0 fix: tighten timeline tag row spacing with compact PopupMenuButton in SizedBox
```

这一阶段实现随手记、觉察、小确幸的编辑。

编辑复用条目右侧 `⋯` 菜单。点击编辑后弹出 EntryEditSheet，预填正文和标签。保存时调用 `rebuildTimelineLine()` 生成 replacement，再调用 editEntry。

编辑只改正文和标签，不改时间、不改条目类型、不改 section。

真机测试确认：时间保持不变，正文写回 Obsidian 正常。

后续修复了两个问题。第一，键盘弹出时 BottomSheet overflow，后来用 SafeArea、SingleChildScrollView 和 viewInsets.bottom 解决。第二，TagPicker 没高亮原标签，根因是 TimelineContent.tags 带 `#`，而 TagConfig.name 不带 `#`，后来在 EntryEditSheet 初始化时 strip `#`。

又修复了添加 `⋯` 后正文和标签之间间距变大的问题。根因是 PopupMenuButton 默认 48×48 撑高标签行，后来改为 28×28 紧凑尺寸。

---

## 17. 跨日自动创建日记

对应提交：

```text
e1dbe4b fix: auto-create diary on load and append retry for cross-midnight usage
```

过 0 点后，App 切到新日期，但新日期日记文件尚未创建，导致第一条随手记写入失败。

修复方案包括两层。

第一，`_loadDiary()` 中如果 `getDiary(date)` 返回 null，则自动调用 `ensureDiary(date)`，再重新读取。

第二，提交记录时如果首次 append 失败，则自动 ensureDiary 并重试一次。

`ensureDiary()` 调用服务端：

```http
POST /api/v1/diary/create
```

该接口幂等，已有日记时不会产生副作用。

真机验证通过：新一天的日记已按默认模板创建，并成功写入第一条随手记。

---

## 18. 当前项目状态

当前 Flutter 端可以定义为：

"荔枝日记 Flutter 文字记录功能对齐版"。

它已经具备日常文字记录 App 的主要能力：跨日自动建日记，随手记、觉察、小确幸可添加、AI 润色、自动标签、编辑、删除；焦虑四问可新建、润色当前回答、编辑替换；习惯可更新；设置页可配置 AI 和提示词；草稿可短时保护；Obsidian 后台同步正常。

尚未完成的主要能力包括：图片添加、画廊页面、历史页、统计页、人生教练功能、标签管理、习惯管理、完整设置管理，以及 Open Design UI 重设计。

---

## 19. Sprint 11-12：图片上传、压缩、显示与删除

对应提交：

```text
970a823 feat: add image upload and media section rendering
8e949d4 feat: image tap-to-preview and delete with confirm dialog
96b3ed0 feat: iterative compression loop with quality + resize, 3MB target
```

这一阶段实现 Flutter 端图片功能 MVP Phase 1 和 Phase 2，包括上传、压缩、显示、预览和删除，复用服务端已有的完整图片能力：

服务端已有：
- `POST /api/v1/diary/image/upload` — 接收 base64 压缩图片，保存为 `Image-YYYYMMDD-NNN.jpg`，追加 `![[filename]]` 到 `## 📸 影像记录`
- `GET /api/v1/diary/image/:year/:imageName?month=:month` — 返回 base64 图片 JSON
- 删除条目时自动清理不再引用的图片文件

Flutter 端实现：

### 19.1 依赖与压缩

新增 `image_picker` 和 `image`（纯 Dart 图片处理）两个依赖。`ImageCompressService` 使用以下策略逐步将图片压缩到 3MB 以内：

1. 长边 > 2000px 时等比缩小到 2000px
2. quality 70 编码 JPEG → ≤ 3MB？返回
3. 逐步降 quality：60 → 50 → 40 → 30
4. 仍 > 3MB：长边 × 0.85 缩小，从 quality 70 重新开始
5. 最小长边 800px（防止无限循环）
6. 最终 best-effort 返回

### 19.2 ApiClient 扩展

新增 `uploadImage()` 和 `fetchDiaryImage()`，分别调用服务端的上传和读取接口。

### 19.3 ImageSectionCard

新建组件，负责：
- 解析 `## 📸 影像记录` section 中的 `![[filename]]` WikiLink
- 通过 `fetchDiaryImage` 加载图片 bytes
- 渲染 120×120 缩略图（loading/error 状态）
- 点击缩略图 → `showDialog` 全屏大图预览（黑色背景，InteractiveViewer 支持缩放）
- 缩略图右上角 ⋮ → "删除" → AlertDialog 确认 → 删除回调

### 19.4 显示路由

`DiaryMarkdownView` 新增 `MediaSection` 路由到 `ImageSectionCard`，传递 `apiClient` 和 `date` 参数。

### 19.5 真机验证

上传后 Obsidian 写入 `![[Image-YYYYMMDD-NNN.jpg]]`，Vault assets 目录生成对应文件，Flutter 刷新后显示缩略图，点击可预览和删除。

---

## 20. 一键生成人生教练（多次迭代）

对应提交：

```text
4e9930b feat: one-click coach generation with action separation
f82f1aa fix: show CoachSection card even when empty so generate button is visible
56b58d4 fix: flexible parseCoachResult + display coach content in card
16500c0 fix: normalize coach output - strict prompt, module parser, markdown cleaning
d007c1a fix: stable coach output - same-type dedup, startsWith matching, empty guard
7acefbd fix: revert to Web-style client-side coach generation with existing server APIs
adcdb86 refactor: delegate coach generation to server endpoint (REVERTED)
393b89b fix: coach card title row height — compact button style to match other sections
65312eb style: unify coach/tomorrow card styling with SectionCard, module titles as small headings
f08695d fix: revert ?trailing syntax, add coach+tomorrow regression tests
886fe09 fix: normalize coach content — handle title+body same-line, ** artifacts, aliases
035c93bf chore: fix use_null_aware_elements lint + remove unused _isCoachModuleTitle
```

这一阶段经历了一次反复的重构，最终稳定在 Web 同款客户端架构。

### 20.1 架构选择（重要经验）

最初选择新增服务端端点 `POST /api/v1/diary/coach/generate`，让服务端统一处理 AI 调用和模块拆分。后来回退到 Web 端同款客户端模式：Flutter 直接调 AI → 正则提取行动建议 → 用已有 `POST /lizhi-says` + `POST /tomorrow` 写入。

**教训**：不要为单一客户端功能新增服务端端点，除非该逻辑必须中心化。Flutter 和 Web 都维护自己的客户端 AI 调用更简单，Web 端经验证的逻辑可以直接在 Flutter 端复刻。

### 20.2 生成逻辑

- PolisherService.generateCoach() — 直接调用 AI 厂商
- PolisherService.splitCoachResultLikeWeb() — 正则提取行动建议模块，写入时分为 lizhiContent 和 actionContent
- 服务端 replaceLizhiSaysSection / replaceTomorrowSection 自动补 `- ` 前缀

### 20.3 格式归一化（多次修补）

AI 输出不稳定导致多次迭代。最终 `_cleanCoachForReplace` 使用 `_extractModuleTitle` + `_normalizeTitle` + `_cleanBodyText` 支持：

- 标题+正文同行拆分：`📌 **模式识别** 今天你展现了…` → `📌 模式识别` + `今天你展现了…`
- Markdown 标记清理：`**`、`###`、`【】`、编号、冒号
- 别名归一化：`主要模式与趋势` → `📌 模式识别`，`潜在矛盾与提醒` → `⚠️ 矛盾指出`，`温暖结语` → `💬 暖心鼓励`
- 正文 bullet 清理：`- - 正文` → `正文`

### 20.4 UI 展示

人生教练卡片从 `Card` + `titleMedium` 改为 `SectionCard`（与其他 section 一致的 13px 标题、左 accent 边线、圆角容器）。
模块标题 📌⚠️💬 降级为小段落标题（bodyMedium + w600 + primary color）。
右侧「重新生成」按钮改为 `VisualDensity.compact` + `shrinkWrap`，避免撑高标题行。

### 20.5 关键修复

- CoachSection 为空时被 `section.isEmpty` 跳过 → 改为 `!CoachSection` 例外
- _buildCoachCard 只渲染按钮不渲染正文 → 新增 `_buildCoachContentWidgets`
- TomorrowSection 不显示 → 测试断言用了 `###` 前缀（实际 parser 已剥除）→ 修复为 `🌙 明日寄语`
- `?trailing` 语法兼容性问题 → 回退为 `if (trailing != null) trailing!`

### 20.6 SectionCard trailing 参数

为支持人生教练卡片右侧的生成按钮，SectionCard 新增可选 `trailing` 参数（Widget?），放入标题行 Row 右侧。

---

## 21. 当前项目状态（2026-06-09）

当前 Flutter 端可以定义为：

"荔枝日记 Flutter 图片 + 文字记录功能对齐版"。

所有文字记录功能已完成并经过多次真机验证：跨日自动建日记，随手记、觉察、小确幸可添加、AI 润色、自动标签、编辑、删除；焦虑四问可新建、润色当前回答、编辑替换；习惯可更新；设置页可配置 AI 和提示词；草稿可短时保护；图片可上传、压缩、预览、删除；人生教练可一键生成（含模块拆分与格式归一化）；Obsidian 后台同步正常。

测试覆盖：227 个 Flutter 测试全部通过，analyze 零问题。

已完成的功能：
- 文字记录（随手记、觉察、小确幸、焦虑四问）CRUD
- AI 润色 + 自动标签（含 retry）
- 习惯追踪（checkbox/counter/water/steps）
- 草稿保护（2 分钟 TTL）
- 图片上传 + 压缩（3MB 上限循环）
- 图片大图预览 + 删除
- 一键生成人生教练（含行动建议拆分）
- CoachSection / TomorrowSection 独立渲染
- SectionCard 统一 UI 样式

开发中的注意事项：
- 人生教练的 AI 输出格式不稳定，`_cleanCoachForReplace` 需要持续兼容各种变体
- 不要新增服务端端点给单一客户端功能
- `section.title` 由 `_sectionHeader` 正则提取，不包含 `###`/`##` 前缀
- SectionCard `trailing` 参数用于标题行右侧控件
- 图片通过 Image.memory 渲染（服务端返回 base64 JSON，不是直接二进制 URL）

---

## 22. Sprint 13：过往页、只读详情与人生教练回归修复

对应提交：

```text
b19105c Fix past diary read-only rendering
428e313 Fix coach fallback and past habit hiding
```

这一阶段新增底部导航，将 App 从单一今日页扩展为「今天 / 过往」两个 tab。

### 22.1 过往页 MVP

新增 `PastScreen`、`PastMemoryService`、`MemoryEntry`、`MemoryCard` 和 `HistoryMonthResult`。

过往页当前不是完整历史管理页，而是记忆回看入口：

- 「今天曾经发生过」：优先取去年同月同日、上个月同日、7 天前的真实记录。
- 「随便走走」：从最近两个月有内容的日期中随机抽取。
- 卡片优先显示图片、小确幸、随手记/觉察摘要；只有前两层为空时才 fallback 显示人生教练摘要。
- 点击卡片进入只读日记详情页。

新增 `ApiClient.fetchHistoryMonth(year, month)`，调用：

```http
GET /api/v1/history/{year}/{month}
```

### 22.2 只读日记详情

新增 `ReadOnlyDiaryScreen`。它复用 `DiaryMarkdownView`，但明确传入：

```dart
readOnly: true
hiddenSections: {'tomorrow', 'habits'}
```

只读详情页定位是回看记忆与成长，不是完整 Obsidian 原文查看器。因此过往详情明确隐藏：

- `明日寄语 / tomorrow`
- `习惯追踪 / 习惯打卡 / habits / habit`

今天页不传 `hiddenSections`，所以今天页继续显示明日寄语和习惯追踪。

### 22.3 人生教练标题与旧格式兼容

过往详情中，旧标题 `荔枝喵说` 统一显示为 `🧠 人生教练`。

`DiaryMarkdownView` 对人生教练展示层做兼容归一化，不修改 Markdown 原文：

- `**模式识别**：正文` → `📌 模式识别` + 正文
- `**矛盾指出**：正文` → `⚠️ 矛盾指出` + 正文
- `**批判性问题**：正文` → `❓ 批判性问题` + 正文
- `**甜点**：正文` → `🍰 甜点` + 正文
- 清理展示中的 `**`、`###` 和存储层 bullet 标记

### 22.4 今天页人生教练按钮回归

一度出现今天页人生教练按钮不显示。最终根因有两层：

1. 前一次安装时构建的是 `app-debug.apk`，但 `flutter install` 实际安装了较旧的 `app-release.apk`，导致真机不是最新代码。
2. 如果当天 Markdown 中根本没有人生教练 section，`DiaryMarkdownView` 没有可渲染的 `CoachSection`，所以即使 `HomeScreen` 传入了 `onGenerateCoach`，按钮也不会出现。

最终修复：

- `HomeScreen` 保持传入 `onGenerateCoach: _handleGenerateCoach` 和 `generatingCoach`。
- `DiaryMarkdownView.readOnly` 默认值保持 `false`。
- 按钮显示条件明确为：

```text
readOnly == false
onGenerateCoach != null
当前 section 是 CoachSection，或当前文档缺少 CoachSection 但允许生成
```

- 当文档缺少人生教练 section 且允许生成时，展示一个空的 `🧠 人生教练` 卡片，按钮显示 `生成今日反馈`。
- 有内容时按钮显示 `重新生成`。
- 只读过往详情不传生成回调，且 `readOnly: true`，所以不显示生成/重新生成按钮。

### 22.5 习惯追踪标题变体

过往详情最初只隐藏 `习惯打卡`，但真实日记中可能使用 `习惯追踪` 标题。修复后：

- `MarkdownParser` 将 `习惯打卡` 和 `习惯追踪` 都识别为 `HabitSection`。
- `DiaryMarkdownView.hiddenSections` 同时按 section type 和标题文本判断。
- 过往详情隐藏 `习惯追踪` 标题变体。
- 今天页不受影响，习惯仍可交互。

### 22.6 Android release 网络权限

release 版曾出现无法连接远程服务端。根因是 Android Manifest 缺少网络权限。

已在 `android/app/src/main/AndroidManifest.xml` 添加：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 22.7 验证状态

截至提交 `428e313`：

- `dart analyze lib test`：通过
- `flutter analyze`：通过
- `flutter test`：238 个测试全部通过
- `flutter build apk --release`：通过
- 最新 release APK 已安装到 PLG110 真机
- 用户真机确认：本轮回归修复成功

### 22.8 当前项目状态（2026-06-11）

当前 Flutter 端可以定义为：

"荔枝日记 Flutter 文字 + 图片 + 过往回看功能对齐版"。

已完成：

- 今日页日记读取与结构化展示
- 随手记、觉察、小确幸、焦虑四问写入
- AI 润色与自动标签
- 条目编辑、删除
- 习惯追踪交互
- 草稿 2 分钟 TTL
- 图片上传、压缩、显示、预览、删除
- 人生教练一键生成与旧格式展示兼容
- 明日寄语展示
- 过往页记忆卡片
- 过往只读详情
- 过往详情隐藏明日寄语和习惯追踪
- release 版远程服务端连接

尚未完成或后续再做：

- 完整日历式历史页
- 统计页
- 画廊页
- 标签管理设置
- 习惯管理设置
- 远程 API 配置编辑
- Open Design 全局 UI 重设计

---

## 23. Sprint 14：顶部 UI 小修与真机安装方式修正

对应提交：

```text
dd5adef Fix top headers on today and past pages
17f75c1 Keep past page header fixed
```

这一阶段只做 UI 修复，不改服务端、不改 Markdown、不改记录、图片、习惯、焦虑、人生教练等业务逻辑。

### 23.1 今天页 header 调整

今天页原来顶部同时显示：

```text
荔枝日记
YYYY年M月D日 星期X
已连接服务器
```

修复后：

- 不再显示顶部「荔枝日记」。
- 不再显示「已连接服务器」提示文案。
- 当前日期作为 AppBar 主标题显示。
- 右上角设置按钮保留。
- 仅隐藏连接状态 UI 文案，不影响 API 连接和错误提示逻辑。

根因：`HomeScreen` 的 `AppBar.title` 仍写死为 `荔枝日记`，body 里又重复显示日期和连接状态。

### 23.2 过往页状态栏重叠

过往页标题曾与系统状态栏重叠。

修复方式：

- `PastScreen` 外层使用 `SafeArea`。
- 页面内容从安全区域下方开始显示。

根因：`PastScreen` 没有 AppBar，也没有 SafeArea，ListView 从 Scaffold 顶部直接开始布局。

### 23.3 过往页 header 固定

用户进一步确认：`过往 / 看看那些已经走过的日子` 应固定在页面顶部，不随下面记忆内容滚动。

最终结构：

```text
SafeArea
└── Column
    ├── 固定 header：过往 + 副标题
    └── Expanded
        └── RefreshIndicator
            └── ListView：今天曾经发生过 / 随便走走 / 记忆卡
```

这样滚动时只滚动记忆内容，header 保持固定。

### 23.4 真机安装方式修正

此前每次真机验证后都需要重新输入远程 token。根因是使用了：

```bash
flutter install --release
```

该命令日志中会出现 `Uninstalling old version...`，卸载旧版会清空 App 本地数据，包括 `flutter_secure_storage` 中保存的 baseUrl/token。

后续真机覆盖安装应使用：

```bash
/Users/yezi/development/flutter/bin/flutter build apk --release
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
```

`adb install -r` 是覆盖安装，不会先卸载旧版。在同 packageId、同签名、非降级安装时，它能保留本地配置和 token。

### 23.5 验证状态

截至提交 `17f75c1`：

- `dart analyze lib test`：通过
- `flutter analyze`：通过
- `flutter test`：240 个测试全部通过
- `flutter build apk --release`：通过
- 用户确认本轮 UI 修复成功

---

## 24. Sprint 15：习惯统计页面完整优化

对应提交：

```text
b731b60 refactor: dropdown habit selector + remove group cards + avg text
be29c5c perf: phased loading + concurrency + static cache for habit stats
c2dfb67 feat: persistent cache for habit stats cold-start
718f700 fix: inject mock cache repo in HabitStatsScreen widget tests
3196c7a chore: cache namespace scoping, habit section parsing, test settle
d5b23c6 fix: heatmap overflow + cross-month test client
```

这一阶段对「习惯统计」页面进行了三轮迭代优化：UI 结构重设计 → 加载性能 → 持久化缓存。

### 24.1 UI 结构重设计

原有问题：
- 30 天热力图用 TabBar 横向切换，页面宽度不足时图标文字显示不全
- 仍有「照顾身体」「照顾成长」两个独立分组卡，信息重复
- 没有 30 天平均值描述

修复后：
- TabBar → `DropdownButton` 下拉选择器，单一习惯展示
- 删除 `HabitGroupCard` 文件，分组统计融入热力图下方
- 新增 30 天平均值文案：数值型「最近 30 天，平均每天饮水 xxxx mL」、布尔型「最近 30 天，完成了 x/30 天」
- 固定 header 标题「习惯统计」，副标题「看看最近的生活节奏」

### 24.2 加载性能优化

根因分析：
- `loadStats()` 一次性串行加载全部 30 天日记（`for` + 逐日 `await getDiary`）
- 30 个网络请求串行等待，首帧白屏十几秒

优化方案：
- 新增 `lib/services/concurrent.dart`：`mapWithConcurrency(concurrency: 4)` 并发工具
- `HabitStatsService` 拆分为 `loadRecent7()` + `loadRecent30()` 两阶段
  - 阶段 1：优先加载 7 天，并发 4，先显示反馈卡 + 节奏谱
  - 阶段 2：后台加载剩余 23 天，复用已缓存的 7 天记录
- 静态 `_dayCache` + `_historyMonthCache`，跨 tab 切换复用
- 屏幕端分阶段 UI：header 立即显示 → skeleton → 7 天优先 → 30 天后台

### 24.3 持久化缓存

根因：静态内存缓存在 App 进程内有效，但冷启动时丢失。

方案：
- 新建 `lib/services/habit_stats_cache_repository.dart`
- 使用 `flutter_secure_storage`（已有依赖），序列化完整 `HabitStats`
- `HabitStatsCacheStorage` 可注入接口，支持测试 mock
- `HabitStatsScreen` cache-first 加载：
  - 有缓存 → 立即显示 + 轻量横幅「正在更新最新节奏…」+ 后台刷新
  - 无缓存 → skeleton loading
  - 刷新成功 → 更新 UI + 写入缓存
  - 刷新失败 → 保留旧缓存，不白屏
- schema version 校验，不匹配时安全忽略

### 24.4 辅助修正

- `_HabitTestHttpClient` 跨月请求返回正确数据
- 热力图 `SizedBox` 高度 180 → 130，修复测试 overflow
- 缓存 namespace 隔离（`identityHashCode`），防止不同 `ApiClient` 实例缓存污染
- `MarkdownParser`：`习惯打卡`/`习惯追踪` 纳入独立 section 识别

### 24.5 小确幸展示优化 + DeepSeek 模型修正

对应提交：

```text
1c49772 feat: happiness rendering rewrite + DeepSeek default model fix
002556c feat: DeepSeek model empty fallback to deepseek-v4-flash
```

**小确幸**：不再使用 Timeline UI。
- 单条：纯文本段落展示
- 多条（≥2）：bullet list（`•` 前缀）
- 新增 `_buildHappinessSection()`，`HappinessSection` 全部走此路径

**DeepSeek**：
- `ai_config.dart` → `aiPresets` 中 DeepSeek 模型 `deepseek-chat` → `deepseek-v4-flash`
- 新增 `AIConfig.resolvedModel`：baseUrl 含 `deepseek` 且 model 为空时自动 fallback
- 用户已保存的模型配置不受影响

### 24.6 验证状态

截至提交 `002556c`：

- `dart analyze lib/ test/`：通过
- `flutter test`：268 个测试全部通过
- 用户真机验收通过

---

## 25. Sprint 16：导航结构调整——移除设置 Tab

### 25.1 背景

设置页被放入了底部导航栏作为第 4 个 Tab，不符合最终产品设计。设置属于配置入口，不应与今天、过往、习惯三个核心工作区平级。

### 25.2 改动内容

导航结构调整：

- 底部导航栏从 4 个 Tab 恢复为 3 个：今天 / 过往 / 习惯
- 移除设置 Tab 及其对应的 `SettingsPage` 路由
- 今天页右上角齿轮按钮 `IconButton(icon: Icons.settings_outlined)` 从跳转 `AiSettingsScreen` 改为跳转 `SettingsPage`
- `SettingsPage` 内容完全保留（外观占位、习惯设置占位、标签设置占位、远程 API、AI 服务配置、润色提示词、图片压缩、关于）

### 25.3 文件修改

| 文件 | 改动 |
|------|------|
| `lib/main.dart` | 移除设置 Tab 的 NavigationDestination 和 SettingsPage screen；清理不再使用的 `settings_page.dart` import |
| `lib/screens/home_screen.dart` | 齿轮按钮导航目标从 `AiSettingsScreen` 改为 `SettingsPage`；添加 `settings_page.dart` import；移除不再使用的 `ai_settings_screen.dart` import |

### 25.4 未改动

- `SettingsPage` 内容
- 子页面（远程 API、AI 服务配置、图片压缩、关于）
- `IndexedStack` 结构（仍保持 3 个页面状态）
- 今天页/过往页/习惯页内部逻辑

### 25.5 验证状态

对应提交：`6c69ab8`

- `flutter analyze`：零问题
- `flutter test`：285 个测试全部通过
- 模拟器真机运行验证通过（Android 16, API 36）

---

## 26. Sprint 17：习惯设置归档刷新与设置页状态修复

### 26.1 背景

代码审查发现近期习惯设置相关改动存在几个风险：

- 习惯设置文件已在工作区存在，但统计页刷新链路没有可靠接入新的活跃习惯列表。
- `HabitStatsScreen` 在 `build()` 中触发异步刷新，且没有先重新读取设置，导致归档后统计页可能继续显示旧习惯。
- `HabitStatsService` 会复用内存中的完整统计结果，但没有区分不同 active habit keys。
- 远程 API 页固定显示 `Token 状态：已配置`，在排查真机连接问题时容易误导。

### 26.2 改动内容

习惯统计刷新：

- `MainScreen` 增加 `refreshToken` 机制：切到「习惯」Tab 时通知 `HabitStatsScreen` 刷新。
- `HabitStatsScreen` 移除 `build()` 中的异步检查逻辑，改为在 `didUpdateWidget()` 中响应明确刷新信号。
- `_loadFresh(force: true)` 每次都会重新读取 `HabitSettingsRepository`，并使用最新 active keys 重新计算统计。
- 下拉刷新也继续清理缓存并重新读取习惯设置。

统计服务缓存：

- `HabitStatsService` 增加 active key signature。
- 只有当完整统计缓存和当前 active keys 匹配时才复用内存统计。
- 当归档/恢复习惯后，统计项会基于同一批日记数据重新计算，不再残留已归档习惯。

设置页状态：

- `ApiClient` 增加 `hasToken` 只读状态。
- `SettingsPage` / `RemoteApiPage` 只传递 token 是否已配置，不展示真实 token。
- 远程 API 页根据真实配置状态显示 `已配置` 或 `未配置`，不再固定写死。

### 26.3 文件修改

| 文件 | 改动 |
|------|------|
| `lib/main.dart` | 为习惯 Tab 增加刷新 token |
| `lib/screens/habit_stats_screen.dart` | 接收刷新 token；移除 build 异步副作用；强制刷新时重读习惯设置 |
| `lib/services/habit_stats_service.dart` | 增加 active key signature，避免复用不匹配的统计缓存 |
| `lib/services/habit_settings_repository.dart` | 保存失败向上抛出，交给页面现有回滚逻辑处理 |
| `lib/services/api_client.dart` | 增加 `hasToken` |
| `lib/screens/home_screen.dart` | 设置页入口传递 token 配置状态 |
| `lib/screens/settings_page.dart` | 透传 token 配置状态到远程 API 页 |
| `lib/screens/remote_api_page.dart` | 按真实状态显示 Token 状态 |
| `test/widget_test.dart` | 增加习惯归档刷新与远程 API 状态测试 |

### 26.4 验证状态

截至当前工作区：

- `flutter analyze lib/ test/`：通过
- `flutter test`：287 个测试全部通过

### 26.5 注意事项

- 本次不修改服务端。
- 本次不修改 Markdown 原文。
- 习惯归档仍然只是客户端显示/统计过滤，不删除历史习惯数据。
- 真机覆盖安装继续使用 `adb install -r` 或等价覆盖方式，避免清空本地 baseUrl/token。

---

## 27. Sprint 17 补充：习惯视觉配置回归修复

### 27.1 背景

习惯设置页面真机验证通过后，代码审查继续发现两个体验/一致性问题：

- 习惯统计页重新读取设置时只同步 active keys，未同步完整 `HabitSettings`，导致自定义名称、图标、颜色可能没有进入统计页。
- 今天页习惯卡只显示自定义图标，不显示默认图标；默认习惯缺少 `💧`、`🚶`、`📖` 等视觉锚点，不利于快速扫读。

### 27.2 改动内容

- `HabitStatsScreen` 在初次加载和刷新设置时同步完整 `HabitSettings`。
- `HabitStatsService` 增加实例级缓存重置和视觉配置签名，确保名称/图标/颜色变更后重新构建统计项。
- `HomeScreen` 从设置页返回后同步完整 `HabitSettings`，今天页可立即使用最新视觉配置。
- `HabitCard` 默认显示习惯图标：自定义图标优先，否则显示默认图标。

### 27.3 测试补充

- `HabitStatsScreen uses custom habit visual settings in stats`：覆盖统计页使用自定义名称、图标、颜色。
- `HabitCard shows default habit icons`：覆盖今天页习惯卡显示默认图标。

### 27.4 验证状态

截至当前提交前：

- `flutter analyze lib/ test/`：通过
- `flutter test`：289 个测试全部通过
- `flutter build apk --release`：通过，生成 `build/app/outputs/flutter-apk/app-release.apk`

### 27.5 真机验证说明

本轮尝试使用 `adb install -r` 覆盖安装真机包，但当前执行环境仍出现：

```text
could not install *smartsocket* listener: Operation not permitted
```

因此 APK 已构建完成，但安装环节需在本机终端执行覆盖安装后继续验收。该问题属于本地 ADB daemon 权限限制，不是 Flutter 构建失败。

---

## 28. Sprint 28：标签设置 MVP

### 28.1 目标

实现标签设置 MVP，允许用户管理标签配置：编辑显示名称、启用/隐藏标签、恢复默认。不修改服务端，不修改历史 Markdown，不新增/删除标签。

### 28.2 新增文件

| 文件 | 职责 |
|------|------|
| `lib/models/tag_settings.dart` | TagSettings 数据模型，以 id 为稳定 key |
| `lib/services/tag_settings_repository.dart` | 本地 FlutterSecureStorage 持久化 |
| `lib/screens/tag_settings_page.dart` | 标签设置 UI：编辑名称、Switch 启用、恢复默认 |
| `lib/services/tag_settings_helper.dart` | 辅助函数：effectiveTagConfig、hiddenInitialTags、countEnabled、validateDisplayName |

### 28.3 关键设计决策

- **稳定 key**：使用现有的 `id` 字段（如 `parenting-interact-play`），不引入新标识符。
- **displayName 接入 TagPicker**：上层计算 `effectiveTagConfig`（过滤 disabled + name 替换为 displayName），TagPicker 无感知。
- **hidden 标签处理**：编辑旧记录时，`TagSettingsHelper.hiddenInitialTags()` 找出隐藏标签，TagPicker 以灰色 `(已隐藏)` 芯片展示；用户不手动取消则保留在输出中。
- **AI 润色过滤**：`PolishResultParser` 新增 `_getDisabledTagNames()`，返回 disabled 标签的 displayName + defaultName，disabled 标签既不被提取为 tag，也不保留在润色正文中。

### 28.4 修改文件

| 文件 | 改动 |
|------|------|
| `lib/screens/settings_page.dart` | 标签设置入口改为真实 TagSettingsPage，显示已启用标签数 |
| `lib/widgets/tag_picker.dart` | 新增 hiddenInitialTags 参数，隐藏标签显示灰色芯片 |
| `lib/widgets/entry_edit_sheet.dart` | 接受 TagSettings，计算 hiddenInitialTags |
| `lib/services/polish_result_parser.dart` | 过滤 disabled 标签，匹配 displayName，清除正文 |
| `lib/services/polisher_service.dart` | 传递 tagSettings 到 parser |
| `lib/widgets/quick_note_timeline.dart` | 传递 tagSettings |
| `lib/widgets/generic_section_card.dart` | 传递 tagSettings |
| `lib/widgets/review_card.dart` | 传递 tagSettings |
| `lib/widgets/diary_markdown_view.dart` | 接受 tagSettings 参数 |
| `lib/screens/home_screen.dart` | 加载 TagSettings，设置页返回后刷新 |
| `test/widget_test.dart` | 新增 12 个 TagSettings 测试 |

### 28.5 验证状态

截至当前：

- `flutter analyze lib/ test/`：零问题
- `flutter test`：303 个测试全部通过
- `flutter build apk --release`：通过，55MB
- 模拟器真机验证：修改标签名称、启用/隐藏、AI 润色过滤、编辑旧记录保留、恢复全部默认全部通过

### 28.6 注意事项

- TagSettings 由 settings_page 创建 ApiClient 加载 TagConfig，通过 TagSettingsRepository 读写本地存储。
- home_screen 从设置页返回时调用 `_loadTagConfig()` 刷新 `_tagSettings`，触发 `_effectiveTagConfig` getter 重新计算。
- 隐藏标签通过两层过滤：`_getAllKnownTags` 只含 enabled 标签 → 不会提取为 tag；`_getDisabledTagNames` 标记 disabled 标签 → 正文中清除。
- 编辑旧记录时，`_TimelineDeleteRow` 和 `_QuickNoteRow` 均传递 tagSettings 到 EntryEditSheet。

---

## 29. Sprint 29：快速记录入口 V2/V3

### 29.1 背景

今天页早期存在内联快速记录卡片：通过 Tab 在随手记、觉察、小确幸、焦虑四问之间切换。真实使用后确认，首页内联输入区会挤压阅读空间，也让入口分散。

本轮目标是让右下角 FAB 成为 Flora 唯一的快速记录入口。首页恢复为“内容展示 + FAB”，记录行为进入对应二级页面或调用既有图片上传流程。

### 29.2 改动内容

- 新增 `QuickCaptureScreen`：随手记、觉察、小确幸共用独立二级记录页。
- 新增 `AnxietyScreen`：焦虑四问进入独立页面，继续复用 `AnxietyComposer` 的逐问润色、草稿、保存逻辑。
- 今日页删除内联快速记录卡片，不再显示随手记/觉察/小确幸/焦虑 Tab。
- FAB 展开为 icon-only 圆形子按钮：`✍️`、`💡`、`✨`、`😰`、`📸`。
- FAB 子按钮改用极坐标计算位置，避免手写固定坐标。
- 根据使用频率调整入口顺序：随手记、觉察、小确幸优先，焦虑四问和图片作为相对低频入口。
- 焦虑四问输入区域放大：第一问 5 行，其余问题 4 行，保留最多 8 行自动扩展。

### 29.3 当前 FAB 参数

| 项目 | 数值 |
|------|------|
| 主按钮尺寸 | 56dp |
| 子按钮视觉尺寸 | 42dp |
| 子按钮点击热区 | 48dp |
| 扇形半径 | 120dp |
| 随手记角度 | 180° |
| 觉察角度 | 155° |
| 小确幸角度 | 130° |
| 焦虑四问角度 | 105° |
| 图片角度 | 82° |

### 29.4 关键边界

- 本轮不修改服务端。
- 本轮不修改 Markdown 格式。
- FAB 子入口不重写保存逻辑，只复用现有 `QuickCaptureScreen`、`AnxietyScreen` 和 `_handleImageUpload()`。
- 焦虑四问不再回到首页旧快速记录区。

### 29.5 验证状态

- `dart analyze lib test`：通过
- Flutter 级 `analyze --no-pub`：通过
- `flutter build apk --release`：通过，生成 `build/app/outputs/flutter-apk/app-release.apk`
- 真机验证：快速记录入口功能正常

### 29.6 注意事项

当前执行环境运行 `flutter test` 时，Flutter tester 无法创建本地临时 socket：

```text
Failed to create server socket (OS Error: Operation not permitted)
```

该限制来自当前沙箱环境，不是测试用例本身失败。相关 FAB 和焦虑页面测试已随实现更新，后续在本机普通终端可继续运行完整 `flutter test`。

---

## 30. Sprint 30：启动兜底、标签兜底与习惯图标稳定性修复

### 30.1 背景

真机替换 SVG 图标后，连续暴露出几类稳定性问题：

- App 启动时可能一直停在 loading。
- 有空日记文件但没有随手记、小确幸、觉察、焦虑内容时，今天页无法显示习惯打卡入口。
- 习惯设置页面中默认图标和候选图标仍有 emoji 残留，未完全按 Flora Icon System 替换。
- 设置页「标签设置」在标签配置加载失败时静默失败，表现为入口点不开。
- 快速记录页偶发显示「标签暂不可用」，导致添加记录时不能选择标签。

### 30.2 关键原因

- `AppEntry` 读取远程配置时没有超时/异常兜底，安全存储读取异常或挂住时可能造成启动 loading 不结束。
- `HomeScreen` 加载今日日记时没有请求超时，远程请求挂住时可能造成今日页 loading 不结束。
- 空日记或缺少 habit section 时，旧渲染链路不会主动补出可交互的 `HabitCard`。
- 习惯视觉配置仍以 emoji 文本作为默认值；多个 UI 位置直接 `Text(icon)`，无法渲染 Flora SVG 图标。
- `TagRepository.loadTagConfig()` 远程失败时抛错，`SettingsPage._openTagSettings()` 又静默吞掉异常。
- `HomeScreen` 在标签配置异步加载完成前打开 `QuickCaptureScreen`，会传入空 `tagConfig`。

### 30.3 改动内容

- `lib/main.dart`
  - `ApiConfig.load()` 增加 5 秒超时和异常兜底。
  - 配置读取失败时进入配置流程，不再无限 loading。

- `lib/screens/home_screen.dart`
  - 今日日记 `getDiary()` / `ensureDiary()` 增加 12 秒超时。
  - 空日记状态显示 fallback `HabitCard`。
  - `_effectiveTagConfig` 在远程标签配置未完成时先使用 `DefaultTagConfig.value`。
  - 标签加载失败时写入默认标签配置与默认标签设置，避免快速记录页显示「标签暂不可用」。

- `lib/models/diary_document.dart`
  - 新增 `HabitSection.empty()`，作为空日记和缺失习惯 section 的最小可交互习惯模型。

- `lib/models/default_tag_config.dart`
  - 新增 Flutter 内置默认标签配置，与服务端默认标签表保持一致。
  - 用于远程标签配置和本地缓存都不可用时的兜底。

- `lib/services/tag_repository.dart`
  - 缓存读取和写入改为 best-effort。
  - 远程刷新增加超时。
  - 远程和缓存都不可用时返回 `DefaultTagConfig.value`。

- `lib/screens/settings_page.dart`
  - 标签设置入口使用 `TagRepository` 兜底结果。
  - 测试用可注入 `ApiClient`，用于覆盖远程失败时仍可进入标签设置页。

- `lib/models/habit_visual_config.dart`
  - 默认习惯图标从 emoji 改为 Flora icon 逻辑名。

- `lib/widgets/habit_icon.dart`
  - 新增 `HabitIcon`：新配置渲染 `FloraIcon`，旧用户设置中保存过的 emoji 继续以文本显示。

- `lib/screens/habit_edit_screen.dart`
  - 习惯候选图标从 emoji 切换为 Flora icon 逻辑名。
  - 包含默认习惯图标与候选图标池。

- `lib/screens/habit_settings_screen.dart`
- `lib/widgets/habit_card.dart`
- `lib/widgets/habit_heatmap_tabs.dart`
- `lib/widgets/habit_rhythm_grid.dart`
  - 统一改用 `HabitIcon`，避免把 `habit-water` 等逻辑名显示成文本。

- `lib/widgets/flora_icon.dart`
  - 增加 `FloraIcons.hasAsset()`。
  - 空路径时使用安全 fallback，避免未配置 SVG 时渲染异常。

### 30.4 测试补充

`test/widget_test.dart` 新增或更新覆盖：

- HomeScreen 空日记时显示 `HabitCard`。
- 日记请求挂住时退出 loading 并显示错误与习惯入口。
- 可编辑日记视图缺少 habit section 时补 fallback habit card。
- 默认习惯图标解析为 Flora assets。
- 习惯编辑页「目标」候选图标使用 Flora icon 并可点击。
- 标签接口失败时，`TagRepository` 返回默认标签配置。
- 标签接口失败时，SettingsPage 仍可进入标签设置页。
- 快速记录页在标签远程配置不可用时仍显示 `TagPicker`，不显示「标签暂不可用」。

### 30.5 当前验证状态

截至提交 `85fb246`：

- `dart analyze lib test`：通过
- `flutter analyze --no-pub`：通过
- `flutter test --no-pub`：359 项全部通过
- `flutter build apk --release`：通过

### 30.6 后续注意事项

- 标签配置兜底是 Flutter 端可用性保护，不替代服务端标签配置；远程配置正常时仍优先使用服务端与缓存。
- 习惯图标设置中的旧 emoji 配置必须继续兼容，不能强制迁移或丢弃用户自定义值。
- 不要在习惯相关 UI 中直接 `Text(icon)`；统一走 `HabitIcon`。
- 标签设置入口不要静默失败，至少应使用默认标签配置打开页面。
- 快速记录页应优先保证可记录，不应因标签远程请求失败阻塞用户输入。

---

## 31. Sprint 31：品牌视觉源图落地

### 31.1 背景

品牌视觉重构过程中，启动页、桌面 App 图标和关于页品牌图一度使用了重新生成的近似图。用户明确要求不要重新设计品牌方向，也不要重新生成相似图，而是使用 `docs/design-reference/` 目录里的原始图作为权威来源。

### 31.2 改动内容

- `docs/design-reference/splash.png` 作为启动页源图，派生到 `assets/icon/brand-splash-reference.png`。
- `docs/design-reference/icon.png` 作为 App 图标和关于页品牌图源图，派生到 `assets/icon/app-icon.png`、`assets/icon/app-launcher.png` 和 Android launcher mipmap 资源。
- `docs/design-reference/reference.png` 保留为整体视觉参考，不作为直接切图资源。
- `FloraSplash` 改为全屏展示 splash 原图，不再在 Flutter 里重新排版「荔枝日记」和副标题。
- `AboutPage` 继续展示品牌图、版本与更新内容，品牌图尺寸真机调整到 168dp。
- Android launcher 图标重新生成，保留原始视觉比例和系统桌面安全留白。

### 31.3 项目规则更新

- 品牌源图目录固定为 `docs/design-reference/`。
- 启动页、App 图标、关于页品牌图后续都应从源图派生，不要手绘或 AI 生成近似版本。
- 更换 launcher 图标后必须重新构建并重装 APK；桌面图标不会通过 hot reload 更新。

### 31.4 当前验证状态

截至本轮品牌视觉确认：

- `flutter analyze --no-pub`：通过
- `flutter test --no-pub`：364 项全部通过
- `flutter build apk --release --no-pub`：通过
- `adb install -r build/app/outputs/flutter-apk/app-release.apk`：成功
- 真机验证：App 图标通过，关于页品牌图尺寸通过
