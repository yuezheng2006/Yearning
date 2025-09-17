#!/bin/bash

# Yearning SQL审计平台 - 二进制包部署配置脚本
# 版本: v1.0.0
# 作者: Yearning Team
# 更新时间: 2025-09-17
# 说明: 此脚本用于准备二进制包部署的环境和配置

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

# 部署配置
INSTALL_DIR="/opt/yearning"
SERVICE_USER="yearning"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
MYSQL_DATABASE="yearning"
MYSQL_USER="yearning"
MYSQL_PASSWORD=""
MYSQL_ROOT_PASSWORD=""
SECRET_KEY=""
JUNO_ENABLED="true"
WEB_PORT="8000"
DOMAIN_NAME=""
ENABLE_SSL="false"

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

# 显示系统要求
show_requirements() {
    cat << 'EOF'
======================================
     Yearning 二进制包部署要求
======================================

【硬件要求】
- CPU: 最低2核，推荐4核+
- 内存: 最低4GB，推荐8GB+
- 存储: 最低20GB，推荐50GB+
- 网络: 支持HTTP/HTTPS访问

【软件要求】
- 操作系统: CentOS 7+/Ubuntu 18.04+/RHEL 7+
- MySQL: 5.7+ 或 8.0+
- Docker: 20.10+ (用于Juno服务)
- 系统权限: root用户或sudo权限

【网络要求】
- 端口8000: Yearning Web服务
- 端口50001: Juno SQL检测服务
- 端口3306: MySQL数据库服务

【先决条件检查】
EOF

    log_info "正在检查系统环境..."
}

# 检查先决条件
check_prerequisites() {
    local check_failed=0

    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        ((check_failed++))
    else
        source /etc/os-release
        log_success "操作系统: $NAME $VERSION"
    fi

    # 检查架构
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
        log_error "不支持的架构: $arch (仅支持 x86_64 和 aarch64)"
        ((check_failed++))
    else
        log_success "系统架构: $arch"
    fi

    # 检查内存
    local memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local memory_gb=$((memory_kb / 1024 / 1024))
    if [[ $memory_gb -lt 4 ]]; then
        log_warning "内存不足: ${memory_gb}GB (推荐至少4GB)"
    else
        log_success "内存: ${memory_gb}GB"
    fi

    # 检查磁盘空间
    local disk_space=$(df / | awk 'NR==2 {print $4}')
    local disk_gb=$((disk_space / 1024 / 1024))
    if [[ $disk_gb -lt 20 ]]; then
        log_warning "磁盘空间不足: ${disk_gb}GB (推荐至少20GB)"
    else
        log_success "磁盘空间: ${disk_gb}GB"
    fi

    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            log_error "需要root权限或sudo权限"
            ((check_failed++))
        else
            log_success "权限: sudo用户"
        fi
    else
        log_success "权限: root用户"
    fi

    # 检查MySQL
    if command -v mysql >/dev/null 2>&1; then
        local mysql_version=$(mysql --version | awk '{print $3}' | awk -F',' '{print $1}')
        log_success "MySQL客户端: $mysql_version"
    else
        log_warning "MySQL客户端未安装（稍后将自动安装）"
    fi

    # 检查MySQL服务
    if systemctl is-active --quiet mysqld || systemctl is-active --quiet mysql; then
        log_success "MySQL服务: 运行中"
    else
        log_warning "MySQL服务未运行（稍后将配置启动）"
    fi

    # 检查Docker
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        log_success "Docker: $docker_version"

        if systemctl is-active --quiet docker; then
            log_success "Docker服务: 运行中"
        else
            log_warning "Docker服务未运行（稍后将启动）"
        fi
    else
        log_warning "Docker未安装（Juno服务需要Docker）"
    fi

    # 检查端口占用
    for port in 8000 50001; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "端口 $port 已被占用"
        else
            log_success "端口 $port 可用"
        fi
    done

    # 检查网络连接
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_success "网络连接: 正常"
    else
        log_warning "网络连接异常（可能影响依赖下载）"
    fi

    if [[ $check_failed -gt 0 ]]; then
        log_error "先决条件检查失败，请解决上述问题后重试"
        exit 1
    fi

    log_success "先决条件检查通过！"
}

