# 会话日志

> 每次开发会话的记录：讨论了什么、为什么这么做、改了什么、遇到了什么问题、最终结果。

---

## 2026-08-18 移除不可用的 OpenCode Go 预设

### 讨论内容

- 用户确认 OpenCode Go 无法稳定使用，要求从 AI 配置预设中移除，不再继续尝试 Pro 或其它替代模型。
- DeepSeek 官方 API 当前正常，应保持现有官方配置和 Host 专属请求修复。

### 决策 & 原因

- 删除 `aiPresets` 中的 OpenCode Go 入口及其专属预设测试，避免用户误选已知不可用服务。
- 保留通用 HTTP AI 配置、连接测试和安全错误处理，以便用户仍可手动配置其它兼容服务；不扩大本次修改范围。
- README、PLAN、CHANGELOG 同步移除当前功能承诺，版本更新为 `1.5.6+18`。

### 改动文件清单

- `pubspec.yaml`
- `lib/models/ai_config.dart`
- `test/widget_test.dart`
- `README.md`、`PLAN.md`、`CHANGELOG.md`、`SESSION_LOG.md`

### 遇到的问题

- 删除预设不等于删除底层通用兼容请求能力；OpenCode 相关服务代码和错误映射仍保留，避免影响用户手动配置的其它服务。

### 最终结果

- OpenCode Go 不再出现在 AI 配置预设列表。
- `flutter analyze` 通过，零问题。
- `flutter test` 350 项全部通过。
- Release APK 构建通过。

---

## 2026-08-18 OpenCode Go 恢复低成本 Flash 预设

### 讨论内容

- 用户明确拒绝使用 `deepseek-v4-pro`：Pro 成本更高，且实测同样不能解决 OpenCode Go 问题。
- DeepSeek 官方 API 已恢复正常，说明客户端的官方 Host 专属 non-thinking 修复有效；OpenCode Go 仍属于独立上游问题。

### 决策 & 原因

- OpenCode Go 预设恢复 `deepseek-v4-flash`，尊重用户选择的成本边界，不用更昂贵模型掩盖上游故障。
- OpenCode Go 发生 `http.ClientException` 时转换为“上游中断连接，请稍后重试”，不再建议 Pro。
- 保留只针对 `api.deepseek.com` 的 `thinking: disabled`，确保 DeepSeek 官方 API 继续正常。
- 不为当前 OpenCode Go 上游异常继续叠加未经验证的兼容参数。

### 改动文件清单

- `pubspec.yaml`
- `lib/models/ai_config.dart`
- `lib/services/polisher_service.dart`
- `test/widget_test.dart`
- `AGENTS.md`、`CHANGELOG.md`、`README.md`、`SESSION_LOG.md`

### 遇到的问题

- OpenCode Go 的连接测试与正式润色表现不一致，且不同模型均有上游故障报告；客户端无法保证其服务端可用性。

### 最终结果

- 版本更新为 `1.5.5+17`。
- OpenCode Go 恢复低成本 Flash 预设，断连提示不再引导 Pro。
- `flutter analyze` 通过，零问题。
- `flutter test` 351 项全部通过。
- Release APK 构建通过。

---

## 2026-08-18 修复 OpenCode Go Flash 服务中断与 DeepSeek 官方连接

### 讨论内容

- 用户确认 OpenCode Go 连接测试成功，但正式润色只显示“润色失败请重试”；原有 DeepSeek 官方 API 也无法通过连接测试。
- 当前错误分类排除了认证、HTTP 状态、超时和空结果，定位到未映射的网络连接中断。
- OpenCode 官方仓库已有同症状报告：Go 端点的 `deepseek-v4-flash` 会在正式响应前中断连接，而同一端点的 `deepseek-v4-pro` 可正常返回。
- DeepSeek 官方文档确认 V4 默认开启 thinking，`thinking: disabled` 是 `api.deepseek.com` 支持的官方控制参数。

### 决策 & 原因

- OpenCode Go 预设默认模型改为 `deepseek-v4-pro`，绕过当前 Flash 上游通道异常；不自动覆盖用户已保存模型，安装后需重新选择预设。
- 仅在 Host 精确匹配 `api.deepseek.com` 时发送 `thinking: disabled`，修复官方 DeepSeek 小输出连接测试，同时不再破坏 OpenCode Go 兼容接口。
- 补充 `http.ClientException` 的安全错误映射，提示 OpenCode Go 用户切换到 `deepseek-v4-pro`。
- 先让预设模型、官方 thinking 和连接中断提示测试失败，再实施修复并验证转绿。

### 改动文件清单

- `pubspec.yaml`
- `lib/models/ai_config.dart`
- `lib/services/polisher_service.dart`
- `test/widget_test.dart`
- `AGENTS.md`、`CHANGELOG.md`、`README.md`、`PLAN.md`、`SESSION_LOG.md`

### 遇到的问题

