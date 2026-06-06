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

后续应逐步从 `DiaryEntry.raw` 过渡到 Flutter 端领域模型，例如：

- 习惯打卡 → `HabitCard`
- 随手记 → `QuickNoteTimeline`
- 焦虑时刻 → `ReflectionCard`
- 每日复盘 → `ReviewCard`
- 人生教练 → `CoachCard`
- Callout → `CalloutCard`

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

修改后尽量运行：

```bash
/Users/yezi/development/flutter/bin/flutter analyze
/Users/yezi/development/flutter/bin/flutter test
```

涉及视觉体验时，优先使用模拟器截图验收。

## 当前推荐路线

下一阶段优先做领域化重构，而不是继续堆 Markdown 渲染规则：

1. 提取 `DiaryParser`
2. 建立 `DailyJournal` 等领域模型
3. 将当前 Markdown 阅读视图拆成原生领域组件
4. 让 `HomeScreen` 只负责加载、刷新、保存和组件编排

