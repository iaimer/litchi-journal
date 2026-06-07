# 荔枝日记 Flutter 客户端项目规则

## 产品定位

荔枝日记 Flutter 客户端是独立的原生产品，不是 Web 版复刻。

Flutter 客户端负责：

- 阅读体验
- 输入体验
- 交互体验
- 状态管理
- API 调用

Flutter 客户端不负责：

- Markdown 文件读写
- Obsidian 兼容细节
- Syncthing 同步
- 服务端业务逻辑
- 数据库存储

服务端负责：

- Markdown 读写
- Obsidian Vault 兼容
- 数据同步
- API 输出

## 架构原则

不要把 Markdown 当作 UI。Markdown 只是存储格式，Obsidian 只是内容仓库。

客户端后续开发应遵循这条数据流：

```text
Markdown
↓
Parser
↓
领域模型
↓
Flutter 原生组件
```

也就是说：

- Markdown 解析应集中在 Parser 层。
- UI 组件应消费领域模型，而不是直接消费 Markdown 文本。
- 页面不应该散落 `##`、`> [!quote]`、`- [x]` 等 Markdown 规则判断。
- 如需兼容旧 Markdown 格式，兼容逻辑应放在 Parser 层。

## 领域模型方向

Flutter 端已建立的领域组件：

- 习惯打卡 → `HabitCard`（checkbox toggle + counter 快捷按钮）
- 随手记 → `QuickNoteTimeline`（条目渲染 + 编辑/删除）
- 焦虑时刻 → `AnxietyCard` / `AnxietyComposer`
- 觉察 → `ReviewCard` → `GenericSectionCard`（含 `_TimelineDeleteRow`）
- 小确幸 → `GenericSectionCard`（含 `_TimelineDeleteRow`）
- Callout → `_buildCallout`（在 `GenericSectionCard` 内）

组件命名应表达产品语义，而不是 Markdown 语法。

## 开发约束

- 优先保持简单。
- 不做过度架构设计。
- 不引入复杂依赖。
- 不创建未来可能用到但现在不需要的代码。
- 不新增功能来顺手解决设计问题。
- 每次改动只处理当前阶段目标。
- 保持现有 API 和服务端边界不变，除非任务明确要求。
- 不记录、不输出 Token 或其他敏感信息。

## UI 迁移原则

可以借鉴 Web 端的视觉语言，但不要迁移 Web 技术栈，也不要逐像素复刻。

应该迁移的是：

- 产品气质
- 信息层级
- 阅读节奏
- 颜色关系
- 交互意图

不应该迁移的是：

- React/Tailwind 结构
- Web 弹窗模式
- Web 页面导航
- 为 Web 端服务的状态组织方式

Flutter UI 应优先使用原生组件表达领域对象。

## 验证要求

修改后必须运行：

```bash
flutter analyze
flutter test
```

涉及视觉体验时，优先使用真机截图验收。真机设备：PLG110 (Android 16)，无线 ADB 连接。
当前状态：180 测试全部通过，analyze 零问题。

## 数据完整性规则

以下规则从开发中沉淀，所有写入类改动必须遵守：

- **rawLine 不可反推**：编辑/删除时必须使用 Parser 解析的原始 rawLine，不能用 content + tags 重新组装 target 或 line。
- **tags 前缀差异**：`TimelineContent.tags` 存储带 `#` 前缀（如 `['#育儿']`），TagPicker 和 `_selectedTags` 存储不带 `#`（如 `['育儿']`）。EntryEditSheet 初始化时须 strip `#`。
- **### 独立 section**：`###` 标题中觉察/人生教练/荔枝喵说/明日寄语/影像 应作为独立 DiarySection，不能作为 SubSectionContent 嵌套在父 section 中。
- **跨日自动创建**：`_loadDiary()` 中如果 `getDiary(date)` 返回 null，须调用 `ensureDiary(date)` 后再重新读取。提交记录时首次失败须 ensureDiary 并重试。
- **草稿 TTL 2 分钟**：草稿目的是短时保护（刷新/切换入口/短暂离开），不是长期草稿箱。过期自动清除。
- **AI 润色分场景**：普通入口（quickNote/reflection/happiness）走 `polish()`，返回 tags；焦虑走 `polishPlainText()`，不含标签。
- **create 文件格式**：Flutter 不本地拼 Markdown 模板，服务端 `POST /api/v1/diary/create` 负责生成。
- **不泄露 API Key**：不在 toString、error、log、SnackBar、test failure message 中出现。

## 项目文档

- `docs/DEV_SUMMARY.md` — Sprint 1-18 完整开发历程
- `docs/DEV_PLAN.md` — 后续 P0-P4 开发优先级与路线图

