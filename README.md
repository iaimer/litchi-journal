# 荔枝日记 Flutter 客户端

荔枝日记 Flutter 客户端是独立的原生移动端产品，不是 Web 端复刻。

客户端负责 UI、状态管理和 API 调用；服务端负责 Markdown 读写、Obsidian Vault 兼容和数据同步。

## 当前状态

当前版本定位：

```text
文字 + 图片 + 过往回看功能对齐版
```

截至提交 `428e313`，已完成：

- 今日页日记读取与结构化展示
- 随手记、觉察、小确幸、焦虑四问写入
- AI 润色与自动标签
- 条目编辑、删除
- 习惯追踪交互
- 图片上传、压缩、显示、预览、删除
- 人生教练一键生成与旧格式展示兼容
- 明日寄语展示
- 过往页记忆卡片
- 过往只读详情
- 过往详情隐藏明日寄语和习惯追踪
- Android release 版远程服务端连接

## 关键文档

- `AGENTS.md`：项目规则、边界和开发约束。
- `docs/DEV_SUMMARY.md`：完整开发历程和已完成能力。
- `docs/DEV_PLAN.md`：后续开发计划与当前待办。

新 agent 接手前应先阅读以上三个文件。

## 验证命令

```bash
/Users/yezi/development/flutter/bin/cache/dart-sdk/bin/dart analyze lib test
/Users/yezi/development/flutter/bin/flutter analyze
/Users/yezi/development/flutter/bin/flutter test
```

构建并安装 release 包：

```bash
/Users/yezi/development/flutter/bin/flutter build apk --release
/Users/yezi/development/flutter/bin/flutter install --release -d <device-id>
```

注意：真机验证前必须先构建对应模式。只构建 debug 却安装 release，会导致手机上不是最新代码。

## 后续方向

短期优先稳定观察和小修，不建议立刻新增大功能。

可规划但尚未完成：

- 完整日历式历史页
- 统计页
- 画廊页
- 标签管理设置
- 习惯管理设置
- 远程 API 配置编辑
- Open Design 全局 UI 重设计