- 手机未连接 ADB，无法直接读取真机日志；通过用户提供的最终 UI 文案和 OpenCode 上游的同症状报告完成错误类别收敛。
- OpenCode Go 与 DeepSeek 官方虽然使用相同模型 ID，但支持的扩展参数不同，不能按模型名共享 thinking 配置。

### 最终结果

- 版本更新为 `1.5.4+16`。
- `flutter analyze` 通过，零问题。
- `flutter test` 351 项全部通过。
- Release APK 构建通过。

---

## 2026-08-18 修复 OpenCode Go 润色与连接测试回归

### 讨论内容

- 用户反馈 AI 配置页连接测试成功，但保存设置后正式润色仍然失败。
- 对比连接测试与正式润色请求，确认两者的提示词长度、输出预算和响应路径并不相同；问题不能只通过“保存配置”解决。
- 首版兼容修复加入 DeepSeek 原生 `thinking` 扩展后，用户反馈连接测试由成功变为失败。

### 决策 & 原因

- 正式润色默认输出预算从 2000 限制为 512，降低 OpenCode Go / DeepSeek V4 因输出预算或响应格式导致失败的概率。
- 通过新旧请求体差分与失败回归测试确认：新增的 `thinking` 是连接测试唯一新增字段；OpenCode Go 官方只声明该端点为 OpenAI-compatible，并未声明支持该扩展。
- 移除 `thinking`，连接测试与正式润色只发送标准 `model`、`messages`、`max_tokens` 字段。
- 将 HTTP 状态、超时、连接失败转换为去敏后的可操作提示；保留通用失败文案，不输出 API Key。
- 增加请求体回归测试，确保连接测试和正式润色不再携带未声明扩展，同时保留受控输出预算。

### 改动文件清单

- `pubspec.yaml`
- `lib/services/polisher_service.dart`
- `lib/screens/quick_capture_screen.dart`
- `lib/widgets/anxiety_composer.dart`
- `test/widget_test.dart`
- `AGENTS.md`、`CHANGELOG.md`、`README.md`、`PLAN.md`、`SESSION_LOG.md`

### 遇到的问题

- 统一错误文案后，原有焦虑润色测试仍断言旧文案；已保留原有通用提示并仅对可识别的 HTTP/网络错误提供更具体的安全提示。
- 首版修复把 DeepSeek 原生参数误用于 OpenCode Go 的兼容接口，造成连接测试回归；回归测试先稳定复现，再移除该字段。

### 最终结果

- 版本更新为 `1.5.3+15`。
- `flutter analyze` 通过，零问题。
- `flutter test` 349 项全部通过。
- Release APK 构建通过。

---

## 2026-08-18 AI 配置增加 OpenCode Go 与连接测试

### 讨论内容

- 用户要求在 AI 配置预设中增加 OpenCode Go，并在 AI 服务配置页提供测试连接按钮，帮助用户确认参数有效。
- 核对 OpenCode Go 官方文档，确认 OpenAI-compatible 模型使用 `https://opencode.ai/zen/go/v1/chat/completions`；API 端点表中的模型 ID 使用原始模型名。

### 决策 & 原因

- 预设填入 `https://opencode.ai/zen/go` 与 `deepseek-v4-flash`，由现有 `chatUrl` 统一补齐 `/v1/chat/completions`。
- 连接测试复用实际 AI 请求路径，发送最小请求并检查响应结构；测试使用当前输入，不自动保存配置。
- 连接测试仅返回去敏后的可操作提示，不在错误或日志中暴露 API Key。

### 改动文件清单

- `lib/models/ai_config.dart`
- `lib/services/polisher_service.dart`
- `lib/screens/ai_settings_screen.dart`
- `test/widget_test.dart`
- `AGENTS.md`、`PLAN.md`、`README.md`、`SESSION_LOG.md`

### 遇到的问题

- OpenCode 文档同时提到 OpenCode 配置文件中的 `opencode-go/<model-id>` 格式和直连 API 表中的原始模型 ID；本项目直接调用 HTTP API，因此采用后者。

### 最终结果

- 已完成 OpenCode Go 预设与 AI 配置连接测试交互，`flutter analyze` 无问题，348 项 Flutter 测试全部通过。

---

## 2026-08-18 OpenCode Go 连接测试失败修复

### 讨论内容

- 用户反馈 OpenCode Go 的地址、模型和 API Key 看起来正确，但 AI 配置页连接测试失败。
- 核对官方实时文档与模型列表，确认 `deepseek-v4-flash` 和 `/v1/chat/completions` 端点仍然有效。

### 决策 & 原因

- 将连接测试的 `max_tokens` 从 1 调整为 16，避免推理模型因输出预算过小而无法返回有效正文。
- 保留最小请求设计，同时将 401/403、404、429、5xx、超时和网络失败转换为可操作且不含 API Key 的提示。
- 用户在对话中暴露的 API Key 不写入代码、日志或测试输出，建议撤销后重新生成。

