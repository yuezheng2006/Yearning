#!/bin/bash

# Yearning 完整构建脚本
# 包含前端构建 + 后端编译

set -e

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 项目信息
APP_NAME="Yearning"
VERSION=$(git describe --tags --always 2>/dev/null || echo "v1.0.0")

# 检测当前系统
CURRENT_OS=$(go env GOOS)
CURRENT_ARCH=$(go env GOARCH)

echo -e "${BLUE}🔨 构建 $APP_NAME $VERSION (前后端一体化)${NC}"
echo -e "${YELLOW}当前系统: $CURRENT_OS/$CURRENT_ARCH${NC}"

# 0. 检查前端是否需要构建
FRONTEND_DIST="src/service/dist"
if [ ! -f "$FRONTEND_DIST/index.html" ]; then
    echo -e "\n${YELLOW}🎨 前端未构建，开始构建前端...${NC}"
    if [ -f "build-frontend.sh" ]; then
        ./build-frontend.sh
    else
        echo -e "${RED}❌ 未找到 build-frontend.sh，请先构建前端${NC}"
        echo -e "运行: ./build-frontend.sh"
        exit 1
    fi
else
    echo -e "\n${GREEN}✅ 前端已构建${NC}"
fi

# 1. 清理
echo -e "\n${YELLOW}🧹 清理旧文件...${NC}"
rm -f $APP_NAME

# 2. 下载依赖
echo -e "${YELLOW}📦 下载Go依赖...${NC}"
go mod tidy

# 3. 构建后端
if [ "$CURRENT_OS" = "linux" ]; then
    echo -e "${YELLOW}🔨 构建本地Linux版本...${NC}"
    CGO_ENABLED=0 go build -ldflags="-s -w" -o $APP_NAME .
    echo -e "${GREEN}✅ 本地Linux版本构建完成${NC}"
else
    echo -e "${YELLOW}🔨 交叉编译Linux版本...${NC}"
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o $APP_NAME .
    echo -e "${GREEN}✅ Linux版本交叉编译完成${NC}"
fi

# 4. 显示构建结果
echo -e "\n${BLUE}📊 构建完成！${NC}"
ls -lh $APP_NAME

# 5. 显示嵌入文件统计
FRONTEND_FILES=$(find "$FRONTEND_DIST" -type f | wc -l)
FRONTEND_SIZE=$(du -sh "$FRONTEND_DIST" | cut -f1)
echo -e "\n${GREEN}📈 构建统计:${NC}"
echo -e "  - 二进制文件: $(ls -lh $APP_NAME | awk '{print $5}')"
echo -e "  - 嵌入前端文件: $FRONTEND_FILES 个"
echo -e "  - 前端资源大小: $FRONTEND_SIZE"

echo -e "\n${GREEN}🎉 一体化应用构建完成！可以部署到服务器了！${NC}"
echo -e "${YELLOW}部署命令:${NC}"
echo -e "  1. 复制文件: scp $APP_NAME conf.toml user@server:/opt/yearning/"
echo -e "  2. 初始化: ./$APP_NAME install"
echo -e "  3. 启动: ./$APP_NAME run"
