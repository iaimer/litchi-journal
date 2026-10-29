# API 服务端部署

源码位于 `server/src/`，构建入口为 `dist/index.js`；PM2进程名 `diary-api`，工作目录由 `ecosystem.config.cjs` 固定为本目录。移除macOS客户端不影响在Mac mini运行Node服务。代码已合入不表示运行机器已部署。

## 配置与运行

开发和CI使用Node.js22。部署机器需要能访问Vault；若通过Tailscale连接，手机与服务端应在可互通网络中。

在本目录复制 `config.example.json` 为 `config.json`，填写实际Vault路径、私有Token、端口及可选 `allowedOrigins`。默认示例端口4001，实际以配置为准。空来源白名单保持本地调试和真机访问兼容；原生客户端不依赖浏览器CORS。配置、密钥和Vault不得提交Git或输出到聊天与日志。

```bash
npm ci
npm test
npm run build
npm run pm2:start
```

PM2需预先安装。开发调试可用 `npm run dev`；不使用PM2时可在构建后 `npm start`。

## Token 与浏览器来源

API Token 会去掉首尾空白后校验，至少32个字符，不能包含内部空白或使用示例占位符；建议使用密码管理器生成足够长的随机值。短 Token 会让新服务拒绝启动，不会自动生成或改写私有配置。

轮换前先确保已安装包含「服务器连接 → 更换 Token」入口的客户端，保留现有设置。由所有者在服务端本地备份私有配置、设置新 Token 并重启服务，然后在客户端输入新 Token，连接验证成功后才保存并立即生效。切换期间旧凭据会收到401，这是预期的短暂维护窗口；验证失败时客户端保留旧配置，可在服务端本地回滚配置恢复服务。无需清除 App 数据，也不要将 Token 粘贴到日志、命令参数或聊天中。健康检查不能代替带凭据的连接验证。

`allowedOrigins: []` 保留既有本地调试兼容；非空时按完整 Origin（协议、主机及非默认端口）精确匹配浏览器来源，不使用通配符。无 Origin 的原生请求仍须通过 Token 认证，CORS 不代替身份校验，也不限制非浏览器调用方。

## 更新

部署前按既有方式备份Vault，确认要交付的分支／提交，保留部署机器的私有配置。在确认的代码版本上执行：

```bash
cd server
npm ci
npm test
npm run build
npm run pm2:restart
```

先完成测试与构建再重启；首次部署用 `pm2:start`。用 `GET /health` 检查进程，再使用客户端完成授权连接和隔离测试数据的创建、记录、习惯、图文及失败重试验证。健康检查不证明Token或全部业务可用。

```bash
curl http://localhost:4001/health
pm2 status
npm run pm2:logs
```

手机使用可达的服务端地址和配置中的Token。连接失败先检查进程、配置端口、手机VPN／代理白名单、fake-ip DNS及浏览器同域名访问；凭据错误在本地核对，不打印真实Token。

## 部署脚本与旧备份清理

`./deploy.sh` 会执行 `npm ci`、TypeScript构建、按需全局安装PM2、删除旧 `diary-api` 进程、清理已撤回备份功能的遗留数据，再启动并保存PM2配置。它不运行测试，结束时显示的4001是固定提示，不能替代实际配置。执行前应了解这些动作，不把它当作无副作用检查。

旧备份清理脚本默认只预览，`--apply` 才删除：

```bash
./scripts/cleanup-removed-backup-data.sh
./scripts/cleanup-removed-backup-data.sh --apply
```

清理时旧服务须停止；脚本只处理 `server/data/` 中指定的备份配置／凭据／状态及 `.corrupt-*`，和系统临时目录下应用专用 `litchi-journal-backups`。符号链接或路径校验异常时拒绝执行，不扫描Vault、云盘、远端WebDAV ZIP或手机下载目录。

## 运维边界

PM2日志位于 `server/logs/out.log` 与 `error.log`；可用 `pm2 monit` 查看状态。需要开机自启时由部署者执行 `pm2 startup`，按其输出完成系统设置，再 `pm2 save`。

新日记写入支持原子替换与操作幂等，旧 `.diary-ops.json` 只读兼容；损坏且无法确认操作结果时返回冲突，不删除索引来绕过保护。原子写入不解决外部编辑器／云盘并发冲突。外部Vault备份继续独立保留，已撤回ZIP／WebDAV应用备份不恢复。