### 改动文件清单

- `lib/services/polisher_service.dart`
- `test/widget_test.dart`
- `SESSION_LOG.md`

### 遇到的问题

- 原实现将所有连接错误统一显示为同一句提示，无法区分权限、额度、路径和网络问题。

### 最终结果

- 连接测试请求预算与错误提示已修复，`flutter analyze` 无问题，348 项 Flutter 测试全部通过；Release APK 已重新构建。

---

## 2026-08-04 文档体系合并精简：6 份工作流文档

### 讨论内容

- 用户要求阅读项目全部文档（AGENTS / PRODUCT / DESIGN / CONTEXT / DEV_SUMMARY / DEV_PLAN / CHANGELOG / SESSION_LOG / README），生成 PRD 文档。
- 随后要求合并并精简文档体系，方便以后按工作流更新；并更新全局 `project-docs-workflow` skill 后再推送。

### 决策 & 原因

- 文档体系对齐 `project-docs-workflow`：收敛为 6 份 —— `AGENTS.md`（知识库）、`README.md`（简介+发布流程）、`CHANGELOG.md`（版本）、`SESSION_LOG.md`（会话）、`PLAN.md`（产品需求+路线图+进度）、`DESIGN.md`（设计语言）。
- 旧文档直接删除（git 历史可恢复），不归档，避免工作区冗余。
- PRD、PRODUCT、CONTEXT 与 DEV_SUMMARY / DEV_PLAN 精华全部并入根目录 `PLAN.md`（10 节结构，含「新需求 & 新想法」inbox）。
- Flora 品牌规范（SVG 图标基线、空状态系统、品牌源图规则）并入 `DESIGN.md`，两份 FLORA 专题稿删除。
- RELEASE_CHECKLIST 并入 `README.md`「发布检查清单」。
- AGENTS.md 新增「文档更新工作流」节，推送前按 版本号 → AGENTS → SESSION_LOG → CHANGELOG → README → PLAN 顺序更新。
- 全局 skill `project-docs-workflow` 升级 v2.0.0 → v3.0.0：文档清单改为 6 份、版本号文件兼容 `pubspec.yaml`/`package.json`、PLAN.md 模板对齐 10 节结构、里程碑更新规则明确。

### 改动文件清单

- 新建 `PLAN.md`（合并 PRD/PRODUCT/CONTEXT 与 DEV_SUMMARY/DEV_PLAN 精华，18KB）
- `AGENTS.md`（项目文档清单 6 份 + 文档更新工作流节）
- `DESIGN.md`（并入 Flora SVG 图标/空状态/品牌资源规范）
- `README.md`（关键文档清单 + 发布检查清单）
- `SESSION_LOG.md`（本次记录）
- 删除 `PRODUCT.md`、`CONTEXT.md`、`RELEASE_CHECKLIST.md`、`docs/DEV_SUMMARY.md`、`docs/DEV_PLAN.md`、`docs/PRD.md`、`docs/FLORA_BRAND_SYSTEM_v1.md`、`docs/FLORA_UI_REFACTOR_PLAN.md`
- 全局 skill：`project-docs-workflow` v2.0.0 → v3.0.0（位于 `~/.reasonix/skills/`，不在 git 仓库内）

### 遇到的问题

- `install_skill` 拒绝覆盖已存在的 skill 文件；先删除旧 skill 目录再重新安装 v3.0.0。

### 最终结果

- 文档从 12 份约 230KB 精简为 6 份约 90KB（净删约 3612 行）。
- 全库 grep 确认当前生效文档无失效引用；CHANGELOG / SESSION_LOG 中的旧文件名属历史记录，保留正确。
- 纯文档改动，未运行 `flutter analyze` / `flutter test`。

---

## 2026-08-04 H4-A 代码全面审查与服务端健壮性加固

### 讨论内容

- 对 Flutter 客户端与 `server/` 服务端做全面代码审查，质量基线：`flutter analyze` 零问题、Flutter 376 测试、服务端 32 测试全部通过。
- 审查发现服务端存在确定问题：`/anxiety/replace` 重复注册、`/tomorrow/action` 调用错误函数（整块替换而非行动建议替换）、YAML frontmatter 列表解析全部丢失、图片上传无格式校验、习惯与统计接口输入校验缺失。
- 客户端主要问题是死代码与健壮性：恒为 false 的 `_tagConfigFailed`、无引用的 QuickNoteComposer/EntryTypeSelector/PlaceholderPage、草稿写入未等待、图片名未 URL 编码。

### 决策 & 原因

