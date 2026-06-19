# 荔枝日记

荔枝日记当前仓库包含 Flutter 原生客户端和 API 服务端。

Flutter 客户端负责 UI、状态管理和 API 调用；`server/` 负责 Markdown 读写、Obsidian Vault 兼容和数据同步。原 Web 端服务端已经迁入本仓库，后续服务端开发以这里为准。

## 当前状态

当前版本定位：

```text
Flutter 客户端 + 本仓库 API 服务端版
```

截至 2026-06-19，已完成：

- 今日页日记读取与结构化展示
- 随手记、觉察、小确幸、焦虑四问写入
- 快速记录 FAB：右下角扇形入口统一进入随手记、觉察、小确幸、焦虑四问和图片上传
- 统一记录页：随手记、觉察、小确幸使用独立二级记录页，焦虑四问使用独立问答页
- AI 润色与自动标签
- 条目编辑、删除
- 习惯追踪交互
- 习惯默认图标与候选图标 SVG 化，兼容旧 emoji 配置
- 标签设置与快速记录标签选择，远程标签配置不可用时使用 Flutter 本地默认兜底
- 图片上传、压缩、显示、预览、删除
- 人生教练一键生成与旧格式展示兼容
- 明日寄语展示
- 过往页记忆卡片
- 过往只读详情
- 过往详情隐藏明日寄语和习惯追踪
- 过往页固定 header，不随内容滚动
- Android release 版远程服务端连接
- 启动配置读取、今日日记加载和标签配置加载的超时/兜底保护

## 关键文档

- `AGENTS.md`：项目规则、边界和开发约束。
- `docs/DEV_SUMMARY.md`：完整开发历程和已完成能力。
- `docs/DEV_PLAN.md`：后续开发计划与当前待办。
- `SESSION_LOG.md`：阶段性会话记录和验证状态。

新 agent 接手前应先阅读以上四个文件。

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

## 后续方向

短期优先稳定观察和小修，不建议立刻新增大功能。

可规划但尚未完成：

- 完整日历式历史页
- 画廊页
- 远程 API 配置编辑
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
  "port": 4001
}
```

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
