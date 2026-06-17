#!/bin/bash

# Diary API Server 部署脚本
# 用于 Mac mini 一键部署

set -e

echo "=== Diary API Server 部署 ==="

# 1. 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "错误：未安装 Node.js"
    exit 1
fi

echo "Node 版本: $(node --version)"

# 2. 安装依赖
echo "安装依赖..."
npm install

# 3. 构建 TypeScript
echo "构建 TypeScript..."
npm run build

# 4. 创建日志目录
mkdir -p logs

# 5. 检查 pm2
if ! command -v pm2 &> /dev/null; then
    echo "安装 pm2..."
    npm install -g pm2
fi

# 6. 停止旧进程（如果存在）
pm2 delete diary-api 2>/dev/null || true

# 7. 启动服务
echo "启动 API Server..."
pm2 start ecosystem.config.cjs

# 8. 显示状态
pm2 status

# 9. 保存 pm2 配置（用于开机自启）
pm2 save

echo ""
echo "=== 部署完成 ==="
echo "API 地址: http://localhost:4001"
echo "查看日志: pm2 logs diary-api"
echo "停止服务: pm2 stop diary-api"
echo ""
echo "如需开机自启，执行: pm2 startup"