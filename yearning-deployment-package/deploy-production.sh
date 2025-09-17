#!/bin/bash

# Yearning SQL审计平台 - 自动化生产环境部署脚本
# 版本: v1.0.0
# 作者: Yearning Team
# 更新时间: 2025-09-17

set -euo pipefail

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/yearning-deploy-$(date +%Y%m%d_%H%M%S).log"

# 颜色配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
INSTALL_DIR="/opt/yearning"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
MYSQL_DATABASE="yearning"
MYSQL_USER="yearning"
MYSQL_PASSWORD=""
MYSQL_ROOT_PASSWORD=""
SECRET_KEY=""
DEPLOY_MODE="binary"  # binary or docker
DOMAIN_NAME=""
ENABLE_SSL="false"

# 日志函数
log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# 检查运行环境
check_environment() {
    log_info "检查运行环境..."

    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用root用户运行此脚本"
        exit 1
    fi

    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        exit 1
    fi

    source /etc/os-release
    log_info "操作系统: $NAME $VERSION"

    # 检查架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
        log_error "不支持的架构: $ARCH"
        exit 1
    fi
    log_info "系统架构: $ARCH"
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."

    if command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL
        yum update -y
        yum install -y curl wget git gcc gcc-c++ make mysql mysql-server nginx logrotate
        if [[ "$DEPLOY_MODE" == "docker" ]]; then
            yum install -y docker docker-compose
            systemctl start docker
            systemctl enable docker
        fi
    elif command -v apt >/dev/null 2>&1; then
        # Ubuntu/Debian
        apt update -y
        apt install -y curl wget git build-essential mysql-server mysql-client nginx logrotate
        if [[ "$DEPLOY_MODE" == "docker" ]]; then
            apt install -y docker.io docker-compose
            systemctl start docker
            systemctl enable docker
        fi
    else
        log_error "不支持的包管理器"
        exit 1
    fi
}

# 安装Go环境（仅二进制部署需要）
install_go() {
    if [[ "$DEPLOY_MODE" != "binary" ]]; then
        return 0
    fi

    log_info "安装Go环境..."

    # 检查Go是否已安装
    if command -v go >/dev/null 2>&1; then
        GO_VERSION=$(go version | awk '{print $3}')
        log_info "Go已安装: $GO_VERSION"
        return 0
    fi

    # 下载并安装Go
    GO_VERSION="1.21.5"
    if [[ "$ARCH" == "x86_64" ]]; then
        GO_ARCH="amd64"
    else
        GO_ARCH="arm64"
    fi

    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    wget -O "/tmp/$GO_TAR" "https://golang.org/dl/$GO_TAR"

    # 移除旧版本并安装新版本
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "/tmp/$GO_TAR"

    # 设置环境变量
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin

    log_success "Go环境安装完成"
}

# 配置MySQL数据库
setup_mysql() {
    log_info "配置MySQL数据库..."

    # 启动MySQL服务
    systemctl start mysqld || systemctl start mysql
    systemctl enable mysqld || systemctl enable mysql

    # 检查MySQL是否启动成功
    if ! systemctl is-active --quiet mysqld && ! systemctl is-active --quiet mysql; then
        log_error "MySQL服务启动失败"
        exit 1
    fi

    # 配置MySQL root密码（如果是新安装）
    if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';" 2>/dev/null || true
    fi

    # 创建数据库和用户
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" << EOF
CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
DROP USER IF EXISTS '$MYSQL_USER'@'%';
CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
EOF

    log_success "MySQL数据库配置完成"
}

# 创建yearning用户
create_yearning_user() {
    if [[ "$DEPLOY_MODE" != "binary" ]]; then
        return 0
    fi

    log_info "创建yearning系统用户..."

    if ! id yearning >/dev/null 2>&1; then
        useradd -r -s /bin/bash -d "$INSTALL_DIR" yearning
        log_success "yearning用户创建成功"
    else
        log_info "yearning用户已存在"
    fi

    # 创建目录结构
    mkdir -p "$INSTALL_DIR"/{bin,conf,logs,data,backups}
    chown -R yearning:yearning "$INSTALL_DIR"
}

# 构建Yearning二进制文件
build_yearning() {
    if [[ "$DEPLOY_MODE" != "binary" ]]; then
        return 0
    fi

    log_info "构建Yearning二进制文件..."

    # 切换到项目目录
    cd "$PROJECT_ROOT"

    # 下载依赖
    go mod download

    # 编译
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -ldflags "-w -s" -o "$INSTALL_DIR/bin/yearning" main.go

    # 设置权限
    chown yearning:yearning "$INSTALL_DIR/bin/yearning"
    chmod +x "$INSTALL_DIR/bin/yearning"

    log_success "Yearning二进制文件构建完成"
}