# 生成密钥
generate_secret_key() {
    if [[ -z "$SECRET_KEY" ]]; then
        # 生成16字符随机密钥
        SECRET_KEY=$(openssl rand -hex 8)
        log_info "生成加密密钥: $SECRET_KEY"
    fi

    if [[ ${#SECRET_KEY} -ne 16 ]]; then
        log_error "密钥长度必须为16字符，当前长度: ${#SECRET_KEY}"
        exit 1
    fi
}

# 加密密码函数
encrypt_password() {
    local password=$1
    local key=$2

    # 使用Go程序加密密码
    cat > /tmp/encrypt_password.go << 'EOF'
package main

import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "os"
)

func pkcs7Padding(data []byte, blockSize int) []byte {
    padding := blockSize - len(data)%blockSize
    padText := make([]byte, padding)
    for i := range padText {
        padText[i] = byte(padding)
    }
    return append(data, padText...)
}

func encrypt(plaintext, key string) string {
    if len(key) != 16 {
        return ""
    }

    origData := []byte(plaintext)
    k := []byte(key)

    block, err := aes.NewCipher(k)
    if err != nil {
        return ""
    }

    blockSize := block.BlockSize()
    origData = pkcs7Padding(origData, blockSize)
    blockMode := cipher.NewCBCEncrypter(block, k[:blockSize])
    crypted := make([]byte, len(origData))
    blockMode.CryptBlocks(crypted, origData)

    return base64.StdEncoding.EncodeToString(crypted)
}

func main() {
    if len(os.Args) != 3 {
        fmt.Println("Usage: encrypt_password <password> <key>")
        os.Exit(1)
    }

    password := os.Args[1]
    key := os.Args[2]

    encrypted := encrypt(password, key)
    if encrypted == "" {
        fmt.Println("Encryption failed")
        os.Exit(1)
    }

    fmt.Println(encrypted)
}
EOF

    if command -v go >/dev/null 2>&1; then
        cd /tmp && go run encrypt_password.go "$password" "$key"
    else
        log_error "Go环境未安装，无法加密密码"
        exit 1
    fi
}

# 创建配置文件
create_config_file() {
    log_info "创建配置文件..."

    # 生成密钥
    generate_secret_key

    # 加密MySQL密码
    local encrypted_password=$(encrypt_password "$MYSQL_PASSWORD" "$SECRET_KEY")
    if [[ -z "$encrypted_password" ]]; then
        log_error "密码加密失败"
        exit 1
    fi

    # 创建配置目录
    mkdir -p "$INSTALL_DIR/conf"

    # 创建配置文件
    cat > "$INSTALL_DIR/conf/yearning.conf" << EOF
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

    # 设置配置文件权限
    chown $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR/conf/yearning.conf"
    chmod 600 "$INSTALL_DIR/conf/yearning.conf"

    log_success "配置文件创建完成: $INSTALL_DIR/conf/yearning.conf"
}

# 创建数据源配置脚本
create_datasource_script() {
    log_info "创建数据源配置脚本..."

    cat > "$INSTALL_DIR/scripts/add-datasource.sh" << EOF
#!/bin/bash

# Yearning 数据源添加脚本
# 用法: ./add-datasource.sh <数据源名称> <主机> <端口> <用户名> <密码> [IDC标识]

set -euo pipefail

if [[ \$# -lt 5 ]]; then
    echo "用法: \$0 <数据源名称> <主机> <端口> <用户名> <密码> [IDC标识]"
    echo "示例: \$0 prod-mysql 192.168.1.100 3306 yearning mypassword prod_001"
    exit 1
fi

SOURCE_NAME="\$1"
HOST="\$2"
PORT="\$3"
USERNAME="\$4"
PASSWORD="\$5"
IDC="\${6:-local_001}"

# 加密密码
ENCRYPTED_PASSWORD=\$(cd /tmp && go run encrypt_password.go "\$PASSWORD" "$SECRET_KEY")

if [[ -z "\$ENCRYPTED_PASSWORD" ]]; then
    echo "密码加密失败"
    exit 1
fi

# 连接数据库添加数据源
mysql -u $MYSQL_USER -p'$MYSQL_PASSWORD' -h $MYSQL_HOST -P $MYSQL_PORT $MYSQL_DATABASE << EOSQL
CALL CreateDataSource(
    '\$SOURCE_NAME',
    '\$HOST',
    \$PORT,
    '\$USERNAME',
    '\$ENCRYPTED_PASSWORD',
    '\$IDC'
);
EOSQL

echo "数据源 \$SOURCE_NAME 添加成功！"
EOF

    chmod +x "$INSTALL_DIR/scripts/add-datasource.sh"
    chown $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR/scripts/add-datasource.sh"

    log_success "数据源配置脚本创建完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."

    # 启动脚本
    cat > "$INSTALL_DIR/scripts/start.sh" << EOF
#!/bin/bash
systemctl start yearning
systemctl status yearning
EOF

    # 停止脚本
    cat > "$INSTALL_DIR/scripts/stop.sh" << EOF
#!/bin/bash
systemctl stop yearning
echo "Yearning 服务已停止"
EOF

    # 重启脚本
    cat > "$INSTALL_DIR/scripts/restart.sh" << EOF
#!/bin/bash
systemctl restart yearning
systemctl status yearning
EOF

    # 状态检查脚本
    cat > "$INSTALL_DIR/scripts/status.sh" << EOF
#!/bin/bash
echo "=== Yearning 服务状态 ==="
systemctl status yearning

echo ""
echo "=== Juno 服务状态 ==="
docker ps | grep juno || echo "Juno 服务未运行"

echo ""
echo "=== 端口监听状态 ==="
netstat -tuln | grep -E ':(8000|50001|3306) '

echo ""
echo "=== 进程信息 ==="
ps aux | grep yearning | grep -v grep || echo "Yearning 进程未运行"

echo ""
echo "=== 日志摘要 ==="
echo "最近10条日志:"
journalctl -u yearning --no-pager -n 10
EOF

    # 日志查看脚本
    cat > "$INSTALL_DIR/scripts/logs.sh" << EOF
#!/bin/bash
if [[ "\${1:-}" == "-f" ]]; then
    journalctl -u yearning -f
else
    journalctl -u yearning --no-pager -n 50
fi
EOF

    # 备份脚本
    cat > "$INSTALL_DIR/scripts/backup.sh" << EOF
#!/bin/bash

BACKUP_DIR="$INSTALL_DIR/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

echo "开始备份 Yearning 数据..."

# 备份数据库
mysqldump -u $MYSQL_USER -p'$MYSQL_PASSWORD' -h $MYSQL_HOST -P $MYSQL_PORT \\
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

echo "备份完成: \$BACKUP_DIR/yearning_db_\$DATE.sql.gz"
echo "配置备份: \$BACKUP_DIR/yearning_conf_\$DATE.conf"
EOF

    # 恢复脚本
    cat > "$INSTALL_DIR/scripts/restore.sh" << EOF
#!/bin/bash

if [[ \$# -ne 1 ]]; then
    echo "用法: \$0 <备份文件.sql.gz>"
    echo "可用备份文件:"
    ls -la $INSTALL_DIR/backups/yearning_db_*.sql.gz 2>/dev/null || echo "无备份文件"
    exit 1
fi

BACKUP_FILE="\$1"

if [[ ! -f "\$BACKUP_FILE" ]]; then
    echo "备份文件不存在: \$BACKUP_FILE"
    exit 1
fi

echo "警告: 此操作将覆盖当前数据库，请确认是否继续？"
read -p "输入 'yes' 继续: " confirm

if [[ "\$confirm" != "yes" ]]; then
    echo "操作已取消"
    exit 1
fi

echo "停止 Yearning 服务..."
systemctl stop yearning

echo "恢复数据库..."
gunzip -c "\$BACKUP_FILE" | mysql -u $MYSQL_USER -p'$MYSQL_PASSWORD' -h $MYSQL_HOST -P $MYSQL_PORT $MYSQL_DATABASE

echo "启动 Yearning 服务..."
systemctl start yearning

echo "数据库恢复完成"
EOF

    # 设置权限
    chmod +x "$INSTALL_DIR/scripts"/*.sh
    chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR/scripts"

    log_success "管理脚本创建完成"
}

# 显示部署后配置指南
show_deployment_guide() {
    cat << EOF

======================================
      二进制包部署配置完成
======================================

【部署信息】
- 安装目录: $INSTALL_DIR
- 服务用户: $SERVICE_USER
- 配置文件: $INSTALL_DIR/conf/yearning.conf
- 数据库: $MYSQL_HOST:$MYSQL_PORT/$MYSQL_DATABASE
- Web端口: $WEB_PORT
- Juno端口: 50001

【下一步操作】

1. 安装MySQL数据库（如未安装）:
   # CentOS/RHEL
   sudo yum install -y mysql-server
   sudo systemctl start mysqld
   sudo systemctl enable mysqld

   # Ubuntu/Debian
   sudo apt install -y mysql-server
   sudo systemctl start mysql
   sudo systemctl enable mysql

2. 配置MySQL数据库:
   sudo mysql_secure_installation

   # 创建数据库和用户
   mysql -u root -p << 'EOSQL'
   CREATE DATABASE $MYSQL_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
   CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
   GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';
   FLUSH PRIVILEGES;
   EOSQL

3. 安装Docker（用于Juno服务）:
   # 安装Docker
   curl -fsSL https://get.docker.com | bash
   sudo systemctl start docker
   sudo systemctl enable docker

   # 启动Juno服务
   sudo docker run -d \\
     --name yearning-juno \\
     --restart unless-stopped \\
     -p 50001:50001 \\
     -e MYSQL_USER=$MYSQL_USER \\
     -e MYSQL_PASSWORD=$MYSQL_PASSWORD \\
     -e MYSQL_ADDR=$MYSQL_HOST:$MYSQL_PORT \\
     -e MYSQL_DB=$MYSQL_DATABASE \\
     yeelabs/juno:latest

4. 部署Yearning二进制文件:
   # 将构建的二进制文件复制到安装目录
   sudo cp yearning $INSTALL_DIR/bin/
   sudo chown $SERVICE_USER:$SERVICE_USER $INSTALL_DIR/bin/yearning
   sudo chmod +x $INSTALL_DIR/bin/yearning

5. 初始化数据库:
   cd $INSTALL_DIR
   sudo -u $SERVICE_USER ./bin/yearning install --config conf/yearning.conf

6. 运行数据库初始化脚本:
   mysql -u $MYSQL_USER -p'$MYSQL_PASSWORD' -h $MYSQL_HOST -P $MYSQL_PORT $MYSQL_DATABASE < $(dirname "$0")/init-database.sql

7. 创建systemd服务:
   sudo tee /etc/systemd/system/yearning.service << 'EOSVC'
[Unit]
Description=Yearning SQL Audit Platform
After=network.target mysql.service
Wants=mysql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
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
EOSVC

8. 启动和启用服务:
   sudo systemctl daemon-reload
   sudo systemctl start yearning
   sudo systemctl enable yearning

9. 配置防火墙:
   # CentOS/RHEL
   sudo firewall-cmd --permanent --add-port=$WEB_PORT/tcp
   sudo firewall-cmd --permanent --add-port=50001/tcp
   sudo firewall-cmd --reload

   # Ubuntu/Debian
   sudo ufw allow $WEB_PORT/tcp
   sudo ufw allow 50001/tcp

10. 访问系统:
    http://$(hostname -I | awk '{print $1}'):$WEB_PORT

    默认账户:
    用户名: admin
    密码: Yearning_admin

【管理命令】
- 启动服务: $INSTALL_DIR/scripts/start.sh
- 停止服务: $INSTALL_DIR/scripts/stop.sh
- 重启服务: $INSTALL_DIR/scripts/restart.sh
- 查看状态: $INSTALL_DIR/scripts/status.sh
- 查看日志: $INSTALL_DIR/scripts/logs.sh [-f]
- 备份数据: $INSTALL_DIR/scripts/backup.sh
- 恢复数据: $INSTALL_DIR/scripts/restore.sh <backup_file>
- 添加数据源: $INSTALL_DIR/scripts/add-datasource.sh <参数>

【配置文件说明】
主配置文件: $INSTALL_DIR/conf/yearning.conf

重要配置项:
- SecretKey: $SECRET_KEY (用于密码加密，请勿泄露)
- MySQL连接信息: $MYSQL_HOST:$MYSQL_PORT/$MYSQL_DATABASE
- Juno服务地址: 127.0.0.1:50001

【故障排除】
1. 查看服务状态: systemctl status yearning
2. 查看详细日志: journalctl -u yearning -f
3. 检查端口占用: netstat -tuln | grep -E ':(8000|50001)'
4. 测试数据库连接: mysql -u $MYSQL_USER -p -h $MYSQL_HOST -P $MYSQL_PORT $MYSQL_DATABASE

======================================

EOF
}

# 显示帮助信息
show_help() {
    cat << 'EOF'
Yearning SQL审计平台 - 二进制包部署配置脚本

用法: ./setup-binary-deployment.sh [选项]

选项:
  --mysql-host HOST         MySQL主机地址 (默认: 127.0.0.1)
  --mysql-port PORT         MySQL端口 (默认: 3306)
  --mysql-db DATABASE       MySQL数据库名 (默认: yearning)
  --mysql-user USER         MySQL用户名 (默认: yearning)
  --mysql-password PWD      MySQL密码 (必需)
  --mysql-root-password PWD MySQL root密码 (可选)
  --secret-key KEY          16字符加密密钥 (可选，自动生成)
  --install-dir DIR         安装目录 (默认: /opt/yearning)
  --service-user USER       服务运行用户 (默认: yearning)
  --web-port PORT           Web服务端口 (默认: 8000)
  --disable-juno            禁用Juno服务
  --domain-name NAME        域名 (可选)
  --enable-ssl              启用SSL
  --check-only              仅检查先决条件
  --help                    显示帮助信息

示例:
  # 检查先决条件
  ./setup-binary-deployment.sh --check-only

  # 基本配置
  ./setup-binary-deployment.sh --mysql-password 'your_password'

  # 完整配置
  ./setup-binary-deployment.sh \
    --mysql-host 192.168.1.100 \
    --mysql-password 'your_password' \
    --mysql-root-password 'root_password' \
    --domain-name yearning.company.com

EOF
}

# 主函数
main() {
    echo "Yearning SQL审计平台 - 二进制包部署配置脚本"
    echo "=================================================="

    local check_only=false

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mysql-host)
                MYSQL_HOST="$2"
                shift 2
                ;;
            --mysql-port)
                MYSQL_PORT="$2"
                shift 2
                ;;
            --mysql-db)
                MYSQL_DATABASE="$2"
                shift 2
                ;;
            --mysql-user)
                MYSQL_USER="$2"
                shift 2
                ;;
            --mysql-password)
                MYSQL_PASSWORD="$2"
                shift 2
                ;;
            --mysql-root-password)
                MYSQL_ROOT_PASSWORD="$2"
                shift 2
                ;;
            --secret-key)
                SECRET_KEY="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --service-user)
                SERVICE_USER="$2"
                shift 2
                ;;
            --web-port)
                WEB_PORT="$2"
                shift 2
                ;;
            --disable-juno)
                JUNO_ENABLED="false"
                shift
                ;;
            --domain-name)
                DOMAIN_NAME="$2"
                shift 2
                ;;
            --enable-ssl)
                ENABLE_SSL="true"
                shift
                ;;
            --check-only)
                check_only=true
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

    # 显示系统要求
    show_requirements

    # 检查先决条件
    check_prerequisites

    # 如果只是检查，则退出
    if [[ "$check_only" == "true" ]]; then
        log_success "先决条件检查完成"
        exit 0
    fi

    # 验证必需参数
    if [[ -z "$MYSQL_PASSWORD" ]]; then
        log_error "MySQL密码是必需的参数"
        show_help
        exit 1
    fi

    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi

    # 创建服务用户
    if ! id "$SERVICE_USER" >/dev/null 2>&1; then
        log_info "创建服务用户: $SERVICE_USER"
        useradd -r -s /bin/bash -d "$INSTALL_DIR" "$SERVICE_USER"
    fi

    # 创建目录结构
    log_info "创建目录结构..."
    mkdir -p "$INSTALL_DIR"/{bin,conf,logs,data,backups,scripts}
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    # 生成配置
    create_config_file
    create_datasource_script
    create_management_scripts

    # 显示部署指南
    show_deployment_guide

    log_success "二进制包部署配置完成！"
}

# 捕获中断信号
trap 'log_error "配置被中断"; exit 1' INT TERM

# 启动脚本
main "$@"