# 2026-10-12 分支整合记录

用户授权合并所有分支并提交。检查范围为同步 `origin` 后的全部本地分支和远端跟踪分支，主线基线为 `287e327`；本轮没有推送、删除分支、发布新版本或远程部署。

## 实际未交付内容

`codex/habit-header-seam-20261008` 有 8 个未提交文件，全部属于习惯趋势页接缝修复及其测试、文档。先在原功能分支提交，再 squash 合并至本地 `main`，保留版本 `1.9.0+39`。没有发现其他未跟踪或未提交内容。

合并前完整回归暴露 4 项既有布局测试失败：画布缩到 320dp 后，测试仍传入 800dp 的 `MediaQuery.size`，在双位月日及 1.3 倍字体下误判日期可以同行。修正三个测试文件的屏幕元信息，并让 Banner 断言允许长日期自然换行；原有固定长短日期测试继续覆盖换行行为。未修改日期控件或产品布局，定向 78 项测试通过。

## 历史分支核对

以下分支之前已经 squash 交付。对每组执行 `git diff --name-only <分支> <主线对应提交>`；标记「文件树相同」的结果为空，包含代码、测试、资源和文档，而非仅比较提交标题。

| 功能分支（同名远端跟踪分支一并覆盖） | 主线对应提交 | 核对结果 |
| --- | --- | --- |
| `codex/today-diary-read-fix-20261008` | `287e327` | 文件树相同 |
| `codex/image-disk-cache-20261007` | `2ed1690` | 文件树相同 |
| `codex/compact-primary-banners-20261005` | `1cf41d2` | 文件树相同 |
| `codex/fan-backdrop-gallery-header-20261004` | `be4881f` | 文件树相同 |
| `codex/glass-origin-motion-20261004` | `2abfe9d` | 文件树相同 |
| `codex/fan-menu-motion-20261004` | `e257c89` | 文件树相同 |
| `codex/capture-content-flow-20261004` | `9a40a8d` | 文件树相同 |
| `feat/record-time-wheel-20260926` | `00b43f4` | 文件树相同 |
| `codex/entry-media-spacing-timeline-20260925` | `ae61192` | 文件树相同 |
| `codex/release-1.8.0-20260925` | `ec868bd` | 文件树相同 |
| `feat/entry-photo-attachments-20260924` | `6b9f77c` | 文件树相同 |
| `codex/fix-multiline-entry-20260923` | `34d1d72` | 文件树相同 |
| `feat/icons-lucide-lordicon-20260919` | `3096227` | 文件树相同 |
| `codex/ui-finish-release-20260919` | `c307352` | 仅 HANDOFF 的历史验收说明一行不同；主线说明更完整 |
| `origin/codex/remove-backup-20260917` | `b0bfed2` | 文件树相同 |
| `origin/codex/backup-credential-cleanup-20260917` | `63fff12` | 文件树相同 |
| `origin/codex/backup-credential-cleanup-report-20260917` | `be0794c` | 文件树相同 |

`codex/backup-webdav-20260916` 另行核对：本地包含远端分支的全部提交，以及阶段 6–7 的三个后续提交。其非备份 UI 实现与 `codex/ui-finish-release-20260919` 完全一致；两者的实现差异均为备份撤回、白名单清理脚本及对应回归，文档和版本差异符合后续发布。主线已通过 `030da1e` 接收备份及阶段 4–5 改造，再通过 `b0bfed2` 撤回备份，通过 `c307352` 接收阶段 6–7。继续保留撤回结果，不恢复备份页面、接口、依赖或下载通道。

## 合并方式与验证

实际接缝修复采用 squash 合并。随后对已核实交付或已被后续撤回取代的旧分支，以及刚交付的接缝功能分支，使用 `ours` 策略记录合并祖先；该步骤不修改文件树。它解决历史 squash 后 `git branch --no-merged` 仍列出旧分支的问题，不替代实现内容的核对与交付。

本轮 Flutter 静态检查零问题、完整 787 项 Flutter 测试、服务端 70 项测试、TypeScript 构建和差异检查均通过。合并完成后核验全部本地和远端跟踪分支均为 `main` 的祖先、历史归并提交的文件树不变、工作树干净。本轮不读取或修改真实 Vault，不安装 APK；真机验收和今天页修复的服务端部署仍按 HANDOFF 单独跟进。
