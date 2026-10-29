# 安全审计报告 · 2026-10-29

| 项目 | 内容 |
| :-- | :-- |
| 审计对象 | 整个仓库：Flutter 客户端（`lib/`、`android/`）+ API 服务端（`server/src`） |
| 源版本 | `b544781`（分支 `codex/ponytail-slim-20261029`）+ 未提交改动（19 改 / 1 删 / 2 新增），以磁盘现状为准 |
| 审计范围 | 客户端与服务端全部源码、Android 打包配置、CI、部署脚本、PM2 配置 |
| 方法 | security-audit 完整流程：4 路侦察 → 25 个覆盖单元 → 3 轮狩猎（9 个 hunter）→ 2 轮覆盖批评 → 5 个候选各由独立验证员复核 |
| 执行限制 | 本机无法施加所需的 OS 强制沙箱，**未执行任何目标代码或测试**；结论为源码级，运行时后果标注为待验证 |
| 结论 | 无高危/严重漏洞；1 条待验证线索，4 条候选经复核否决，14 项加固建议 |

## 1. 结论摘要

**没有发现高危或严重漏洞。** 认证、路径包含、原子写盘、移动端凭据与备份这四条主线做得比一般自建笔记服务更扎实，并有回归测试守着。

需要动手的是：

- **1 条待验证线索**：未认证请求会先解压并解析最多 10MB JSON 才返回 401（预认证放大）。机制由源码确定，可用性后果与端口可达性待确认。
- **4 条候选经独立复核否决**：客户端明文传输、标签配置符号链接写入、`readDiary` 符号链接读取、习惯时长 rawLine 回退。其中后两条的底层是真实缺陷，但不构成跨主体越权，应作为普通 bug 修。
- **14 项加固建议**：P1 五项值得本周改，其余按性价比排。

## 2. 方法与限制

### 2.1 怎么做

1. **侦察**：4 个只读代理分别梳理产品与部署形态、参与方与权限、入口面与 sink、本地可执行能力。
2. **覆盖单元**：按「入口 × 边界 × 子系统 × 攻击类」拆出 25 个单元，每个单元记录起始路径、所选攻击类、排除的攻击类及排除理由。
3. **狩猎**：3 轮共 9 个 hunter，每轮后由独立覆盖批评者检查漏项；最终清洁批评确认无遗漏单元、无 reassignment。
4. **验证**：5 个候选各交给一个未参与狩猎的独立验证员，逐行重读源码并尝试推翻。

### 2.2 硬限制

本机无法满足方法要求的 OS 强制沙箱：

- `/usr/bin/sandbox-exec` 存在，但任何 profile 都以 `sandbox_apply: Operation not permitted` 失败（exit 71）；
- 无 Linux namespace / `bwrap` / cgroups；
- `RLIMIT_AS` 无法设置，也没有墙钟限制器。

因此**没有执行任何目标代码、测试或服务端进程**，全部结论为源码级。需要运行时观测的后果按方法要求只能标为「待验证」，并给出所有者可安全执行的观测方式。

### 2.3 目标形态

单拥有者个人日记产品：一名拥有者在自己的 Mac mini 上运行 Express 服务端，用 Android 客户端读写自己 Obsidian Vault 中的 Markdown 与照片。没有多租户、没有账号体系，全系统只有一份静态 `apiToken`。这一点决定了大量「同一主体自损」的候选不能算作安全边界问题。

## 3. 已确认的控制（不必改）

