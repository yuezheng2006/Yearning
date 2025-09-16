#!/bin/bash

# Yearning 前端构建脚本
# 使用本地 frontend/ 目录构建前端项目

set -e

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 项目信息
FRONTEND_DIR="frontend"
TARGET_DIR="src/service/dist"

echo -e "${BLUE}🎨 Yearning 前端构建脚本${NC}"
echo -e "${YELLOW}前端目录: $FRONTEND_DIR${NC}"
echo -e "${YELLOW}目标目录: $TARGET_DIR${NC}"

# 1. 检查前端源码目录
if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "\n${RED}❌ 前端目录不存在: $FRONTEND_DIR${NC}"
    echo -e "${YELLOW}请先执行以下命令克隆前端代码:${NC}"
    echo -e "git clone --depth 1 -b next https://github.com/cookieY/gemini-next.git frontend"
    exit 1
fi

# 2. 检查目标目录是否存在
if [ -d "$TARGET_DIR" ]; then
    echo -e "\n${YELLOW}🧹 清理旧的前端资源...${NC}"
    rm -rf "$TARGET_DIR"/*
fi

# 3. 进入前端目录
echo -e "\n${YELLOW}📂 进入前端目录...${NC}"
cd "$FRONTEND_DIR"

# 4. 检查是否为 Vue3 + Vite 项目
if [ -f "vite.config.ts" ]; then
    echo -e "${GREEN}✅ 检测到 Vue3 + Vite 项目${NC}"
    BUILD_TOOL="vite"
elif [ -f "vue.config.js" ]; then
    echo -e "${GREEN}✅ 检测到 Vue2 + Vue CLI 项目${NC}"
    BUILD_TOOL="vue-cli"
else
    echo -e "${RED}❌ 未检测到支持的构建工具${NC}"
    exit 1
fi

# 5. 安装依赖
echo -e "\n${YELLOW}📦 安装前端依赖...${NC}"
if command -v yarn &> /dev/null && [ -f "yarn.lock" ]; then
    echo -e "${BLUE}使用 yarn 安装依赖...${NC}"
    yarn install
else
    echo -e "${BLUE}使用 npm 安装依赖...${NC}"
    npm install --legacy-peer-deps
fi

# 6. 设置环境变量
echo -e "\n${YELLOW}⚙️ 配置构建环境...${NC}"
export VITE_APP_API_URL=""
export VUE_APP_API_URL=""

# 7. 构建前端
echo -e "\n${YELLOW}🔨 构建前端项目...${NC}"
if [ "$BUILD_TOOL" = "vite" ]; then
    if command -v yarn &> /dev/null && [ -f "yarn.lock" ]; then
        yarn build
    else
        npm run build
    fi
elif [ "$BUILD_TOOL" = "vue-cli" ]; then
    if command -v yarn &> /dev/null && [ -f "yarn.lock" ]; then
        yarn build
    else
        npm run build
    fi
fi

# 8. 复制构建产物
echo -e "\n${YELLOW}📋 复制构建产物...${NC}"
cd .. # 回到项目根目录

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 复制构建产物
if [ -d "$FRONTEND_DIR/dist" ]; then
    cp -r "$FRONTEND_DIR/dist/"* "$TARGET_DIR/"
else
    echo -e "${RED}❌ 构建产物目录不存在: $FRONTEND_DIR/dist${NC}"
    exit 1
fi

# 9. 验证构建结果
if [ -f "$TARGET_DIR/index.html" ]; then
    echo -e "\n${GREEN}🎉 前端构建成功！${NC}"
    echo -e "${GREEN}📊 构建统计:${NC}"
    FILE_COUNT=$(find "$TARGET_DIR" -type f | wc -l)
    TOTAL_SIZE=$(du -sh "$TARGET_DIR" | cut -f1)
    echo -e "  - 文件数量: $FILE_COUNT 个"
    echo -e "  - 总大小: $TOTAL_SIZE"
    echo -e "  - 目标目录: $TARGET_DIR"
    
    echo -e "\n${BLUE}📝 二次开发提示:${NC}"
    echo -e "  - 前端源码: $FRONTEND_DIR/"
    echo -e "  - 修改前端代码后，重新运行此脚本构建"
    echo -e "  - 构建完成后，运行 ./build.sh 重新编译后端"
else
    echo -e "\n${RED}❌ 前端构建失败！${NC}"
    echo -e "${RED}未找到 index.html 文件${NC}"
    exit 1
fi