# 生成配置文件
generate_config() {
    log_info "生成配置文件..."

    # 生成随机密钥（如果未提供）
    if [[ -z "$SECRET_KEY" ]]; then
        SECRET_KEY=$(openssl rand -hex 8)
        log_info "生成随机密钥: $SECRET_KEY"
    fi

    if [[ "$DEPLOY_MODE" == "binary" ]]; then
        CONFIG_FILE="$INSTALL_DIR/conf/yearning.conf"
    else
        CONFIG_FILE="$PROJECT_ROOT/conf.toml"
    fi

    cat > "$CONFIG_FILE" << EOF
[Mysql]
Db = "$MYSQL_DATABASE"
Host = "$MYSQL_HOST"
Port = "$MYSQL_PORT"
Password = "$MYSQL_PASSWORD"
User = "$MYSQL_USER"

[General]
SecretKey = "$SECRET_KEY"
RpcAddr = "127.0.0.1:50001"
LogLevel = "info"
Lang = "zh_CN"

[Oidc]
Enable = false
ClientId = "yearning"
ClientSecret = "fefehelj23jlj22f3jfjdfd"
Scope = "openid profile"
AuthUrl = ""
TokenUrl = ""
UserUrl = ""
RedirectUrL = "http://127.0.0.1:8000/oidc/_token-login"
UserNameKey = "preferred_username"
RealNameKey = "name"
EmailKey = "email"
SessionKey = "session_state"
EOF

    if [[ "$DEPLOY_MODE" == "binary" ]]; then
        chown yearning:yearning "$CONFIG_FILE"
    fi

    log_success "配置文件生成完成: $CONFIG_FILE"
}

# 部署Juno服务
deploy_juno() {
    log_info "部署Juno SQL检测服务..."

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker未安装，无法部署Juno服务"
        exit 1
    fi

    # 停止并删除旧容器
    docker stop yearning-juno-prod 2>/dev/null || true
    docker rm yearning-juno-prod 2>/dev/null || true

    # 启动Juno容器
    docker run -d \
        --name yearning-juno-prod \
        --restart unless-stopped \
        -p 50001:50001 \
        -e MYSQL_USER="$MYSQL_USER" \
        -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
        -e MYSQL_ADDR="$MYSQL_HOST:$MYSQL_PORT" \
        -e MYSQL_DB="$MYSQL_DATABASE" \
        yeelabs/juno:latest

    # 等待服务启动
    sleep 10

    # 检查服务状态
    if docker ps | grep -q yearning-juno-prod; then
        log_success "Juno服务部署成功"
    else
        log_error "Juno服务部署失败"
        exit 1
    fi
}

# 初始化数据库
initialize_database() {
    log_info "初始化Yearning数据库..."

    if [[ "$DEPLOY_MODE" == "binary" ]]; then
        cd "$INSTALL_DIR"
        sudo -u yearning bash -c "echo 'yes' | ./bin/yearning install --config conf/yearning.conf"
    else
        cd "$PROJECT_ROOT"
        echo 'yes' | docker exec yearning-backend-prod ./yearning install --config conf.toml
    fi

    log_success "数据库初始化完成"
}

# 创建systemd服务（仅二进制部署）
create_systemd_service() {
    if [[ "$DEPLOY_MODE" != "binary" ]]; then
        return 0
    fi

    log_info "创建systemd服务..."

    cat > /etc/systemd/system/yearning.service << EOF
[Unit]
Description=Yearning SQL Audit Platform
After=network.target mysql.service
Wants=mysql.service

[Service]
Type=simple
User=yearning
Group=yearning
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/yearning run --config $INSTALL_DIR/conf/yearning.conf
ExecReload=/bin/kill -USR2 \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=5
Restart=on-failure
RestartSec=5
StandardOutput=append:$INSTALL_DIR/logs/yearning.log
StandardError=append:$INSTALL_DIR/logs/yearning_error.log

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    systemctl daemon-reload

    log_success "systemd服务创建完成"
}

