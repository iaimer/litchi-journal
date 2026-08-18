# 荔枝日记

荔枝日记当前仓库包含 Flutter 原生客户端和 API 服务端。

Flutter 客户端负责 UI、状态管理和 API 调用；`server/` 负责 Markdown 读写、Obsidian Vault 兼容和数据同步。原 Web 端服务端已经迁入本仓库，后续服务端开发以这里为准。

## 当前状态

当前版本定位：

```text
Flutter 客户端 + 本仓库 API 服务端版
```

截至 2026-08-04，已完成：

- 今日页日记读取与结构化展示
- 随手记、觉察、小确幸、焦虑四问写入
- 快速记录 FAB：右下角扇形入口统一进入随手记、觉察、小确幸、焦虑四问和图片上传
- 统一记录页：随手记、觉察、小确幸使用独立二级记录页，焦虑四问使用独立问答页
- AI 润色与自动标签
- AI 服务配置支持 OpenCode Go 预设与请求级连接测试
- 条目编辑、删除与发生时间修改；新增或编辑后，当前 Markdown section 内的时间条目自动按 `HH:mm` 排序
- 习惯追踪交互
- 习惯默认图标与候选图标 SVG 化，兼容旧 emoji 配置
- 标签设置与快速记录标签选择，远程标签配置不可用时使用 Flutter 本地默认兜底
- 图片上传、压缩、显示、预览、删除
- 人生教练一键生成与旧格式展示兼容
- 明日寄语展示
- 过往页记忆卡片
- 过往月历：按月选择指定历史日期，有真实记录或相片的日期显示圆点
- 过往只读详情；已有历史内容不开放编辑或删除
- 历史补录：支持为指定过去日期补录随手记、觉察、小确幸和最多 9 张相片
- 无日记历史日期仅在首次真正保存时创建标准日记，避免误触产生空文件
- 过往详情隐藏明日寄语和习惯追踪
- 过往页固定 header，不随内容滚动
- Android release 版远程服务端连接
- 远程 API 配置编辑：支持在设置页修改服务器地址，并复用当前 Token 测试连接后保存
- 远程 API 地址保存后即时生效，不再需要重启 App
- 启动配置读取、今日日记加载和标签配置加载的超时/兜底保护
- API / AI 请求超时保护与可操作错误提示，图片上传失败会显示具体原因
- 品牌视觉资源落地：启动页、App 图标、关于页品牌图均使用 `docs/design-reference/` 中的原始参考图派生
- Today Rainbow 模块视觉：随手记红、小确幸橙、焦虑黄、觉察绿、人生教练青、明日寄语蓝、影像记录紫
- 日记正文标签 chip 跟随所在模块色，快速记录页 TagPicker 使用领域不同、主题统一、方法统一的稳定标签色规则
- 习惯统计热力图 icon-only Tab 切换：图标一次性展示，使用滑块式 Tab 指示器和轻量动效

## 关键文档

文档体系共 6 份，合并与精简后以此为准：

- `AGENTS.md` — 项目知识库：规则、架构、数据完整性与开发约束。
- `PLAN.md` — 产品需求（定位、用户故事、实现决策）与路线图、开发进度。
- `DESIGN.md` — 设计语言：色彩、排版、组件、Flora 图标与空状态规范。
- `SESSION_LOG.md` — 逐次开发会话记录和验证状态。
- `CHANGELOG.md` — 版本发布记录。
- `docs/design-reference/` — 品牌视觉源图，更新启动页或 App 图标时优先读取这里。

新 agent 接手前应先阅读 `AGENTS.md`、`PLAN.md`、`SESSION_LOG.md`。

## 验证命令

```bash
/Users/yezi/development/flutter/bin/cache/dart-sdk/bin/dart analyze lib test
/Users/yezi/development/flutter/bin/flutter analyze
/Users/yezi/development/flutter/bin/flutter test
```

构建并安装 release 包：

```bash
/Users/yezi/development/flutter/bin/flutter build apk --release
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
```

注意：真机验证前必须先构建对应模式。日常覆盖安装要用 `adb install -r`，在同 packageId、同签名、非降级安装时会保留本地 baseUrl/token。不要用 `flutter install --release` 做日常覆盖安装，因为它可能先卸载旧版，导致 token 丢失。

## 发布检查清单

发布前请确认：

- [ ] 更新 `pubspec.yaml` 中的 `version`
- [ ] 更新 `CHANGELOG.md` 对应版本内容
- [ ] `dart analyze` 无问题
- [ ] `flutter test` 全部通过
- [ ] `flutter build apk --release` 构建成功
- [ ] 真机安装验证核心功能
- [ ] 关于页显示正确版本号与当前版本更新内容
- [ ] 外观主题设置：三种模式均正常工作，深色模式主要页面可读
- [ ] 标签设置、AI 润色正常

## 后续方向

短期优先验证历史补录的数据完整性和多图上传体验，不建议立刻新增大功能。

可规划但尚未完成：

- 画廊页
- Open Design 全局 UI 重设计

## 服务端

服务端位于 `server/`，是从原 Web 项目迁入的 TypeScript/Express API。

本地配置不会提交到 Git。第一次运行前复制模板：

```bash
cd server
cp config.example.json config.json
```

然后编辑 `config.json`：

```json
{
  "vaultPath": "/path/to/your/Obsidian Vault",
  "apiToken": "<YOUR_PRIVATE_TOKEN>",
  "port": 4001,
  "allowedOrigins": []
}
```

`allowedOrigins` 为空数组时保持当前本地调试和真机访问兼容；需要限制浏览器跨域来源时填写允许的 Origin 列表。原生 Flutter 客户端不依赖浏览器 CORS。

常用命令：

```bash
cd server
npm install
npm run build
npm test
npm run dev
```

Mac mini 部署：

```bash
cd server
./deploy.sh
```

健康检查：

```bash
curl http://localhost:4001/health
```

图片上传接口已支持可选 `imagePrefix`。旧客户端不传时继续生成 `Image-YYYYMMDD-NNN.jpg`；Flutter 新客户端传入合法前缀时会生成 `{prefix}-YYYYMMDD-NNN.jpg`。