- 按报告优先级修复：P1 行为错误、P2 输入校验与数据一致性、P3 死代码与健壮性清理。
- `/tomorrow/action` 客户端从未使用且死函数实现有 bug（会误删全文含 🎯 的行），按「简洁优先、不保留臆想代码」直接删除路由与函数。
- 草稿写入改为串行链（Future 链 + catchError），避免保存与清空竞争导致残留，同时不让单次失败中断后续写入。
- 服务端测试脚本限定 `vitest run src`，因为默认会重复收集 `dist/` 编译产物里的测试。
- 版本从 `1.5.0+12` 升至 `1.5.1+13`，按项目工作流更新 CHANGELOG、SESSION_LOG、README、AGENTS、DEV_PLAN、DEV_SUMMARY。

### 改动文件清单

- `server/src/routes/diary.ts`（重复路由、死路由、图片校验、习惯校验、区块补建）
- `server/src/routes/habit.ts`（days 上限）
- `server/src/services/markdown.ts`、`markdown.test.ts`（YAML 列表解析 + 测试）
- `server/src/services/template.ts`（动态年份）
- `server/src/services/vault.ts`（错误信息不含路径）
- `server/package.json`（测试限定 src）
- `lib/services/api_client.dart`（图片名 URL 编码）
- `lib/screens/home_screen.dart`、`quick_capture_screen.dart`（死代码清理、草稿串行）
- `lib/widgets/anxiety_composer.dart`（草稿串行）
- 删除 `lib/widgets/quick_note_composer.dart`、`lib/widgets/entry_type_selector.dart`、`lib/screens/placeholder_page.dart`
- `test/widget_test.dart`（同步清理 33 个死代码测试）
- `pubspec.yaml`、`AGENTS.md`、`CHANGELOG.md`、`README.md`、`SESSION_LOG.md`、`docs/DEV_PLAN.md`、`docs/DEV_SUMMARY.md`

### 遇到的问题

- Dart 3 的 switch 非空 case 隐式 break，审查时一度误判 `HabitStatus.fromHabitSection` 为 fallthrough bug，实测确认行为正确。
- vitest 默认收集 `dist/` 里编译后的测试文件，导致测试数量失真（32 → 36），通过限定 `src` 解决。
- 服务端 `parseYaml` 对缩进列表项（无冒号行）整行跳过，frontmatter 数组全丢；改为带当前列表键的状态机解析。

### 最终结果

- `flutter analyze` 通过，零问题。
- `flutter test` 343 项全部通过（移除 33 个死代码组件测试）。
- `server npm run build` 通过。
- `server npm test` 18 项全部通过。
- 推送后即可更新远程服务端（`server/` 编译产物部署）。

---

## 2026-07-23 H3-B 今日日记条目时间编辑与 Markdown 排序

### 讨论内容

- 已有条目编辑需要支持修正发生时间，不应要求用户删除后重新记录。
- 用户明确要求时间排序写入 Markdown 数据层，而不是仅在 Flutter 时间轴 UI 排序。
- 真机回归发现编辑后可排序，但新增记录仍为尾部追加；因此将新增写入也纳入同一排序规则。

### 决策 & 原因

- `EntryEditSheet` 使用系统时间选择器，保存值统一为 `HH:mm`。
- Flutter 保持 `rawLine` 定位原则，仅在 replacement 中替换时间 token，继续保留 `-` 或 `>` 的原始格式。
- 服务端在 `edit-entry` 替换后排序，并让 `appendToSection()` 在新增后调用同一 section 局部排序函数，确保 Obsidian 与 App 顺序一致。
- 排序仅识别当前 section 的时间行，完整移动原始行，避免影响 callout、普通文本、图片和其它模块。
- 版本从 `1.4.5+10` 升至 `1.4.6+11`。

### 改动文件清单

- `pubspec.yaml`
- `lib/screens/home_screen.dart`
- `lib/services/entry_line_builder.dart`
- `lib/widgets/diary_markdown_view.dart`
- `lib/widgets/entry_edit_sheet.dart`
- `lib/widgets/generic_section_card.dart`
- `lib/widgets/quick_note_timeline.dart`
- `lib/widgets/review_card.dart`
- `server/src/routes/diary.ts`
- `server/src/services/markdown.ts`
- `server/src/services/markdown.test.ts`
- `test/widget_test.dart`
- `AGENTS.md`
- `CHANGELOG.md`
- `README.md`
- `docs/DEV_PLAN.md`
- `docs/DEV_SUMMARY.md`
- `SESSION_LOG.md`

### 遇到的问题

- 首版仅在编辑接口后排序，新增记录仍按追加顺序写入；通过服务端回归测试复现“18:00 后新增 10:00”的 Markdown 倒序问题。
- 远端 PM2 运行 `dist/index.js`，部署时必须执行 `npm run build` 后再重启，单纯拉取 `src/` 不会更新运行代码。

### 最终结果

- 新增和编辑时间条目都会在当前 section 内按时间升序写入 Markdown。
- `flutter analyze` 通过，`flutter test` 370 项通过。
- `server npm run build` 通过，`server npm test` 32 项通过。
- Android Debug APK 已覆盖安装；远端服务更新后用户确认测试成功。

