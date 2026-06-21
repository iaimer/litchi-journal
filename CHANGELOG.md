# Changelog

## 1.4.0

### 新增
- 习惯设置页分区：启用中的习惯 / 已归档
- 新增/重命名习惯同名校验，提示「已存在同名习惯」
- 自定义习惯进入统计页：aliases 历史名称匹配，完整 7 天/30 天统计
- HabitSettings 新增 customHabitAliases 字段（schemaVersion 4）

### 优化
- 归档自定义习惯后统计页主视图隐藏
- 重新启用后统计恢复显示，aliases 继续匹配历史 Markdown
- 名称输入前后空格自动 trim

### 架构
- 统计逻辑全部在 Flutter 客户端完成，服务端不参与统计聚合
- customHabitAliases 不写入 Markdown，不写 custom key
- 旧数据兼容：version < 4 时 customHabitAliases 默认 {}

---

## 1.3.0

### 新增
- 自定义普通打卡习惯：设置页新增、编辑、归档、今日页显示、打卡写入 Markdown

### 优化
- 习惯系统边界明确：App 负责习惯定义，服务端只负责打卡写入，Markdown 只保存完成状态

## 1.2.1

### 修复
- FAB 图标：收起状态显示加号，展开显示叉号（原 FloraIcons.close 映射错误为 plus SVG）
- 日记详情页下拉刷新背景色统一为 scaffoldBackgroundColor

### 优化
- SectionCard 移除左侧强调竖线
- 饮水快捷按钮：「目标」改为「自定义」毫升数输入
- 运动步数编辑弹窗输入框默认空白
- 关于页更新内容使用 MarkdownBody 渲染

## 1.2.0

### 新增
- FloraPageScaffold：轻量统一页面骨架组件（Scaffold + AppBar + body SafeArea）
- Android 12+ 原生启动屏配置：消除冷启动时 App 图标居中闪现

### 优化
- 设置页骨架统一：10 个设置页面接入 FloraPageScaffold，统一 SafeArea 和底部留白
- 一级页 SafeArea：HomeScreen / PastScreen / HabitStatsScreen 补底部安全区
- 输入页 SafeArea：QuickCaptureScreen / AnxietyScreen 补底部安全区
- 卡片样式一致：ImageSectionCard 接入 SectionCard；GenericSectionCard / QuickNoteTimeline / HabitCard accentColor 改为 theme primary
- SectionCard 左侧强调竖线移除，标题区更轻盈
- 快速记录工具栏对齐：AI 润色按钮与标签展开入口合并到同一行
- TagPicker 标签布局修复
- 关于页更新内容使用 MarkdownBody 渲染
- 饮水快捷按钮优化：「目标」改为「自定义」毫升数输入；运动步数编辑默认空白
- 日记详情页下拉刷新背景色统一为 scaffoldBackgroundColor

## 1.1.0

### 新增
- 外观设置：支持跟随系统、浅色模式、深色模式
- 习惯设置：支持自定义习惯名称、图标、颜色和启用状态
- 标签设置：支持隐藏标签、重命名标签，并在编辑旧记录时保留隐藏标签
- 快速记录入口：今天页右下角 FAB 扇形菜单，支持随手记、觉察、小确幸、焦虑四问和图片入口
- 统一记录页：随手记、觉察、小确幸进入独立记录页面；焦虑四问进入独立问答页面

### 优化
- 今天页、过往页、习惯统计页与设置页的手机端布局
- 品牌视觉资源：启动页使用 `docs/design-reference/splash.png` 原始图，App 图标与关于页品牌图使用 `docs/design-reference/icon.png` 派生资源
- Android launcher 图标重新生成，保留原始视觉比例和系统桌面安全留白
- 习惯统计页缓存与刷新体验
- 过往详情页只读展示逻辑
- 快速记录扇形菜单：圆形 icon-only 子按钮、极坐标布局、按使用频率调整入口顺序
- 焦虑四问独立页面输入区域，保留逐问润色和原保存逻辑
- 习惯默认图标与候选图标统一使用 Flora SVG 图标，并兼容旧 emoji 配置
- 标签配置增加 Flutter 本地默认兜底，远程标签接口暂不可用时记录页仍可选标签

### 修复
- 人生教练按钮显示与旧格式渲染问题
- 过往详情隐藏明日寄语和习惯追踪
- 真机重复输入远程 Token 的安装验证流程问题
- 深色模式下主要页面的可读性
- 启动配置读取或今日日记请求挂住时 App 一直转圈
- 有空日记文件但没有正文 section 时今天页缺少习惯打卡入口
- 标签设置入口在标签配置加载失败时静默点不开
- 快速记录页偶发显示「标签暂不可用」
- 关于页品牌图四角黑边、尺寸过大或过小的问题

## 1.0.0

### 新增
- 今天页面记录能力：随手记、觉察、小确幸、焦虑四问
- AI 润色与自动标签
- 习惯追踪（饮水、步数、阅读、语言、补充剂）
- 过往页面（随机记忆卡片、过去日记详情）
- 习惯统计页（热力图、节奏谱、反馈卡）
- 设置页：习惯设置、标签设置、AI 服务配置、润色提示词、图片压缩
- 图片上传、压缩、预览、删除
- 人生教练功能（生成、重新生成、明日寄语拆分写入）
- 远程 API 配置
- 底部导航（今天 / 过往 / 习惯）

### 优化
- 小确幸 HTML 格式到 Markdown 格式的兼容展示
- 人生教练旧格式（荔枝喵说）展示归一化
- 编辑弹窗键盘避让与保存体验
- 习惯统计缓存与冷启动加载速度

### 修复
- 跨日自动创建日记
- 焦虑四问编辑时草稿 2 分钟 TTL
- 编辑旧记录时隐藏标签不丢失
- AI 润色结果保留隐藏标签问题
- 图片删除范围错误
- 过往详情人生教练渲染问题
