# 荔枝日记项目规则

## 产品定位

荔枝日记当前仓库包含 Flutter 原生客户端和 `server/` API 服务端。Flutter 客户端是独立的原生产品，不是 Web 版复刻；原 Web 端服务端已经迁入本仓库，后续服务端开发以 `server/` 为准。

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

服务端代码位置：

- `server/` — TypeScript/Express API 服务端
- `server/config.example.json` — 本地配置模板
- `server/config.json` — 本地私有配置，禁止提交

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
- 快速记录入口 → 今日页右下角 FAB 扇形菜单，统一进入 `QuickCaptureScreen`、`AnxietyScreen` 或图片上传
- 觉察 → `ReviewCard` → `GenericSectionCard`（含 `_TimelineDeleteRow`）
- 小确幸 → `GenericSectionCard`（含 `_TimelineDeleteRow`）
- Callout → `_buildCallout`（在 `GenericSectionCard` 内）

组件命名应表达产品语义，而不是 Markdown 语法。

## 快速记录入口规则

- 今天页只保留日记内容展示和右下角快速记录 FAB，不再放置首页内联快速记录输入区。
- FAB 子入口只负责路由或调用已有处理函数，不重写保存逻辑。
- 随手记、觉察、小确幸统一进入 `QuickCaptureScreen`。
- 焦虑四问进入 `AnxietyScreen`，继续复用 `AnxietyComposer` 的逐问润色与保存逻辑。
- 图片入口直接调用现有图片选择、压缩、上传、刷新流程。
- FAB 扇形菜单使用极坐标计算位置；避免回退到手写固定 x/y 坐标。

## 配置兜底规则

- 启动配置、今日日记和标签配置加载都必须有超时或兜底，不能让 UI 无限 loading。
- 标签配置优先使用服务端 `/api/v1/settings/tags` 或本地缓存；远程与缓存都不可用时，Flutter 使用 `DefaultTagConfig.value`。
- 快速记录页不应因为远程标签配置暂不可用而显示「标签暂不可用」；默认标签至少要保证用户可以完成记录。
- 设置页的「标签设置」入口不能静默失败；远程标签加载失败时也应打开基于默认标签配置的设置页。

## Flora 图标规则

- 习惯默认图标和习惯候选图标使用 `FloraIcon` 逻辑名称，而不是直接保存新的 emoji。
- 习惯展示统一经过 `HabitIcon`：新配置渲染 SVG，旧用户配置中保存过的 emoji 继续兼容显示。
- 不要在习惯卡、习惯设置页或习惯统计页直接 `Text(icon)`，否则会把 `habit-water` 等逻辑名称显示成文本。

## Today Rainbow 视觉规则

- 模块色顺序固定为：随手记红、小确幸橙、焦虑黄、觉察绿、人生教练青、明日寄语蓝、影像记录紫。
- 当前色值：随手记 `#FF6B6B`，小确幸 `#FF9F43`，焦虑 `#FFD43B`，觉察 `#51CF66`，人生教练 `#12B5CB`，明日寄语 `#4DABF7`，影像记录 `#9775FA`。
- 日记正文标签 chip 在模块上下文中跟随模块色；无模块上下文时才回退到标签类型色。
- 快速记录页 `TagPicker` 使用独立标签色规则：领域按固定色板区分，主题统一 `#F2C94C`，方法统一 `#9775FA`。
- 不要把模块颜色、标签颜色写入 Markdown。

## 品牌资源规则

- `docs/design-reference/` 是荔枝日记品牌视觉源图目录。
- 启动页必须从 `docs/design-reference/splash.png` 派生到 `assets/icon/brand-splash-reference.png`，不要重新绘制近似版本。
- App 图标和关于页品牌图必须从 `docs/design-reference/icon.png` 派生到 `assets/icon/app-icon.png`、`assets/icon/app-launcher.png` 和 Android launcher mipmap 资源。
- `docs/design-reference/reference.png` 仅作为整体视觉参考，不作为直接切图资源。
- 关于页品牌图当前使用 168dp 展示尺寸；如需调整，先真机比对后再改。
- 更新品牌资源时必须重新构建并重装 APK，系统桌面图标不会只靠 hot reload 更新。

## 开发约束

