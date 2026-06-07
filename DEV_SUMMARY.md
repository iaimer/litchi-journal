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
