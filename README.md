# 荔枝日记

Flutter 原生日记客户端与 TypeScript／Express API 服务端，内容长期保存在自己的 Obsidian Vault。客户端负责阅读、输入、交互与缓存，`server/` 负责 Markdown 读写和 Obsidian 兼容。

当前客户端清单为 `1.10.0+42`，包含四项导航、浅白／浅桃粉主题、年趋势及标签显示优化；具体 APK、验证日期与手机安装状态见 [HANDOFF.md](HANDOFF.md)，不以旧构建或旧真机反馈替代本轮验收。

## 当前能力

- 四个主页面通过贴底通栏玻璃导航切换：今天、过往、习惯、设置。二级页面隐藏导航，设置内可调整外观、习惯、标签及服务器连接。
- 今天页展示日记、习惯、回顾和图片；右下角竖排菜单进入小确幸、觉察、随手记。三种记录共用原生输入、发生时间、标签和短时草稿；空白提示不写入内容。
- 今天可新增、编辑和删除记录；多段正文按完整原始块操作。随手记与小确幸可关联最多 9 张照片，正文后展示，编辑删除保护其他引用。
- 三种记录在今天与历史详情统一展示已保存时间和时间轴；正文两端对齐，阅读字号为 14／16／18sp。阅读标签独立为 10–12sp 单行，超长省略保留全文语义，窄屏操作可移到下一行。
- 内置与自定义习惯、饮水／步数目标、时长专注计时、静音完成反馈，以及当年趋势摘要和最近26周点阵热力图。
- 过往按月照片画廊、月历、当天多图预览和只读历史详情；历史补录只支持随手记、觉察、小确幸，保存前不创建空日记。
- AI 服务手动配置、连接测试、润色与自动标签、今日回顾；请求有超时与错误分类，密钥不出现在提示或日志中。
- 旧焦虑记录只读兼容；新版服务端模板不再创建焦虑四问，已有文件不迁移。
- 暖纸浅深色主题、独立阅读字号、Lucide 静态图标、少量 Lordicon 单次动画与减少动态效果支持。

## 数据与离线

服务端是 Markdown 写入权威。Flutter 消费 Parser 产生的领域模型，不直接操作 Vault；同步由外部云盘客户端负责，已撤回的 ZIP／WebDAV 备份不提供。

阅读副本按规范化服务器地址及凭据摘要隔离，日记／索引最多 50MB、图片最多 200MB。访问时先显示缓存再联网更新；图片七天后尝试后台更新，离线保留可读旧图。设置可清理图片或全部阅读缓存，不删除配置、短时草稿或服务器文件。系统可能回收缓存，缓存不能替代备份。

离线只支持已缓存内容阅读，不新增、编辑、删除或自动补交。今天页只有 GET 明确 404 才允许创建；网络、权限或服务器错误不当作没有日记。写入成功后使相关阅读、画廊与统计缓存失效，过期响应不能回填。

## 开发与验证

开发和 CI 基线为 Flutter 3.44.2／Dart 3.12.2、Node.js 22。安装依赖后执行：

```bash
flutter pub get
flutter analyze
flutter test

cd server
npm ci
npm test
npm run build
```

文档整理需检查 `git diff --check`、链接、路径与当前清单；完整验证要求以 [AGENTS.md](AGENTS.md) 为准。实际结果统一记在交接文档，README 不滚动累积测试数量。

## 服务端配置与运行

首次复制本地配置模板，然后填写 Vault 路径和自有 Token；私有 `server/config.json` 禁止提交。

```bash
cd server
cp config.example.json config.json
npm ci
npm run build
npm run dev
```

```json
{
  "vaultPath": "/path/to/your/Obsidian Vault",
  "apiToken": "<YOUR_PRIVATE_TOKEN>",
  "port": 4001,
  "allowedOrigins": []
}
```

`allowedOrigins` 为空时保留本地调试与真机访问兼容；需要限制浏览器来源时填写白名单。原生 Flutter 不依赖浏览器 CORS。

健康检查为 `GET /health`。画廊通过 `/api/v1/history/gallery?cursor=YYYY-MM&limit=3` 分页，只索引已有安全附件；图片渲染使用 `/api/v1/diary/image/render/:year/:imageName?month=MM&maxWidth=...`，不向 Vault 写缩略图。趋势快照接口 `/api/v1/stats/habit?from=YYYY-MM-DD&to=YYYY-MM-DD` 只读取最多 366 天，周期聚合由客户端完成。

服务端源码合并不表示运行环境已部署。更新需保留私有配置和 Vault，部署、重启及真实健康检查见 [docs/RELEASE.md](docs/RELEASE.md)。

## Android 构建与覆盖安装

```bash
flutter build apk --release
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
```

日常覆盖安装使用 `adb install -r`；同包名、同签名且非降级时保留本地连接配置。内部 Release 沿用原 debug 证书和 `com.example.litchi_journal_flutter`，不是商店正式包。可选商店模式必须提供正式包名与本地签名，缺配置拒绝构建。iOS 需另行完成构建和设备验收。

只有明确准备发布新版本时才修改 `pubspec.yaml` 与对应 CHANGELOG 版本。构建测试包、代码合并、服务端部署和真机验收分别记录，完整流程与权限说明见 [发布说明](docs/RELEASE.md)。

## 项目文档

| 文档 | 职责 |
|---|---|
| [AGENTS.md](AGENTS.md) | 稳定开发规则、架构与数据安全边界 |
| [HANDOFF.md](HANDOFF.md) | 最近交付、当前验证、已知阻塞和待验收事项 |
| [CHANGELOG.md](CHANGELOG.md) | 用户可感知的版本变化及未单独升版的主线增量 |
| [README.md](README.md) | 使用入口、能力、开发命令与构建流程 |
| [PLAN.md](PLAN.md) | 已确认需求、开发进度与后续安排 |

视觉规则见 [DESIGN.md](DESIGN.md)，品牌源图在 `docs/design-reference/`，许可见 [第三方声明](docs/THIRD_PARTY_NOTICES.md)。旧计划和交接保存在 `docs/archive/`；`SESSION_LOG.md` 仅供历史追溯，不再更新。接手先读 AGENTS、HANDOFF 与 PLAN，按需查详细设计和历史方案。