- 优先保持简单。
- 不做过度架构设计。
- 不引入复杂依赖。
- 不创建未来可能用到但现在不需要的代码。
- 不新增功能来顺手解决设计问题。
- 每次改动只处理当前阶段目标。
- 保持现有 API 和服务端边界不变，除非任务明确要求。
- 不记录、不输出 Token 或其他敏感信息。

### 先思考，后编码

不要假设。如有不确定，先提问。如果存在多种解释，全部列出再决定。如果有更简单的方法，请说出来。

### 精准修改

- 只动必须改的地方，只清理自己改动造成的遗留问题。
- 不要"改进"相邻代码、注释或格式。
- 不要重构没坏的代码。
- 不要随意修改已有函数签名。
- 如果发现无关的废弃代码，可以提一句——但不要删除。
- 因你的改动而产生的无用代码（import、变量等）需要清理。

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

## 编码准则

### 可读性优先
- 代码是给人读的，其次才是机器执行。
- 必要时加简洁注释：解释**为什么**，不是**做什么**。
- 不写废话注释（如 `i++ // 增加 i`）。
- 变量名表达意图，不用 `tmp`、`data`、`obj` 等泛命名。

### 模块化
- 按功能拆分文件，避免巨型文件和万能函数。
- 一个函数只做一件事，控制长度 < 50 行，嵌套不超过 3 层。
- 多用 early return 减少嵌套。

### 错误处理
- 不吞异常，提供清晰可操作的错误信息。
- 考虑边界情况：空值、异常输入，提供合理默认行为。

### 一致性
- 保持代码风格统一，遵循项目已有规范优先于个人习惯。
- 匹配现有风格，即使自己会有不同做法。

## 目标驱动执行

**定义成功标准，循环验证直到达标。**

将任务转化为可验证的目标：
- "添加校验" → "为无效输入编写测试，然后让测试通过"
- "修复这个 bug" → "编写能复现它的测试，然后让测试通过"
- "重构 X" → "确保重构前后测试都通过"

对于多步骤任务，给出简要计划并逐步骤验证。

## 验证要求

修改后必须运行：

```bash
flutter analyze
flutter test
```

涉及视觉体验时，优先使用真机截图验收。真机设备：PLG110 (Android 16)，无线 ADB 连接。
当前状态：363 测试全部通过，analyze 零问题。

## 数据完整性规则

以下规则从开发中沉淀，所有写入类改动必须遵守：

- **rawLine 不可反推**：编辑/删除时必须使用 Parser 解析的原始 rawLine，不能用 content + tags 重新组装 target 或 line。
- **tags 前缀差异**：`TimelineContent.tags` 存储带 `#` 前缀（如 `['#育儿']`），TagPicker 和 `_selectedTags` 存储不带 `#`（如 `['育儿']`）。EntryEditSheet 初始化时须 strip `#`。
- **### 独立 section**：`###` 标题中觉察/人生教练/荔枝喵说/明日寄语/影像 应作为独立 DiarySection，不能作为 SubSectionContent 嵌套在父 section 中。
- **跨日自动创建**：`_loadDiary()` 中如果 `getDiary(date)` 返回 null，须调用 `ensureDiary(date)` 后再重新读取。提交记录时首次失败须 ensureDiary 并重试。
- **草稿 TTL 2 分钟**：草稿目的是短时保护（刷新/切换入口/短暂离开），不是长期草稿箱。过期自动清除。
- **AI 润色分场景**：普通入口（quickNote/reflection/happiness）走 `polish()`，返回 tags；焦虑走 `polishPlainText()`，不含标签。
- **标签配置兜底**：`TagRepository.loadTagConfig()` 失败时必须返回 `DefaultTagConfig.value`；缓存读写失败不能让标签功能不可用。
- **create 文件格式**：Flutter 不本地拼 Markdown 模板，服务端 `POST /api/v1/diary/create` 负责生成。
- **不泄露 API Key**：不在 toString、error、log、SnackBar、test failure message 中出现。

## 项目文档

- `docs/DEV_SUMMARY.md` — Sprint 1-18 完整开发历程
- `docs/DEV_PLAN.md` — 后续 P0-P4 开发优先级与路线图

## 语言要求

**全程使用中文。** 包括对话回复、代码注释、思考过程、agent 内部推理均使用中文。仅代码、标识符、文件路径、shell 命令、技术术语保留原文。

除非用户明确要求使用英文，否则所有面向用户和非面向用户的输出都应使用中文。