---

## 2026-07-13 P1/P2 上线前稳定性修复与 1.4.5 Release

### 讨论内容

- 用户要求根据上线前 code review 的 P1/P2 建议依次修复，并在修复后完成验证。
- P1 重点是网络请求超时、图片上传失败提示、远程 API 地址保存后即时生效。
- P2 重点是服务端认证格式收紧和 CORS 白名单能力。
- 初次提交和真机安装后发现漏更新版本号和发布文档，需要补做 release 文档流程。

### 决策 & 原因

- `ApiClient` 统一封装 GET/POST 请求入口，普通请求 12 秒超时，图片上传 30 秒超时，错误文案保持可读且不泄露 Token。
- `PolisherService` 增加 AI 请求 30 秒超时，避免润色请求长时间悬挂。
- App 入口持有并释放当前 `ApiClient`，远程 API 地址保存成功后立即切换客户端连接，不再要求重启。
- 图片上传在压缩后仍过大时提前提示；服务端返回 401/403/413/5xx 时给出更明确原因。
- 服务端认证严格要求 `Token <value>`，并使用恒定时间比较；CORS 增加可选 `allowedOrigins` 白名单。
- 版本号从 `1.4.4+9` 升至 `1.4.5+10`，CHANGELOG/README/AGENTS/SESSION_LOG/DEV 文档同步更新。

### 改动文件清单

- `pubspec.yaml`
- `lib/main.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/remote_api_page.dart`
- `lib/screens/settings_page.dart`
- `lib/services/api_client.dart`
- `lib/services/polisher_service.dart`
- `server/config.example.json`
- `server/src/config/index.ts`
- `server/src/index.ts`
- `server/src/middleware/auth.ts`
- `server/src/middleware/auth.test.ts`
- `test/widget_test.dart`
- `AGENTS.md`
- `CHANGELOG.md`
- `README.md`
- `SESSION_LOG.md`
- `docs/DEV_SUMMARY.md`
- `docs/DEV_PLAN.md`

### 遇到的问题

- 服务端 `node_modules` 目录存在但 `.bin` 和部分包内容残缺，`tsc` / `vitest` 无法执行；通过 `npm install` 恢复本地依赖后完成验证，未执行 `npm audit fix`。
- 远程 API 设置页新增测试复现了保存后立即 dispose `TextEditingController` 的真实生命周期问题，已改为由页面状态持有并在页面销毁或下次编辑前释放。
- 首次发布提交漏更新文档和版本号，导致真机 Release 仍为 `1.4.4+9`；本次补发 `1.4.5+10`。

### 最终结果

- `flutter analyze --no-pub` 通过，零问题。
- `flutter test --no-pub` 369 项全部通过。
- `server npm run build` 通过。
- `server npm test` 4 个测试文件、26 项测试全部通过。
- `flutter build apk --release --no-pub` 通过。
- Release APK 使用 `adb install -r` 覆盖安装到 PLG110，保留本地服务器地址和 Token。

## 2026-06-23 Today Rainbow 视觉校准与标签色规则稳定

### 讨论内容

- 用户真机验收发现 Today Rainbow 中标签 chip、人生教练色、焦虑回答背景和焦虑/觉察模块色存在不一致。
- 快速记录页 TagPicker 在接入标签色 helper 后过于花，方法标签出现不同颜色，需要稳定为统一方法色。
- 最终模块顺序确认：随手记红、小确幸橙、焦虑黄、觉察绿、人生教练青、明日寄语蓝、影像记录紫。

### 决策 & 原因

- 日记正文标签 chip 支持 `moduleAccentColor`，在今日页和过往详情页跟随所在模块色；没有模块上下文时继续使用标签类型色。
- TagPicker 保持独立颜色模式：领域按固定色板区分，主题统一 `#F2C94C`，方法统一 `#9775FA`，避免快速记录页视觉过乱。
- 人生教练色改为 `#12B5CB`，与觉察绿色形成清晰区分。
- 焦虑模块最终为 `#FFD43B`，觉察与迭代最终为 `#51CF66`。
- 焦虑回答 blockquote 不再使用浅蓝底，改为当前模块色低透明度 tint 和同色系可读文字。

### 改动文件清单

- `lib/widgets/tag_color_helper.dart`
- `lib/widgets/tag_picker.dart`
- `lib/widgets/generic_section_card.dart`
- `lib/widgets/diary_markdown_view.dart`
- `lib/widgets/anxiety_card.dart`
- `lib/widgets/quick_note_timeline.dart`
- `test/widget_test.dart`
- `pubspec.yaml`
- `AGENTS.md`
- `CHANGELOG.md`
- `README.md`
- `SESSION_LOG.md`
- `docs/DEV_SUMMARY.md`

### 遇到的问题

