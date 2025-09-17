#!/bin/bash

# Yearning macOS 快速测试部署脚本
# 适用于Apple Silicon Mac (ARM64)

set -e

# 颜色配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/mac-test-deployment"

log_info "🚀 开始Yearning macOS快速测试部署"

# 1. 检查系统环境
log_info "检查系统环境..."
if [[ "$(uname -m)" != "arm64" ]]; then
    log_warning "检测到非ARM64架构，如果是Intel Mac请使用对应的包"
fi

# 2. 创建工作目录
log_info "创建测试工作目录..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 3. 解压Apple Silicon版本的包
log_info "解压二进制包..."
tar -xzf "$SCRIPT_DIR/yearning-v20250917-72d84e6-darwin-arm64.tar.gz"
cd yearning-v20250917-72d84e6-darwin-arm64

# 4. 设置权限
chmod +x yearning
if [ -d scripts ]; then
    chmod +x scripts/*.sh
fi

# 5. 创建简化配置
log_info "创建测试配置..."
mkdir -p conf
cat > conf/yearning.conf << 'EOF'
[Mysql]
Db = "yearning"
Host = "127.0.0.1"
Port = "3306"
Password = "test123"
User = "yearning"

[General]
SecretKey = "testkey123456789"
RpcAddr = "127.0.0.1:50001"
LogLevel = "debug"
Lang = "zh_CN"

[Oidc]
Enable = false
EOF

# 6. 创建日志目录
mkdir -p logs

# 7. 检查端口可用性
log_info "检查可用端口..."
for port in 8080 8081 8082 8083 8084 8085; do
    if ! lsof -i:$port > /dev/null 2>&1; then
        AVAILABLE_PORT=$port
        log_info "找到可用端口: $port"
        break
    fi
done

if [ -z "$AVAILABLE_PORT" ]; then
    AVAILABLE_PORT=8090
    log_warning "使用默认备用端口: $AVAILABLE_PORT"
fi

# 8. 显示程序信息
log_info "测试程序版本..."
./yearning --version

log_success "✅ Yearning macOS测试环境准备完成！"

echo ""
echo "========================================"
echo "         测试环境信息"
echo "========================================"
echo "工作目录: $PWD"
echo "程序版本: $(./yearning --version 2>/dev/null || echo 'v20250917-72d84e6')"
echo "系统架构: $(uname -m)"
echo "配置文件: conf/yearning.conf"
echo ""
echo "下一步操作："
echo "1. 启动MySQL服务（如果还没有）"
echo "2. 启动Docker和Juno服务（如果需要SQL检测）"
echo "3. 运行程序: ./yearning run --config conf/yearning.conf"
echo ""
echo "快速启动命令："
echo "cd $PWD"
echo "./yearning run --port $AVAILABLE_PORT --config conf/yearning.conf"
echo ""
echo "Web访问地址："
echo "http://localhost:$AVAILABLE_PORT"
echo ""
echo "登录信息："
echo "用户名: admin"
echo "密码: Yearning_admin"
echo ""
echo "========================================"

log_success "🎉 测试环境已就绪，您可以开始测试了！"