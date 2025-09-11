#!/bin/bash

# Yearning Linux构建脚本

set -e

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目信息
APP_NAME="Yearning"
VERSION=$(git describe --tags --always 2>/dev/null || echo "v1.0.0")

echo -e "${BLUE}🔨 构建 $APP_NAME $VERSION (Linux)${NC}"

# 1. 清理
echo "清理旧文件..."
rm -f $APP_NAME

# 2. 下载依赖
echo "下载依赖..."
go mod tidy

# 3. 构建Linux版本
echo "构建Linux版本..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o $APP_NAME .

echo -e "${GREEN}✅ Linux版本构建完成${NC}"
ls -lh $APP_NAME

echo -e "${GREEN}🎉 可以部署到Linux服务器了！${NC}"
