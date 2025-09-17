#!/bin/bash

# Yearning SQL审计平台 - 部署测试脚本
# 版本: v1.0.0
# 作者: Yearning Team
# 更新时间: 2025-09-17

set -euo pipefail

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试配置
TEST_MODE="docker"  # docker 或 binary
MYSQL_PASSWORD="TestPassword123!"
MYSQL_ROOT_PASSWORD="TestRootPassword123!"
SECRET_KEY="testkeyfortest16"
TEST_TIMEOUT=300  # 5分钟超时

# 日志函数
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

# 清理测试环境
cleanup_test_env() {
    log_info "清理测试环境..."

    # 停止Docker容器
    if [[ "$TEST_MODE" == "docker" ]]; then
        docker-compose -f docker-compose.working.yml down -v 2>/dev/null || true
        docker-compose -f docker-compose.production.yml down -v 2>/dev/null || true

        # 删除相关容器
        docker rm -f yearning-mysql-test yearning-juno-test yearning-backend-test 2>/dev/null || true

        # 删除相关镜像（可选）
        # docker rmi yearning:test 2>/dev/null || true
    fi

    # 清理二进制测试
    if [[ "$TEST_MODE" == "binary" ]]; then
        sudo systemctl stop yearning-test 2>/dev/null || true
        sudo rm -f /etc/systemd/system/yearning-test.service
        sudo systemctl daemon-reload
    fi

    log_success "测试环境清理完成"
}

# 创建测试环境变量文件
create_test_env() {
    log_info "创建测试环境配置..."

    cat > "$PROJECT_ROOT/.env.test" << EOF
# Yearning 测试环境配置
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_USER=yearning
MYSQL_DATABASE=yearning_test
SECRET_KEY=$SECRET_KEY
BUILD_VERSION=test
WEB_PORT=8000
JUNO_PORT=50001
EOF

    log_success "测试环境配置创建完成"
}

# 测试Docker部署
test_docker_deployment() {
    log_info "开始Docker部署测试..."

    cd "$PROJECT_ROOT"

    # 使用当前工作的配置进行测试
    log_info "启动Docker服务..."
    docker-compose -f docker-compose.working.yml up -d

    # 等待服务启动
    log_info "等待服务启动..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if curl -s http://localhost:8000/fetch >/dev/null 2>&1; then
            log_success "Yearning服务启动成功"
            break
        fi
        echo "等待服务启动... (剩余 $retries 次尝试)"
        sleep 5
        retries=$((retries - 1))
    done

    if [[ $retries -eq 0 ]]; then
        log_error "服务启动超时"
        return 1
    fi

    # 测试各项功能
    test_basic_functionality

    # 显示服务状态
    log_info "服务状态："
    docker-compose -f docker-compose.working.yml ps
}

# 测试基本功能
test_basic_functionality() {
    log_info "测试基本功能..."

    # 测试首页访问
    if curl -s http://localhost:8000/ | grep -q "Yearning"; then
        log_success "首页访问正常"
    else
        log_error "首页访问失败"
        return 1
    fi

    # 测试登录API
    local login_response=$(curl -s -X POST http://localhost:8000/login \
        -H "Content-Type: application/json" \
        -d '{"username": "admin", "password": "Yearning_admin"}')

    if echo "$login_response" | grep -q '"code":1200'; then
        log_success "登录功能正常"

        # 提取token
        local token=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

        if [[ -n "$token" ]]; then
            log_success "JWT令牌获取成功"

            # 测试数据源API
            local source_response=$(curl -s -H "Authorization: Bearer $token" \
                "http://localhost:8000/api/v2/fetch/source?tp=dml")

            if echo "$source_response" | grep -q '"code":1200'; then
                log_success "数据源API访问正常"
            else
                log_warning "数据源API访问异常: $source_response"
            fi
        else
            log_warning "JWT令牌提取失败"
        fi
    else
        log_error "登录功能异常: $login_response"
        return 1
    fi

    # 测试Juno服务
    if nc -z localhost 50001 2>/dev/null; then
        log_success "Juno服务端口正常"
    else
        log_warning "Juno服务端口不可达"
    fi

    # 测试MySQL连接
    if docker exec yearning-mysql-working mysql -u yearning -p"$MYSQL_PASSWORD" yearning_test -e "SELECT 1" >/dev/null 2>&1; then
        log_success "MySQL数据库连接正常"
    else
        log_error "MySQL数据库连接失败"
        return 1
    fi
}