# 启动服务
start_services() {
    log_info "启动Yearning服务..."

    if [[ "$DEPLOY_MODE" == "binary" ]]; then
        systemctl start yearning
        systemctl enable yearning

        # 检查服务状态
        sleep 5
        if systemctl is-active --quiet yearning; then
            log_success "Yearning服务启动成功"
        else
            log_error "Yearning服务启动失败，请检查日志: journalctl -u yearning"
            exit 1
        fi
    else
        cd "$PROJECT_ROOT"
        docker-compose -f docker-compose.prod.yml up -d

        # 等待服务启动
        sleep 15

        # 检查服务状态
        if docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
            log_success "Docker服务启动成功"
        else
            log_error "Docker服务启动失败，请检查容器日志"
            exit 1
        fi
    fi
}

# 配置Nginx反向代理
setup_nginx() {
    if [[ -z "$DOMAIN_NAME" ]]; then
        log_info "跳过Nginx配置（未指定域名）"
        return 0
    fi

    log_info "配置Nginx反向代理..."

    # 创建Nginx配置
    cat > "/etc/nginx/sites-available/yearning" << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    # 如果启用SSL，重定向到HTTPS
    $(if [[ "$ENABLE_SSL" == "true" ]]; then
        echo "return 301 https://\$server_name\$request_uri;"
    else
        echo "location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }"
    fi)
}

$(if [[ "$ENABLE_SSL" == "true" ]]; then
cat << 'EOFSSL'
server {
    listen 443 ssl http2;
    server_name DOMAIN_NAME;

    ssl_certificate /etc/ssl/certs/yearning.crt;
    ssl_certificate_key /etc/ssl/private/yearning.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOFSSL
fi)
EOF

    # 替换域名占位符
    sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" /etc/nginx/sites-available/yearning

    # 启用站点
    ln -sf /etc/nginx/sites-available/yearning /etc/nginx/sites-enabled/

    # 测试Nginx配置
    nginx -t

    # 重启Nginx
    systemctl restart nginx
    systemctl enable nginx

    log_success "Nginx配置完成"
}

# 设置防火墙
setup_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL
        firewall-cmd --permanent --add-port=8000/tcp
        firewall-cmd --permanent --add-port=50001/tcp
        if [[ -n "$DOMAIN_NAME" ]]; then
            firewall-cmd --permanent --add-service=http
            if [[ "$ENABLE_SSL" == "true" ]]; then
                firewall-cmd --permanent --add-service=https
            fi
        fi
        firewall-cmd --reload
    elif command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian
        ufw allow 8000/tcp
        ufw allow 50001/tcp
        if [[ -n "$DOMAIN_NAME" ]]; then
            ufw allow 'Nginx HTTP'
            if [[ "$ENABLE_SSL" == "true" ]]; then
                ufw allow 'Nginx HTTPS'
            fi
        fi
        ufw --force enable
    fi

    log_success "防火墙配置完成"
}

# 设置日志轮转
setup_logrotate() {
    if [[ "$DEPLOY_MODE" != "binary" ]]; then
        return 0
    fi

    log_info "配置日志轮转..."

    cat > /etc/logrotate.d/yearning << EOF
$INSTALL_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    postrotate
        systemctl reload yearning
    endscript
}
EOF

    log_success "日志轮转配置完成"
}

