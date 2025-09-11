#!/bin/bash

# Yearning 一键部署脚本

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Yearning 一键部署${NC}"

# 1. 构建
echo -e "${YELLOW}步骤1: 构建应用...${NC}"
./build.sh

# 2. 配置检查
if [ ! -f "conf.toml" ]; then
    echo -e "${YELLOW}步骤2: 创建配置文件...${NC}"
    cp conf.toml.template conf.toml
    echo -e "${YELLOW}⚠️  请编辑 conf.toml 配置MySQL连接信息${NC}"
    echo "按回车继续..."
    read
fi

# 3. 初始化数据库
echo -e "${YELLOW}步骤3: 初始化数据库...${NC}"
echo "yes" | ./Yearning install

# 4. 启动服务
echo -e "${YELLOW}步骤4: 启动服务...${NC}"
echo -e "${GREEN}✅ 部署完成！${NC}"
echo -e "${GREEN}🌐 访问地址: http://localhost:8000${NC}"
echo -e "${GREEN}👤 默认账号: admin / Yearning_admin${NC}"
echo ""
echo "启动服务..."
./Yearning run