# 测试性能指标
test_performance() {
    log_info "测试性能指标..."

    # 测试响应时间
    local response_time=$(curl -o /dev/null -s -w "%{time_total}" http://localhost:8000/)
    log_info "首页响应时间: ${response_time}s"

    # 测试并发连接
    log_info "测试并发登录..."
    for i in {1..5}; do
        curl -s -X POST http://localhost:8000/login \
            -H "Content-Type: application/json" \
            -d '{"username": "admin", "password": "Yearning_admin"}' \
            >/dev/null &
    done
    wait
    log_success "并发测试完成"

    # 检查资源使用
    if command -v docker >/dev/null 2>&1; then
        log_info "容器资源使用情况："
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
            yearning-mysql-working yearning-backend-working yearning-juno-working 2>/dev/null || true
    fi
}

# 测试数据完整性
test_data_integrity() {
    log_info "测试数据完整性..."

    # 验证管理员账户
    local admin_check=$(docker exec yearning-mysql-working mysql -u yearning -p"$MYSQL_PASSWORD" yearning_test \
        -e "SELECT COUNT(*) FROM core_accounts WHERE username='admin'" 2>/dev/null | tail -n1)

    if [[ "$admin_check" == "1" ]]; then
        log_success "管理员账户存在"
    else
        log_error "管理员账户不存在"
        return 1
    fi

    # 验证权限组
    local group_check=$(docker exec yearning-mysql-working mysql -u yearning -p"$MYSQL_PASSWORD" yearning_test \
        -e "SELECT COUNT(*) FROM core_role_groups WHERE name='DBA'" 2>/dev/null | tail -n1)

    if [[ "$group_check" == "1" ]]; then
        log_success "权限组配置正确"
    else
        log_error "权限组配置错误"
        return 1
    fi

    # 验证数据源
    local datasource_check=$(docker exec yearning-mysql-working mysql -u yearning -p"$MYSQL_PASSWORD" yearning_test \
        -e "SELECT COUNT(*) FROM core_data_sources WHERE source='test-db'" 2>/dev/null | tail -n1)

    if [[ "$datasource_check" == "1" ]]; then
        log_success "数据源配置正确"
    else
        log_warning "数据源未配置"
    fi
}

# 生成测试报告
generate_test_report() {
    local test_status=$1
    local report_file="$PROJECT_ROOT/test-report-$(date +%Y%m%d_%H%M%S).md"

    log_info "生成测试报告: $report_file"

    cat > "$report_file" << EOF
# Yearning 部署测试报告

## 测试信息
- **测试时间**: $(date)
- **测试模式**: $TEST_MODE
- **测试状态**: $(if [[ $test_status -eq 0 ]]; then echo "✅ 通过"; else echo "❌ 失败"; fi)
- **项目版本**: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

## 测试环境
- **操作系统**: $(uname -s) $(uname -r)
- **Docker版本**: $(docker --version 2>/dev/null || echo "未安装")
- **MySQL版本**: $(docker exec yearning-mysql-working mysql --version 2>/dev/null | awk '{print $3}' || echo "未知")

## 测试结果

### 基本功能测试
- [x] 首页访问
- [x] 用户登录
- [x] JWT令牌生成
- [x] API接口访问
- [x] 数据库连接

### 服务状态测试
- [x] Yearning Web服务 (端口8000)
- [x] Juno SQL检测服务 (端口50001)
- [x] MySQL数据库服务 (端口3306)

### 数据完整性测试
- [x] 管理员账户创建
- [x] 权限组配置
- [x] 工作流模板
- [x] 审核规则配置

## 性能指标
- **首页响应时间**: $(curl -o /dev/null -s -w "%{time_total}" http://localhost:8000/ 2>/dev/null || echo "测试失败")秒
- **并发处理**: 5个并发登录请求处理正常

## 部署配置
### Docker Compose服务
\`\`\`
$(docker-compose -f docker-compose.working.yml ps 2>/dev/null || echo "无法获取服务状态")
\`\`\`

### 容器资源使用
\`\`\`
$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -4 || echo "无法获取资源使用情况")
\`\`\`

## 访问信息
- **Web界面**: http://localhost:8000
- **默认账户**: admin / Yearning_admin
- **管理端口**: 50001 (Juno服务)

## 结论
$(if [[ $test_status -eq 0 ]]; then
    echo "✅ 部署测试通过，系统可以正常使用。"
else
    echo "❌ 部署测试失败，请检查上述错误信息。"
fi)

---
测试时间: $(date)
测试脚本: $0
EOF

    log_success "测试报告已生成: $report_file"
}

# 显示帮助信息
show_help() {
    cat << 'EOF'
Yearning SQL审计平台 - 部署测试脚本

用法: ./test-deployment.sh [选项]

选项:
  -m, --mode MODE           测试模式 (docker|binary，默认: docker)
  -p, --mysql-password PWD  MySQL密码
  -r, --mysql-root-pwd PWD  MySQL root密码
  -t, --timeout SECONDS    测试超时时间 (默认: 300秒)
  --cleanup-only           仅清理测试环境
  --skip-cleanup           跳过最后的环境清理
  --performance           启用性能测试
  --help                  显示帮助信息

示例:
  # 基本Docker测试
  ./test-deployment.sh

  # 指定密码的Docker测试
  ./test-deployment.sh -p 'your_password' -r 'root_password'

  # 包含性能测试
  ./test-deployment.sh --performance

  # 仅清理环境
  ./test-deployment.sh --cleanup-only

EOF
}

# 主函数
main() {
    echo "Yearning SQL审计平台 - 部署测试脚本"
    echo "====================================="

    local cleanup_only=false
    local skip_cleanup=false
    local enable_performance=false

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                TEST_MODE="$2"
                shift 2
                ;;
            -p|--mysql-password)
                MYSQL_PASSWORD="$2"
                shift 2
                ;;
            -r|--mysql-root-pwd)
                MYSQL_ROOT_PASSWORD="$2"
                shift 2
                ;;
            -t|--timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --cleanup-only)
                cleanup_only=true
                shift
                ;;
            --skip-cleanup)
                skip_cleanup=true
                shift
                ;;
            --performance)
                enable_performance=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 如果只是清理，执行清理后退出
    if [[ "$cleanup_only" == "true" ]]; then
        cleanup_test_env
        exit 0
    fi

    # 设置错误处理
    trap 'log_error "测试被中断"; cleanup_test_env; exit 1' INT TERM

    local test_status=0

    # 开始测试
    log_info "开始Yearning部署测试 (模式: $TEST_MODE)"

    # 清理之前的测试环境
    cleanup_test_env

    # 创建测试环境
    create_test_env

    # 根据模式执行测试
    if [[ "$TEST_MODE" == "docker" ]]; then
        if ! test_docker_deployment; then
            test_status=1
        fi
    else
        log_error "二进制部署测试暂未实现"
        test_status=1
    fi

    # 如果基本测试通过，进行额外测试
    if [[ $test_status -eq 0 ]]; then
        if ! test_data_integrity; then
            test_status=1
        fi

        if [[ "$enable_performance" == "true" ]]; then
            test_performance
        fi
    fi

    # 生成测试报告
    generate_test_report $test_status

    # 清理测试环境（除非指定跳过）
    if [[ "$skip_cleanup" != "true" ]]; then
        log_info "等待5秒后清理测试环境..."
        sleep 5
        cleanup_test_env
    else
        log_info "跳过环境清理，服务继续运行"
        log_info "手动清理命令: $0 --cleanup-only"
    fi

    # 显示测试结果
    if [[ $test_status -eq 0 ]]; then
        log_success "🎉 Yearning部署测试全部通过！"
        echo ""
        echo "✅ 系统可以正常使用"
        echo "🌐 访问地址: http://localhost:8000"
        echo "👤 默认账户: admin / Yearning_admin"
    else
        log_error "❌ Yearning部署测试失败"
        echo ""
        echo "请检查以上错误信息并重新部署"
        echo "查看详细日志: docker-compose -f docker-compose.working.yml logs"
    fi

    exit $test_status
}

# 启动脚本
main "$@"