# 创建备份脚本
create_backup_script() {
    log_info "创建备份脚本..."

    cat > "$INSTALL_DIR/scripts/backup.sh" << EOF
#!/bin/bash

BACKUP_DIR="$INSTALL_DIR/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# 备份数据库
mysqldump -u $MYSQL_USER -p'$MYSQL_PASSWORD' \\
  --single-transaction \\
  --routines \\
  --triggers \\
  $MYSQL_DATABASE > \$BACKUP_DIR/yearning_db_\$DATE.sql

# 压缩备份文件
gzip \$BACKUP_DIR/yearning_db_\$DATE.sql

# 备份配置文件
cp $INSTALL_DIR/conf/yearning.conf \$BACKUP_DIR/yearning_conf_\$DATE.conf

# 删除7天前的备份
find \$BACKUP_DIR -name "yearning_db_*.sql.gz" -mtime +7 -delete
find \$BACKUP_DIR -name "yearning_conf_*.conf" -mtime +7 -delete

echo "备份完成: \$BACKUP_DIR"
EOF

    chmod +x "$INSTALL_DIR/scripts/backup.sh"
    chown yearning:yearning "$INSTALL_DIR/scripts/backup.sh"

    # 添加到crontab
    (crontab -u yearning -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/scripts/backup.sh") | crontab -u yearning -

    log_success "备份脚本创建完成"
}

# 显示部署信息
show_deployment_info() {
    log_success "Yearning部署完成！"
    echo ""
    echo "========================================"
    echo "          部署信息摘要"
    echo "========================================"
    echo "部署模式: $DEPLOY_MODE"
    echo "安装目录: $INSTALL_DIR"
    echo "访问地址: http://$(hostname -I | awk '{print $1}'):8000"
    if [[ -n "$DOMAIN_NAME" ]]; then
        if [[ "$ENABLE_SSL" == "true" ]]; then
            echo "域名访问: https://$DOMAIN_NAME"
        else
            echo "域名访问: http://$DOMAIN_NAME"
        fi
    fi
    echo ""
    echo "数据库信息:"
    echo "  主机: $MYSQL_HOST:$MYSQL_PORT"
    echo "  数据库: $MYSQL_DATABASE"
    echo "  用户: $MYSQL_USER"
    echo ""
    echo "默认登录账户:"
    echo "  用户名: admin"
    echo "  密码: Yearning_admin"
    echo ""
    echo "服务管理命令:"
    if [[ "$DEPLOY_MODE" == "binary" ]]; then
        echo "  启动: systemctl start yearning"
        echo "  停止: systemctl stop yearning"
        echo "  重启: systemctl restart yearning"
        echo "  状态: systemctl status yearning"
        echo "  日志: journalctl -u yearning -f"
    else
        echo "  启动: docker-compose -f docker-compose.prod.yml up -d"
        echo "  停止: docker-compose -f docker-compose.prod.yml down"
        echo "  日志: docker-compose -f docker-compose.prod.yml logs -f"
    fi
    echo ""
    echo "日志文件: $LOG_FILE"
    echo "========================================"
}

# 显示帮助信息
show_help() {
    cat << EOF
Yearning SQL审计平台 - 自动化部署脚本

用法: $0 [选项]

选项:
  -m, --mode MODE           部署模式 (binary|docker，默认: binary)
  -d, --dir DIR            安装目录 (默认: /opt/yearning)
  -h, --mysql-host HOST    MySQL主机 (默认: 127.0.0.1)
  -P, --mysql-port PORT    MySQL端口 (默认: 3306)
  -D, --mysql-db DATABASE  MySQL数据库名 (默认: yearning)
  -u, --mysql-user USER    MySQL用户名 (默认: yearning)
  -p, --mysql-password PWD MySQL密码 (必需)
  -r, --mysql-root-pwd PWD MySQL root密码 (必需)
  -s, --secret-key KEY     加密密钥 (16字符，可选)
  -n, --domain-name NAME   域名 (可选)
  -S, --enable-ssl         启用SSL (需要证书)
  --help                   显示此帮助信息

示例:
  # 基本部署
  $0 -p 'mysql_password' -r 'root_password'

  # Docker部署
  $0 -m docker -p 'mysql_password' -r 'root_password'

  # 带域名的部署
  $0 -p 'mysql_password' -r 'root_password' -n 'yearning.company.com'

EOF
}

# 主函数
main() {
    echo "Yearning SQL审计平台 - 自动化部署脚本"
    echo "========================================"

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -h|--mysql-host)
                MYSQL_HOST="$2"
                shift 2
                ;;
            -P|--mysql-port)
                MYSQL_PORT="$2"
                shift 2
                ;;
            -D|--mysql-db)
                MYSQL_DATABASE="$2"
                shift 2
                ;;
            -u|--mysql-user)
                MYSQL_USER="$2"
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
            -s|--secret-key)
                SECRET_KEY="$2"
                shift 2
                ;;
            -n|--domain-name)
                DOMAIN_NAME="$2"
                shift 2
                ;;
            -S|--enable-ssl)
                ENABLE_SSL="true"
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

    # 验证必需参数
    if [[ -z "$MYSQL_PASSWORD" || -z "$MYSQL_ROOT_PASSWORD" ]]; then
        log_error "MySQL密码是必需的参数"
        show_help
        exit 1
    fi

    # 验证部署模式
    if [[ "$DEPLOY_MODE" != "binary" && "$DEPLOY_MODE" != "docker" ]]; then
        log_error "无效的部署模式: $DEPLOY_MODE"
        exit 1
    fi

    # 开始部署
    log_info "开始部署，日志文件: $LOG_FILE"

    check_environment
    install_dependencies
    install_go
    setup_mysql
    create_yearning_user
    build_yearning
    generate_config
    deploy_juno
    initialize_database
    create_systemd_service
    start_services
    setup_nginx
    setup_firewall
    setup_logrotate
    create_backup_script

    show_deployment_info
}

# 捕获中断信号
trap 'log_error "部署被中断"; exit 1' INT TERM

# 启动脚本
main "$@"