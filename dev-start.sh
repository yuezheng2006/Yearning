#!/bin/bash

# Yearning 开发环境启动脚本
# 使用方法: ./dev-start.sh [命令]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

# 检查Docker是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行，请先启动 Docker"
        exit 1
    fi
}

# 检查端口是否被占用
check_ports() {
    local ports=("80" "3000" "8000" "3306" "2345")
    for port in "${ports[@]}"; do
        if lsof -ti:$port > /dev/null 2>&1; then
            log_warn "端口 $port 已被占用"
            read -p "是否继续？(y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    done
}

# 创建前端开发目录
setup_frontend() {
    if [ ! -d "frontend-dev" ]; then
        log_info "创建前端开发目录..."
        mkdir -p frontend-dev
        # 这里可以从 Yearning-gemini 仓库克隆或复制前端代码
        log_info "前端开发目录已创建: ./frontend-dev"
        log_warn "请将前端源码放置在 ./frontend-dev 目录中"
    fi
}

# 启动完整开发环境
start_dev() {
    log_header "启动 Yearning 开发环境"
    
    check_docker
    check_ports
    setup_frontend
    
    log_info "启动开发环境..."
    docker-compose -f docker-compose.dev.yml up --build -d
    
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    log_info "检查服务状态..."
    docker-compose -f docker-compose.dev.yml ps
    
    log_header "开发环境已启动"
    echo
    log_info "访问地址："
    echo "  🌐 完整应用 (Nginx代理): http://localhost"
    echo "  🔧 前端开发服务器: http://localhost:3000"
    echo "  🔌 后端API服务器: http://localhost:8000"
    echo "  🗄️  MySQL数据库: localhost:3306"
    echo "  🐛 Go调试端口: localhost:2345"
    echo
    log_info "默认账号: admin / Yearning_admin"
    echo
    log_info "查看日志: ./dev-start.sh logs"
    log_info "停止服务: ./dev-start.sh stop"
}

# 仅启动后端
start_backend() {
    log_header "启动后端开发环境"
    
    check_docker
    
    log_info "启动MySQL和后端服务..."
    docker-compose -f docker-compose.dev.yml up --build mysql backend-dev -d
    
    log_info "等待服务启动..."
    sleep 10
    
    log_info "后端开发环境已启动"
    echo "  🔌 后端API服务器: http://localhost:8000"
    echo "  🗄️  MySQL数据库: localhost:3306"
    echo "  🐛 Go调试端口: localhost:2345"
}

# 仅启动前端
start_frontend() {
    log_header "启动前端开发环境"
    
    check_docker
    setup_frontend
    
    log_info "启动前端开发服务器..."
    docker-compose -f docker-compose.dev.yml up --build frontend-dev -d
    
    log_info "前端开发环境已启动"
    echo "  🔧 前端开发服务器: http://localhost:3000"
}

# 停止开发环境
stop_dev() {
    log_header "停止开发环境"
    
    log_info "停止所有服务..."
    docker-compose -f docker-compose.dev.yml down
    
    log_info "开发环境已停止"
}

# 查看日志
show_logs() {
    if [ -z "$2" ]; then
        docker-compose -f docker-compose.dev.yml logs -f
    else
        docker-compose -f docker-compose.dev.yml logs -f "$2"
    fi
}

# 重启服务
restart_dev() {
    log_info "重启开发环境..."
    stop_dev
    sleep 2
    start_dev
}

# 进入容器
exec_container() {
    local service="$2"
    if [ -z "$service" ]; then
        log_error "请指定服务名: backend-dev, frontend-dev, mysql"
        exit 1
    fi
    
    docker-compose -f docker-compose.dev.yml exec "$service" bash
}

# 清理开发环境
clean_dev() {
    log_header "清理开发环境"
    
    log_warn "这将删除所有开发环境的容器、网络和数据卷"
    read -p "确定继续？(y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f docker-compose.dev.yml down -v --rmi all
        log_info "开发环境已清理"
    fi
}

# 显示状态
show_status() {
    log_header "开发环境状态"
    
    echo "Docker容器状态:"
    docker-compose -f docker-compose.dev.yml ps
    
    echo
    echo "端口使用情况:"
    local ports=("80" "3000" "8000" "3306" "2345")
    for port in "${ports[@]}"; do
        if lsof -ti:$port > /dev/null 2>&1; then
            echo "  端口 $port: 🔴 使用中"
        else
            echo "  端口 $port: 🟢 空闲"
        fi
    done
}

# 帮助信息
show_help() {
    log_header "Yearning 开发环境管理脚本"
    
    echo "使用方法: $0 [命令]"
    echo
    echo "命令:"
    echo "  start          启动完整开发环境 (默认)"
    echo "  backend        仅启动后端开发环境"
    echo "  frontend       仅启动前端开发环境"
    echo "  stop           停止开发环境"
    echo "  restart        重启开发环境"
    echo "  logs [service] 查看日志"
    echo "  status         显示环境状态"
    echo "  exec <service> 进入容器"
    echo "  clean          清理开发环境"
    echo "  help           显示帮助信息"
    echo
    echo "服务名:"
    echo "  mysql          MySQL数据库"
    echo "  backend-dev    后端开发服务"
    echo "  frontend-dev   前端开发服务"
    echo "  nginx-proxy    Nginx代理服务"
    echo
    echo "示例:"
    echo "  $0 start         # 启动完整环境"
    echo "  $0 logs backend-dev  # 查看后端日志"
    echo "  $0 exec mysql        # 进入MySQL容器"
}

# 主函数
main() {
    case "${1:-start}" in
        "start")
            start_dev
            ;;
        "backend")
            start_backend
            ;;
        "frontend")
            start_frontend
            ;;
        "stop")
            stop_dev
            ;;
        "restart")
            restart_dev
            ;;
        "logs")
            show_logs "$@"
            ;;
        "status")
            show_status
            ;;
        "exec")
            exec_container "$@"
            ;;
        "clean")
            clean_dev
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