- `flutter install --use-application-binary` 未能识别无线 ADB 的 mDNS 设备名，改用 `adb install -r` 安装成功。
- 后续 ADB 启动截图验收需要非沙箱权限，用户选择亲自真机验收。

### 最终结果

- `flutter analyze --no-pub` 通过，零问题。
- `flutter test --no-pub` 通过，363 项全部通过。
- `flutter build apk --debug --no-pub` 通过。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk` 成功。
- 用户确认修改符合要求。

## 2026-06-20 品牌视觉源图落地与真机确认

### 讨论内容

- 启动页、桌面 App 图标和关于页品牌图必须严格使用参考设计图，不应重新生成近似图。
- 用户指定 `docs/design-reference/` 中的原始图作为资源来源。
- 桌面 App 图标首次更新后主体比例通过，但关于页品牌图先后出现过太小、太大的问题，需要真机微调。

### 决策 & 原因

- `docs/design-reference/splash.png` 作为启动页源图，派生到 `assets/icon/brand-splash-reference.png`。
- `docs/design-reference/icon.png` 作为 App 图标和关于页品牌图源图，派生到 `assets/icon/app-icon.png`、`assets/icon/app-launcher.png` 和 Android mipmap launcher 资源。
- `docs/design-reference/reference.png` 只作为整体视觉参考，不再用作直接裁切资源。
- 启动页直接展示完整 splash 原图，不再由 Flutter 重新排版标题和副标题。
- 关于页品牌图最终调整为 168dp，用户真机确认尺寸合适。

### 改动文件清单

- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground_bitmap.png`
- `assets/icon/app-icon.png`
- `assets/icon/app-launcher.png`
- `assets/icon/brand-splash-reference.png`
- `docs/design-reference/icon.png`
- `docs/design-reference/splash.png`
- `docs/design-reference/reference.png`
- `lib/screens/about_page.dart`
- `lib/widgets/flora_splash.dart`
- `test/widget_test.dart`

### 验证结果

