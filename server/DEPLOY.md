# 荔枝日记 API 服务端部署指南

## 前置要求

- Mac mini 已安装 Node.js (v20+)
- Mac mini 已安装 Tailscale 并连接
- 已确认 Obsidian Vault 的本地路径

服务端已迁入 Flutter 项目仓库的 `server/` 目录。原 Web 端可以逐步淘汰，后续 API 服务端开发以本仓库为准。

## 一键部署

```bash
# 1. Clone 项目到 Mac mini
git clone <repo-url> litchi-journal
cd litchi-journal/server

# 2. 创建本地配置并填写私有值
cp config.example.json config.json

# 3. 执行部署脚本
./deploy.sh
```

## 手动部署

```bash
cd litchi-journal/server

# 1. 安装依赖
npm install

# 2. 构建 TypeScript
npm run build

# 3. 创建日志目录
mkdir -p logs

# 4. 启动服务
npm run pm2:start

# 5. 查看状态
pm2 status
```

## 验证部署

```bash
# 测试 Health endpoint
curl http://localhost:4001/health

# 查看日志
pm2 logs diary-api
```

## 常用命令

```bash
# 查看状态
pm2 status

# 查看日志
npm run pm2:logs
pm2 logs diary-api --lines 100

# 重启服务
npm run pm2:restart

# 停止服务
npm run pm2:stop

# 删除服务
pm2 delete diary-api
```

## 开机自启

```bash
# 生成 startup 脚本
pm2 startup

# 保存当前 pm2 进程列表
pm2 save
```

执行 `pm2 startup` 后会输出一条命令，复制执行即可。

## 日志管理

日志文件位置：
- 输出日志：`logs/out.log`
- 错误日志：`logs/error.log`

日志格式：
```
2026-05-12 10:29:58 +08:00: Diary API Server running on port 4001
```

## 更新部署

```bash
# 拉取最新代码
git pull

# 重新部署
cd server
npm run build
npm run pm2:restart
```

## 监控

### pm2 监控面板

```bash
pm2 monit
```

### API 监控

```bash
# Health check
curl http://localhost:4001/health

# 日记接口测试
curl http://localhost:4001/api/v1/diary/2026-05-12 \
  -H "Authorization: Token <YOUR_PRIVATE_TOKEN>"
```

## 故障排查

### 1. 服务未启动

```bash
# 检查进程
pm2 status

# 查看错误日志
pm2 logs diary-api --err
```

### 2. 端口被占用

```bash
# 检查端口
lsof -i :4001

# 停止占用进程
pm2 stop diary-api
```

### 3. Token 无效

检查 `config.json` 中的 apiToken 配置。

## 手机端配置

Flutter 客户端远程 API 配置：

- API 地址：`http://<TAILSCALE_IP>:4001`
- Token：使用仅保存在本地 `server/config.json` 中的私有 Token

## 配置文件

复制模板后编辑本地配置。`server/config.json` 已加入 `.gitignore`，禁止提交真实值：

```bash
cp config.example.json config.json
```

`server/config.json`：
```json
{
  "vaultPath": "/path/to/your/Obsidian Vault",
  "apiToken": "<YOUR_PRIVATE_TOKEN>",
  "port": 4001
}
```

**注意**：Mac mini 的 vaultPath 可能与 MacBook 不同，需要修改。

## 图片命名前缀

`POST /api/v1/diary/image/upload` 支持可选字段 `imagePrefix`。

- 不传：继续使用 `Image-YYYYMMDD-NNN.jpg`
- 传入合法前缀：使用 `{prefix}-YYYYMMDD-NNN.jpg`
- 合法字符：英文、数字、短横线、下划线

非法前缀会返回错误，不会写入图片或 Markdown。