| 边界 | 控制 | 位置 |
| :-- | :-- | :-- |
| 网络 → API | 严格 `Token ` 前缀 + 等长 `timingSafeEqual`；缺失/空/占位 Token 拒绝启动 | [auth.ts](../server/src/middleware/auth.ts#L12-L31)、[config/index.ts](../server/src/config/index.ts#L13-L21) |
| 请求 → 文件系统 | 日期严格回环校验；图片名白名单 + `resolve`/`relative`/`realpath`/`isFile` 四重；删除附件前做全库引用扫描 | [date.ts](../server/src/utils/date.ts#L33-L43)、[vault.ts](../server/src/services/vault.ts#L191-L221)、[diary.ts](../server/src/routes/diary.ts#L1209-L1240) |
| 写盘 | `wx` 临时文件 + `fsync` + `rename`，失败保留完整旧文件；上传独占创建，文件名由服务端生成 | [vault.ts](../server/src/services/vault.ts#L60-L97)、[diary.ts](../server/src/routes/diary.ts#L787-L806) |
| 启动清理 | 只删「超 24h + 严格 UUIDv4 + 与现存日记字节完全一致」的副本，`lstat` 不跟随链接 | [vault-temp-cleanup.ts](../server/src/services/vault-temp-cleanup.ts#L5-L35) |
| 幂等 | 严格 UUID `diary-op` 标记由服务端生成，用户内容续行带缩进无法伪造 | [diary.ts](../server/src/routes/diary.ts#L184-L203) |
| 客户端凭据 | Token/AI Key 全在 `FlutterSecureStorage`；无 `print`；错误文案只给状态码；展示用配置显式清空 Token | [api_config.dart](../lib/services/api_config.dart#L4-L25)、[main.dart](../lib/main.dart#L207-L210) |
| 本地缓存 | 文件名 = `sha256(namespace)-sha256(key)`，namespace 含凭据摘要；401/403 清副本；50MB/200MB 有界 LRU | [reading_cache_repository.dart](../lib/services/reading_cache_repository.dart#L57-L61)、[api_client.dart](../lib/services/api_client.dart#L43-L55) |
| 移动平台 | `allowBackup=false` + 云端/换机双规则全量排除；唯一 exported 是 launcher，无 deep link、无 provider、无 WebView | [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml#L5-L7) |
| AI 数据流 | 日记正文只发往用户显式启用的 baseUrl；厂商私有参数按精确 host+path+port 门槛；连接测试结果绑定配置修订号 | [polisher_service.dart](../lib/services/polisher_service.dart#L610-L633) |
| 渲染 | `flutter_markdown` 无 HTML 渲染器、全仓无 `onTapLink`；WikiLink 文件名经 `Uri.encodeComponent` 单段拼接 | [generic_section_card.dart](../lib/widgets/generic_section_card.dart#L170-L174)、[api_client.dart](../lib/services/api_client.dart#L439-L442) |
| 验证数据 | 服务端测试全部 `vi.mock` 配置 + `node:os.tmpdir()` 临时 Vault，不读真实配置 | [diary.test.ts](../server/src/routes/diary.test.ts#L12-L24) |
| CI | `permissions: contents: read`、`persist-credentials: false`、锁文件不被改写 | [ci.yml](../.github/workflows/ci.yml#L8-L9) |

## 4. 待验证线索

### F1 未认证请求先解压解析再 401（预认证放大）

**指纹**：`server/src/index.ts:express.json-10mb-before-auth:pre-auth-body-inflate-parse`

**位置**：[index.ts](../server/src/index.ts#L29-L36)

**机制**：挂载顺序是 `cors` → `express.json({limit:'10mb'})` → `/health` → `authMiddleware`。这两者之间没有任何代码需要请求体，但 body parser 已对所有请求生效。锁定的 body-parser 1.20.5 默认 `inflate: true`，gzip 请求体会先被 `zlib.createGunzip()` 解压；`read.js` 取完 `stream.length` 后立即置 `undefined`，使 raw-body 的 Content-Length 预检失效；10MB 上限只与**解压后**字节比较，随后在认证之前执行 `JSON.parse` 并构造对象图。

**后果**：约 10–20KB 的 gzip 体即可驱动单进程 Node 完成 10MB 级解压与解析。仓库没有速率限制、并发上限或请求超时；PM2 为 `instances: 1`、`max_memory_restart: '1G'`，触顶即重启。任何能连到 4001 端口的对端都能施加这份成本。

**为什么只标待验证**：机制完全由源码确定，但可用性后果（并发到何种程度会触发重启）需要运行时观测，而本机不允许执行；端口可达性（`app.listen(PORT)` 已确定绑定全部接口，剩下的是 macOS 防火墙/NAT 与所处网段）也属仓库外事实。

**复现条件**（在可用沙箱内）：复刻中间件顺序的最小 Express 应用 + `zlib.gzipSync` 生成解压后约 10MB 的高重复 JSON，带 `Content-Type: application/json`、`Content-Encoding: gzip`，不带 `Authorization`，断言返回 401 而非 413/400，并记录 401 之前的耗时与 `heapUsed`；对照组把 `express.json` 移到认证之后。

**最小修复**（所有消费 body 的路由都在认证之后，无兼容成本）：

```ts
app.use(cors(corsOptions));
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});
app.use(authMiddleware);
app.use(express.json({ limit: '10mb' }));
```

**回归测试**：新增一条中间件顺序测试，发未带 `Authorization` + `Content-Encoding: gzip` 的大体量 JSON，断言在读取 body 之前就返回 401（可用 spy 证明 body parser 未被调用）。

**所有者可自行确认的三件事**（只读，不发送审计流量）：

1. `lsof -nP -iTCP:4001 -sTCP:LISTEN` 确认绑定地址；
2. `socketfilterfw --getglobalstate` 确认主机防火墙状态；
3. 确认 Mac mini 所连网段是否只有本人设备。

## 5. 已否决的候选

记录下来是为了以后不重复怀疑同一件事，也说明各自的残余价值。四条都已完成机制核对与主体判定。

| 候选 | 机制是否成立 | 否决理由 | 保留价值 |
| :-- | :-- | :-- | :-- |
| 客户端不设 https 下限 | 成立 | baseUrl 的唯一写入点是两个 owner 手输入口，仓库无 deep link / 设置导入 / 服务端下发；`targetSdk 36` 下平台默认拒绝明文；默认值与文档推荐均为 https，唯一 `http` 提示指向 Tailscale 隧道 | 地址变更对话框对非 https 给一次明确提示 |
| 标签配置 `writeFileSync` 跟随符号链接 | 成立 | 全仓无 HTTP 可达的建链原语，其他写入口都用 `wx` 或 `rename`；能放链接者权限已不低于服务端用户 | 整表截断写非原子、无旧副本、坏文件让 GET 永久 500 —— 按普通 bug 修 |
| `readDiary` 无 `realpath`/`isFile`，`raw` 全文回传 | 成立 | 与上一条同源：链接只能带外植入，植入者已握有 Vault 写权限；FIFO 变体是同主体自损 | 对齐 `resolveSafeImagePath` 的读取纪律（见加固 3） |
| 习惯时长 rawLine 过期时按标签回退 | 部分成立 | 标签回退是原地更新、不产生重复行；重复行只在「rawLine 过期且标签也改名」这一支，且既有测试明确断言了兼容行为。无更低信任主体 | 真实的数据完整性缺陷：过期来源会产生重复习惯行，之后 `/habit` 一直 409（见加固 6） |

## 6. 加固清单

### P1 · 值得本周改

| # | 事项 | 位置 | 理由 |
| :-- | :-- | :-- | :-- |
| 1 | `express.json` 移到认证之后 | [index.ts](../server/src/index.ts#L30-L36) | 见 F1；一行改动消掉唯一开放线索 |
| 2 | `habit`/`history`/`settings` 的 500 改成固定文案 | [habit.ts](../server/src/routes/habit.ts#L92)、[history.ts](../server/src/routes/history.ts#L71)、[settings.ts](../server/src/routes/settings.ts#L191) | 回传 `(error as Error).message`，Node fs 错误会带出 Vault 绝对主机路径，与 [diary.ts](../server/src/routes/diary.ts#L205-L215) 的脱敏 500 不一致 |
| 3 | `readDiary` 加 `realpath` 包含性 + `isFile`；`GET /diary/:date` 考虑不回传 `raw` | [vault.ts](../server/src/services/vault.ts#L48-L58)、[markdown.ts](../server/src/services/markdown.ts#L136-L137) | 与同文件图片读取纪律对齐；`raw` 全文回传会把任何「读到非预期文件」的缺陷放大成全文外泄 |
| 4 | 标签配置改 `tmp + rename`、坏文件隔离为 `.corrupt-<ts>`、GET 不再写盘 | [settings.ts](../server/src/routes/settings.ts#L78-L81)、[settings.ts](../server/src/routes/settings.ts#L183-L211) | 整表截断写、无备份、`JSON.parse` 无兜底：半份配置会让标签功能永久 500 |
| 5 | 构建前 `rm -rf dist`，并清理部署机的历史产物 | [deploy.sh](../server/deploy.sh#L27) | `tsc` 不清理 outDir，`server/dist/` 仍留着已下线的 `routes/backups.js`、`services/backup_*.js`、`webdav_backup.js`。当前 `dist/index.js` 不 import 它们，**无现行暴露**，但部署目录永久保存未评审的旧代码 |

### P2 · 有空再做

| # | 事项 | 位置 |
| :-- | :-- | :-- |
| 6 | 习惯时长：区分「rawLine 为空」与「rawLine 过期」，后者仿 [diary.ts](../server/src/routes/diary.ts#L922) 返回 409 | [diary.ts](../server/src/routes/diary.ts#L499-L505) |
| 7 | 两个焦虑端点统一加续行前缀/转义行首，`content` 改必填 | [diary.ts](../server/src/routes/diary.ts#L645-L647)、[diary.ts](../server/src/routes/diary.ts#L967-L998) |
| 8 | `appendToSection` 的模板示例行删除只扫到 section 结束 | [markdown.ts](../server/src/services/markdown.ts#L197-L204) |
| 9 | 月历接口：`parseInt` → 严格游标、`firstImage` 复用安全过滤、补未来日期过滤 | [history.ts](../server/src/routes/history.ts#L77-L106) |
| 10 | `stats/habit?days=all` 补 366 天上限；`catch` 区分读失败与缺档 | [habit.ts](../server/src/routes/habit.ts#L46-L87) |
| 11 | 客户端给 `MarkdownBody` 注入只允许自家 render 前缀的 `imageBuilder`，并显式禁用链接 | [generic_section_card.dart](../lib/widgets/generic_section_card.dart#L170-L174) |
| 12 | Token 校验：`trim()` 后比占位符、要求最短长度；文档写清轮换步骤（客户端目前没有改 Token 的入口，`ApiConfig.clear()` 无调用方，轮换只能清 App 数据） | [config/index.ts](../server/src/config/index.ts#L19)、[api_config.dart](../lib/services/api_config.dart#L27-L30) |
| 13 | 部署/CI：`deploy.sh` 用 `npm ci`；action 固定到 commit SHA；CORS 空白名单时只放行回环/私网 | [deploy.sh](../server/deploy.sh#L23)、[ci.yml](../.github/workflows/ci.yml#L20-L23) |
| 14 | 客户端清理 `image_picker` 的 `scaled_*` 缓存副本 | [quick_capture_screen.dart](../lib/screens/quick_capture_screen.dart#L475-L505) |

## 7. 覆盖清单

25 个覆盖单元：24 covered、1 candidate（F1）、0 blocked。最终清洁批评确认无遗漏单元。

| 子系统 | 覆盖单元（surface / boundary） | 状态 | 主评审 |
| :-- | :-- | :-- | :-- |
| repository | `.github/workflows/ci.yml#jobs`<br>`.github/workflows/ci.yml#permissions` | covered | h01-perimeter |
| flutter-client | `android/app/src/main/AndroidManifest.xml#application`<br>`android/app/src/main/AndroidManifest.xml#allowBackup` | covered | h05-client-secrets |
| flutter-client | `lib/screens/quick_capture_screen.dart#_pickPhotos`<br>`lib/services/image_compress_service.dart#compress` | covered | h09-critic-gaps |
| flutter-client | `lib/services/api_client.dart#ApiClient`<br>`lib/services/api_config.dart#ApiConfig.load` | covered | h05-client-secrets |
| flutter-client | `lib/services/markdown_parser.dart#parseDiary`<br>`lib/widgets/diary_markdown_view.dart#build` | covered | h06-client-ai |
| flutter-client | `lib/services/polisher_service.dart#PolisherService`<br>`lib/models/ai_config.dart#AIConfig.isUsable` | covered | h06-client-ai |
| flutter-client | `lib/services/reading_cache_repository.dart#ReadingCacheRepository`<br>`lib/services/reading_cache_repository.dart#_name` | covered | h05-client-secrets |
| server | `server/src/index.ts#app.listen(PORT)`<br>`server/src/middleware/auth.ts#authMiddleware` | covered | h01-perimeter |
| server | `server/src/index.ts#app.use(authMiddleware)`<br>`server/src/middleware/auth.ts#isTokenValid` | covered | h01-perimeter |
| server | `server/src/index.ts#express.json({ limit: 10mb })`<br>`server/src/index.ts#app.use(authMiddleware)` | **candidate（F1）** | h01-perimeter |
| server | `server/src/routes/diary.ts#GET /api/v1/diary/:date`<br>`server/src/services/vault.ts#readDiary` | covered | h07-readpaths |
| server | `server/src/routes/diary.ts#GET /api/v1/diary/image/:year/:imageName`<br>`server/src/services/vault.ts#resolveImagePath` | covered | h07-readpaths |
| server | `server/src/routes/diary.ts#GET /api/v1/diary/image/render/:year/:imageName`<br>`server/src/services/vault.ts#resolveImagePath` | covered | h02-files |
| server | `server/src/routes/diary.ts#POST /api/v1/diary/anxiety`<br>`server/src/routes/diary.ts#replaceAnxietySection` | covered | h09-critic-gaps |
| server | `server/src/routes/diary.ts#POST /api/v1/diary/delete-entry`<br>`server/src/routes/diary.ts#deleteUnreferencedImageFiles` | covered | h02-files |
| server | `server/src/routes/diary.ts#POST /api/v1/diary/edit-entry`<br>`server/src/routes/diary.ts#findEntryRangeInSection` | covered | h08-writepaths |
| server | `server/src/routes/diary.ts#POST /api/v1/diary/habit/duration`<br>`server/src/routes/diary.ts#findExistingLine` | covered | h03-writes |
| server | `server/src/routes/diary.ts#POST /api/v1/diary/image/upload`<br>`server/src/routes/diary.ts#isImageBuffer` | covered | h02-files |
| server | `server/src/routes/diary.ts#POST /api/v1/diary/quick-note`<br>`server/src/routes/diary.ts#commitDiary` | covered | h03-writes |
| server | `server/src/routes/habit.ts#GET /api/v1/stats/habit`<br>`server/src/routes/habit.ts#queryString` | covered | h09-critic-gaps |
| server | `server/src/routes/history.ts#GET /api/v1/history/:year/:month`<br>`server/src/services/vault.ts#listMonthDiaries` | covered | h07-readpaths |
| server | `server/src/routes/history.ts#GET /api/v1/history/gallery`<br>`server/src/services/gallery.ts#parseMonthCursor` | covered | h04-reads |
| server | `server/src/routes/settings.ts#GET /api/v1/settings/tags`<br>`server/src/routes/settings.ts#loadTagConfig` | covered | h08-writepaths |
| server | `server/src/routes/settings.ts#PUT /api/v1/settings/tags`<br>`server/src/routes/settings.ts#validateConfig` | covered | h04-reads |
| server | `server/src/services/vault-temp-cleanup.ts#cleanupDiaryTemporaryFiles`<br>`server/src/services/vault-temp-cleanup.ts#removeDuplicate` | covered | h03-writes |

### 7.1 未单独成单元但已记录

- `writeDiary` 的父目录符号链接（年份/月份目录被替换为链接）：与已否决的「预植入符号链接」同根因，不另立单元。
- `/reflection` 占位行替换分支写入时间条目不排序，可能留下乱序时间轴直到下一次 append。
- `edit-entry` 的 `replacement` 可写入 `<!-- diary-op:… -->` 与 `<!-- litchi-photo-of:… -->`，伪造幂等证明或照片关联。
- `GET /settings/tags` 的读时落盘已在 GET 单元内记录，不重复计入。
- 画廊客户端渲染已并入 `api_client` 单元的 URI 构造检查。

### 7.2 先前运行

无。`~/security-audit-skill` 在本轮之前不存在，这是首次审计。

## 8. 复现与验证说明

- 本轮校验使用技能自带的 `validate-findings.cjs` 与 `validate-coverage-ledger.cjs`，25 个覆盖单元、5 条最终记录（1 needs_validation + 4 rejected）均通过。这两份中间产物按本次请求只写在系统临时目录，未入库。
- 所有候选的复现步骤都假定存在可用的隔离环境（容器或修复后的 `sandbox-exec`），且不接触真实 Vault、真实 Token 或任一外部服务。
- 需要所有者观测的部署事实：TLS/反代拓扑、主机防火墙与网段、`server/config.json` 的 Token 强度与 `allowedOrigins`、Android 签名身份、Vault 是否被同步工具写入符号链接。

## 9. 维护说明

本文件是一次性审计快照，不随代码演进自动更新。后续审计请新增同格式的日期化文件，并在此处追加一行指向前一份，不要原地改写结论；发现修复后是否关闭，以新一次审计的结论为准。