- `flutter analyze --no-pub` 通过。
- `flutter test --no-pub` 364 项全部通过。
- `flutter build apk --release --no-pub` 通过。
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` 成功。
- 真机验证：App 图标通过，关于页品牌图尺寸通过。

## 2026-06-19 启动兜底、标签兜底与习惯图标替换

### 讨论内容

- 真机替换 SVG 图标后，App 启动出现长时间转圈。
- 有日志文件但没有正文记录时，今天页无法显示习惯入口。
- 习惯设置里的默认图标和候选图标仍有 emoji 残留。
- 标签设置入口点不开，快速记录页显示「标签暂不可用」。

### 决策 & 原因

- 启动配置读取和今日日记加载都增加超时/兜底，避免异步请求挂住导致无限 loading。
- 空日记或缺少习惯 section 时，今天页使用 `HabitSection.empty()` 显示可操作的 `HabitCard`。
- 习惯默认图标与候选图标统一切到 Flora SVG 图标；新增 `HabitIcon` 兼容旧用户配置中保存过的 emoji。
- Flutter 端内置默认标签配置；远程标签接口或本地缓存不可用时，记录页和标签设置页仍可使用默认标签。

### 改动文件清单

- `lib/main.dart`
- `lib/models/default_tag_config.dart`
- `lib/models/diary_document.dart`
- `lib/models/habit_settings.dart`
- `lib/models/habit_visual_config.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/settings_page.dart`
- `lib/screens/habit_edit_screen.dart`
- `lib/screens/habit_settings_screen.dart`
- `lib/services/tag_repository.dart`
- `lib/widgets/flora_icon.dart`
- `lib/widgets/habit_icon.dart`
- `lib/widgets/habit_card.dart`
- `lib/widgets/habit_heatmap_tabs.dart`
- `lib/widgets/habit_rhythm_grid.dart`
- `test/widget_test.dart`
- `AGENTS.md`
- `CHANGELOG.md`
- `README.md`
- `SESSION_LOG.md`

### 遇到的问题

- `SettingsPage._openTagSettings()` 原先在标签配置加载失败时静默吞掉异常，导致用户感觉入口点不开。
- `HomeScreen` 在标签配置异步加载完成前打开快速记录页时，可能传入空 `tagConfig`。
- `TagRepository` 读取/写入安全存储缓存没有兜底，安全存储异常会让标签配置整体不可用。

### 最终结果

- `dart analyze lib test` 通过。
- `flutter analyze --no-pub` 通过。
- `flutter test --no-pub` 359 项全部通过。
- `flutter build apk --release` 通过，APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 2026-06-18 快速记录入口 V2/V3

### 讨论内容

- 今天页不再保留内联快速记录区域。
- 右下角 FAB 作为 Flora 唯一快速记录入口。
- 扇形菜单继续保留，但优化为圆形 icon-only 子按钮。
- 随手记、觉察、小确幸进入统一记录页；焦虑四问进入独立问答页；图片直接复用现有上传流程。

### 决策 & 原因

- 首页只保留内容展示和 FAB，避免输入区挤压阅读体验。
- FAB 子按钮使用极坐标布局，避免手写坐标导致真机重叠。
- 子按钮视觉尺寸为 42dp，点击热区为 48dp，兼顾清晰和可点性。
- 焦虑四问作为独立页面后放大输入区，但不改变逐问润色和保存逻辑。

### 改动文件清单

- `lib/screens/home_screen.dart`
- `lib/screens/quick_capture_screen.dart`
- `lib/screens/anxiety_screen.dart`
- `lib/widgets/anxiety_composer.dart`
- `test/widget_test.dart`
- `AGENTS.md`
- `CHANGELOG.md`
- `README.md`
- `docs/DEV_SUMMARY.md`

### 遇到的问题

- 当前执行环境运行 `flutter test` 时，Flutter tester 无法创建本地临时 socket，报 `Operation not permitted`。该问题属于沙箱限制。

### 最终结果

- `dart analyze lib test` 通过。
- Flutter 级 `analyze --no-pub` 通过。
- `flutter build apk --release` 通过。
- 真机验证快速记录入口功能正常。

---

## 2026-06-20 自定义普通打卡习惯 H1 完整闭环

### 讨论内容

- 用户希望支持新增自定义普通打卡习惯（checkbox 类型），不支持计数/饮水/步数类。
- 系统边界：App 决定习惯定义（名称、图标、颜色、启用/归档），服务端只负责打卡写入，Markdown 只保存完成状态。
- Markdown 必须干净可读，不写 custom key，不写 HTML 注释。

### 决策 & 原因

- key 格式 `custom_<10位时间戳>`，只作为内部 ID，不暴露给用户，不写入 Markdown。
- `HabitSettings.extraHabits` 存储自定义习惯的 key→初始显示名映射，schemaVersion → 3。
- 设置页通过 `manageableKeys`（内置+自定义并集）统一渲染，归档习惯不丢失。
- `activeKeys` 过滤 orphan custom_xxx（不在 extraHabits 中但残留于 statusMap 的旧数据）。
- 今日页用 `_CustomCheckboxRow` 渲染自定义习惯，Markdown 解析结果只用于补 checked 状态，不重复渲染。
- 点击自定义习惯时，必须同步传完整内置 HabitStatus（避免清空其它习惯）。
- extraCheckboxes 每次传所有启用自定义习惯的状态。
- 服务端 `POST /habit` 解析 extraCheckboxes，追加 `- [x] 📝 冥想` 格式的自定义行。

### 遇到的问题

- 新建后显示名出现 custom_xxx：`displayNameFor` 缺少 extraHabits 层 fallback。
- 归档后自定义习惯消失：`updateHabit` 和 `resetHabit` 遗漏 extraHabits 参数。
- 已启用数量与实际列表不一致：`activeKeys` 统计了不在 extraHabits 中的 orphan key。
- 今日页出现两个同名习惯：Markdown 解析的未知 key 行被重复渲染。
- 点击自定义习惯清空内置习惯：传了零值的 HabitStatus。

### 最终结果

- flutter analyze --no-pub：零问题
- flutter test --no-pub：362 通过
- flutter build apk --release：通过
- 真机验证：新增、编辑、归档、找回、今日页显示、打卡、取消打卡、刷新保持、Markdown 干净可读

---

## 2026-06-21 修复今日页与只读日记详情页下拉 head 变深

### 讨论内容

- 用户真机验证发现今日页和只读日记详情页下拉时，状态栏下方和日期标题所在 head 区域会变深。
- PastScreen 和 HabitStatsScreen 是正确参考：下拉时顶部区域保持页面底色统一。
- 上一轮 `canvasColor` 兜底没有解决 head 变深，说明问题更可能来自 Material 3 AppBar 的 scrolled-under / surfaceTint / elevation overlay。

### 决策 & 原因

- HomeScreen 和 ReadOnlyDiaryScreen 都使用 `Scaffold.appBar` 渲染顶部标题区域，会在滚动/下拉时触发 Material 3 AppBar 的 scrolled-under 状态。
- PastScreen 和 HabitStatsScreen 的 header 位于 body/SafeArea 内，不使用 AppBar，因此不会产生 AppBar tint/elevation 叠色。
- 本轮采用最小修复：在两个 AppBar 上显式使用 `theme.scaffoldBackgroundColor`，并关闭 `surfaceTintColor`、`shadowColor`、`elevation`、`scrolledUnderElevation`。
- 保留上一轮 `canvasColor` 兜底，用于 overscroll 露底颜色，不影响本轮 AppBar 修复。

### 改动文件清单

- `lib/screens/home_screen.dart`
- `lib/screens/read_only_diary_screen.dart`

### 遇到的问题

- `flutter install` 在设备侧替换 release 包时长时间无输出，改为构建 debug APK 后使用 adb 安装。
- 后续真机页面操作由用户完成，用户确认两个页面都已修复成功。

### 最终结果

- `flutter analyze --no-pub` 通过，零问题。
- `flutter test --no-pub` 通过，362 项全部通过。
- `flutter build apk --debug --no-pub` 通过。
- 真机验证：今日页和只读日记详情页下拉时 head 区域不再变深。

---

## 2026-07-03 习惯热力图 Tab 与远程 API 配置编辑

### 讨论内容

- 用户希望把习惯统计热力图上方的标签从菜单式切换改为类似 Chrome 的 Tab 页切换，只显示图标，不显示文字。
- Tab 样式参考 Uiverse 滑块式 segmented tab，保留图标显示效果，并保证触摸面积不要太小。
- 真机出现 App 不能连接服务器，服务端健康检查正常。

### 决策 & 原因

- 习惯热力图标签改为横向 icon-only Tab，所有图标一次性展示；文字只保留在 tooltip/语义信息中，不占用界面空间。
- Tab 使用灰色圆角轨道、白色/同主题 surface 滑块、轻微阴影和 200ms 切换动效，保持原生 Flutter 实现，不引入依赖。
- 远程 API 页面增加服务器地址编辑入口，复用当前 Token 测试新地址；连接成功后才保存，避免写入不可用地址。
- 真机连接失败最终确认为手机端 VPN 白名单/代理路径问题；App 权限、配置和服务端健康状态正常。

### 改动文件清单

- `lib/widgets/habit_heatmap_tabs.dart`
- `lib/services/api_client.dart`
- `lib/screens/remote_api_page.dart`
- `lib/screens/settings_page.dart`
- `lib/screens/home_screen.dart`
- `pubspec.yaml`
- `AGENTS.md`
- `CHANGELOG.md`
- `README.md`
- `SESSION_LOG.md`

### 遇到的问题

- 真机访问 `obsidian.femkits.org` 时浏览器也出现 `ERR_CONNECTION_CLOSED`，说明不是 Flutter App 单独异常。
- App 进程日志显示域名解析/连接层失败；服务端直连健康检查正常。
- 修复方式是在手机端将 App 加入 VPN 白名单，恢复 App 的正确代理路径。

### 最终结果

- 版本更新为 `1.4.4+9`。
- 习惯热力图 Tab 样式完成。
- 远程 API 地址编辑与连接测试完成。
- 真机连接问题定位为 VPN 白名单配置问题，非 App 代码或服务端运行问题。
- `flutter analyze --no-pub` 通过，零问题。
- `flutter test --no-pub` 通过，363 项全部通过。

---

## 2026-07-31 历史月历与历史日记补录

### 讨论内容

- 用户需要为指定过去日期补录相片、随手记、觉察和小确幸，同时保持已有历史内容只读。
- 过往页头部需要内联月历，有真实记录的日期显示圆点，并避免浏览空日期时创建空日记。
- 相片补录需要一次选择多张，而不是默认单张。

### 决策 & 原因

- 历史补录 FAB 只出现在历史详情页，不出现在过往首页。
- 月历仅允许选择过去日期；圆点依据 `hasContent || hasImages`，空白模板不标记。
- 文字补录复用 `QuickCaptureScreen` 和现有 append API，草稿按目标日期与条目类型隔离。
- 无日记日期在首次保存失败后才调用 `ensureDiary(date)` 并重试，浏览和打开记录页不会创建文件。
- 相片一次最多选择 9 张，按顺序逐张压缩上传；遇到失败停止后续上传，保留已成功结果。
- 版本从 `1.4.6+11` 升至 `1.5.0+12`。

### 改动文件清单

- `pubspec.yaml`
- `lib/screens/past_screen.dart`
- `lib/screens/read_only_diary_screen.dart`
- `lib/screens/quick_capture_screen.dart`
- `lib/widgets/history_calendar.dart`
- `lib/widgets/historical_quick_record_fab.dart`
- `test/widget_test.dart`
- `PRODUCT.md`
- `DESIGN.md`
- `CONTEXT.md`
- `.impeccable/design.json`
- `AGENTS.md`
- `CHANGELOG.md`
- `README.md`
- `docs/DEV_SUMMARY.md`
- `docs/DEV_PLAN.md`
- `SESSION_LOG.md`

### 遇到的问题

- 真机 ADB 曾短暂断开，重新连接后使用 `adb install -r` 完成覆盖安装。
- 真机自动操作耗时较长，后续由用户负责人工功能验收，开发侧保留自动测试与构建验证。

### 最终结果

- 历史月历、日期圆点、历史详情专属补录入口、历史文字补录和多相片补录已实现。
- `flutter analyze --no-pub` 通过，零问题。
- `flutter test --no-pub` 376 项全部通过。
- `server npm run build` 通过。
- `server npm test` 32 项全部通过。
- Debug APK 已覆盖安装到 PLG110，原有配置保留。
